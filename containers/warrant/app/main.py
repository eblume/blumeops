"""Warrant — the approval broker for agent-requested privileged runs.

See [[warrant-approval-gated-runs]] for the program and
[[warrant]] for the service reference.

Agents (authentik ``agents-m2m`` JWT, JWKS-verified):
- POST /api/requests, GET /api/requests

Approvers (authentik OIDC session, ``admins`` group, MFA per the authentik
flow — the step-up factor lives there, never here):
- GET  /auth/{login,callback,logout}
- POST /api/requests/{id}/decision, POST /requests/{id}/decide (UI form)
- GET  /api/warrants

An approval mints a **warrant**: a single-use, TTL'd record binding the
frozen {action, sha, inputs}. This service holds **no privileged
credential** — it records decisions; the human still dispatches. The
dispatcher that consumes warrants is [[warrant-dispatch-credential]].
"""

import os
import sqlite3
import time
from contextlib import contextmanager

import httpx

import jwt
from fastapi import FastAPI, Header, HTTPException, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field

DB_PATH = os.environ.get("WARRANT_DB", "/data/warrant.db")
# Authentik OIDC issuer for the agents-m2m provider; JWKS derived from it.
ISSUER = os.environ.get(
    "WARRANT_ISSUER", "https://authentik.ops.eblu.me/application/o/agents-m2m/"
)
JWKS_URL = os.environ.get("WARRANT_JWKS_URL", f"{ISSUER}jwks/")
CLIENT_ID = os.environ.get("WARRANT_CLIENT_ID", "agents-m2m")
# Escape hatch for pre-Authentik smoke testing ONLY (never set in manifests).
ALLOW_ANON = os.environ.get("WARRANT_DEV_ALLOW_ANON") == "1"

# ── v0.2a: the human door ──────────────────────────────────────────────────
# Separate provider from agents-m2m: humans arrive via the OIDC code flow,
# app policy-bound to `admins` in authentik. The approval *step-up* factor
# lives in the authentik flow, never here (invariant 4).
HUMAN_ISSUER = os.environ.get(
    "WARRANT_HUMAN_ISSUER", "https://authentik.ops.eblu.me/application/o/warrant/"
)
HUMAN_CLIENT_ID = os.environ.get("WARRANT_HUMAN_CLIENT_ID", "warrant")
HUMAN_CLIENT_SECRET = os.environ.get("WARRANT_HUMAN_CLIENT_SECRET", "")
SESSION_KEY = os.environ.get("WARRANT_SESSION_KEY", "")
PUBLIC_URL = os.environ.get("WARRANT_PUBLIC_URL", "https://warrant.ops.eblu.me")
SESSION_COOKIE = "warrant_session"
SESSION_TTL = 8 * 3600

app = FastAPI(title="warrant", version="0.2.2")
_jwks_client: jwt.PyJWKClient | None = None
_human_jwks_client: jwt.PyJWKClient | None = None


class RunRequest(BaseModel):
    action: str = Field(..., max_length=200, description="e.g. argocd-deploy.yaml")
    sha: str = Field(..., pattern=r"^[0-9a-f]{40}$")
    inputs: dict[str, str] = Field(default_factory=dict)
    why: str = Field("", max_length=2000)
    pr: int | None = None


@contextmanager
def db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at REAL NOT NULL,
                requester TEXT NOT NULL,
                action TEXT NOT NULL,
                sha TEXT NOT NULL,
                inputs TEXT NOT NULL,
                why TEXT NOT NULL,
                pr INTEGER,
                status TEXT NOT NULL DEFAULT 'pending'
            )"""
        )
        # v0.2b: warrants — the approval artifact (invariants 2 & 5). A row
        # here is a RECORD of an authenticated human decision, bound to the
        # frozen {action, sha, inputs}; single-use + TTL fields exist now so
        # v0.2c's dispatcher can consume them without a schema change.
        conn.execute(
            """CREATE TABLE IF NOT EXISTS warrants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                request_id INTEGER NOT NULL REFERENCES requests(id),
                decision TEXT NOT NULL,
                decided_by TEXT NOT NULL,
                decided_at REAL NOT NULL,
                action TEXT NOT NULL,
                sha TEXT NOT NULL,
                inputs TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                expires_at REAL NOT NULL,
                consumed INTEGER NOT NULL DEFAULT 0
            )"""
        )


# Schema init at import — deterministic under uvicorn and test clients alike
# (the deprecated on_event("startup") hook doesn't fire in bare TestClient).
init_db()


def verify_agent(authorization: str | None) -> str:
    """Verify the Bearer JWT against Authentik's JWKS; return the subject."""
    if ALLOW_ANON:
        return "anonymous-dev"
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Bearer token required (agents-m2m client_credentials)")
    token = authorization.removeprefix("Bearer ")
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = jwt.PyJWKClient(JWKS_URL, cache_keys=True)
    try:
        key = _jwks_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            key.key,
            algorithms=["RS256", "ES256"],
            audience=CLIENT_ID,
            issuer=ISSUER.rstrip("/"),
            options={"verify_iss": False},  # authentik issuer format: verify in v0.2
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(401, f"token rejected: {exc}") from exc
    # Human-readable identity, not the hashed sub (pilot feedback).
    return str(claims.get("preferred_username") or claims.get("sub", "unknown"))


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True, "version": app.version}


# ── v0.2a human auth: OIDC code flow + signed session cookie ───────────────

def _sign(claims: dict, ttl: int) -> str:
    return jwt.encode({**claims, "exp": time.time() + ttl}, SESSION_KEY, algorithm="HS256")


def _unsign(token: str) -> dict | None:
    try:
        return jwt.decode(token, SESSION_KEY, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None


def current_user(request: Request) -> dict | None:
    """The signed session, if present and valid. None = anonymous viewer."""
    if not SESSION_KEY:
        return None
    if cookie := request.cookies.get(SESSION_COOKIE):
        return _unsign(cookie)
    return None


@app.get("/auth/login")
def auth_login() -> Response:
    if not (SESSION_KEY and HUMAN_CLIENT_SECRET):
        raise HTTPException(503, "human login not configured (warrant-oidc secret missing)")
    state = _sign({"kind": "oauth-state", "nonce": os.urandom(16).hex()}, 600)
    from urllib.parse import urlencode

    params = urlencode(
        {
            "response_type": "code",
            "client_id": HUMAN_CLIENT_ID,
            "redirect_uri": f"{PUBLIC_URL}/auth/callback",
            "scope": "openid profile email",
            "state": state,
        }
    )
    resp = Response(status_code=302)
    resp.headers["Location"] = f"https://authentik.ops.eblu.me/application/o/authorize/?{params}"
    return resp


@app.get("/auth/callback")
def auth_callback(code: str, state: str) -> Response:
    if _unsign(state) is None or _unsign(state).get("kind") != "oauth-state":
        raise HTTPException(400, "bad state")
    token_resp = httpx.post(
        "https://authentik.ops.eblu.me/application/o/token/",
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": f"{PUBLIC_URL}/auth/callback",
            "client_id": HUMAN_CLIENT_ID,
            "client_secret": HUMAN_CLIENT_SECRET,
        },
        timeout=15.0,
    )
    if token_resp.status_code != 200:
        raise HTTPException(401, f"code exchange failed: {token_resp.text[:200]}")
    id_token = token_resp.json().get("id_token", "")
    global _human_jwks_client
    if _human_jwks_client is None:
        _human_jwks_client = jwt.PyJWKClient(f"{HUMAN_ISSUER}jwks/", cache_keys=True)
    try:
        key = _human_jwks_client.get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token, key.key, algorithms=["RS256", "ES256"], audience=HUMAN_CLIENT_ID
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(401, f"id_token rejected: {exc}") from exc
    if "admins" not in (claims.get("groups") or []):
        raise HTTPException(403, "warrant approvers must be in the admins group")
    session = _sign(
        {
            "kind": "session",
            "sub": claims.get("sub"),
            "username": claims.get("preferred_username", "unknown"),
            "groups": claims.get("groups", []),
        },
        SESSION_TTL,
    )
    resp = Response(status_code=302)
    resp.headers["Location"] = "/"
    resp.set_cookie(
        SESSION_COOKIE, session, max_age=SESSION_TTL,
        httponly=True, secure=True, samesite="lax",
    )
    return resp


@app.get("/auth/logout")
def auth_logout() -> Response:
    resp = Response(status_code=302)
    resp.headers["Location"] = "/"
    resp.delete_cookie(SESSION_COOKIE)
    return resp


@app.post("/api/requests", status_code=201)
def create_request(
    body: RunRequest, authorization: str | None = Header(default=None)
) -> dict:
    requester = verify_agent(authorization)
    import json as _json

    with db() as conn:
        cur = conn.execute(
            "INSERT INTO requests (created_at, requester, action, sha, inputs, why, pr)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (time.time(), requester, body.action, body.sha,
             _json.dumps(body.inputs), body.why, body.pr),
        )
        return {"id": cur.lastrowid, "status": "pending", "requester": requester}


@app.get("/api/requests")
def list_requests(status: str | None = None, limit: int = 50) -> list[dict]:
    q = "SELECT * FROM requests"
    args: list = []
    if status:
        q += " WHERE status = ?"
        args.append(status)
    q += " ORDER BY id DESC LIMIT ?"
    args.append(min(limit, 500))
    with db() as conn:
        return [dict(r) for r in conn.execute(q, args).fetchall()]


WARRANT_TTL = int(os.environ.get("WARRANT_TTL_SECONDS", "3600"))


def _require_approver(request: Request) -> dict:
    user = current_user(request)
    if user is None:
        raise HTTPException(401, "sign in at /auth/login (admins only)")
    if "admins" not in (user.get("groups") or []):
        raise HTTPException(403, "approvers must be in the admins group")
    return user


def _csrf_token() -> str:
    return _sign({"kind": "csrf"}, 3600)


def _check_csrf(token: str) -> None:
    payload = _unsign(token)
    if payload is None or payload.get("kind") != "csrf":
        raise HTTPException(400, "bad csrf token")


def _decide(req_id: int, decision: str, note: str, user: dict) -> dict:
    """v0.2b: record an authenticated decision. Approval MINTS a warrant —
    a single-use, TTL'd record binding {action, sha, inputs} (invariants
    2 & 5) — but dispatches NOTHING. The human still runs the forge
    dispatch; the warrant is the audit artifact v0.2c's dispatcher will
    consume. Denial closes the request."""
    if decision not in ("approve", "deny"):
        raise HTTPException(400, "decision must be approve|deny")
    with db() as conn:
        row = conn.execute("SELECT * FROM requests WHERE id = ?", (req_id,)).fetchone()
        if row is None:
            raise HTTPException(404, "no such request")
        if row["status"] != "pending":
            raise HTTPException(409, f"request is already {row['status']}")
        new_status = "approved" if decision == "approve" else "denied"
        conn.execute("UPDATE requests SET status = ? WHERE id = ?", (new_status, req_id))
        result: dict = {"request_id": req_id, "status": new_status, "decided_by": user["username"]}
        if decision == "approve":
            cur = conn.execute(
                "INSERT INTO warrants (request_id, decision, decided_by, decided_at,"
                " action, sha, inputs, note, expires_at) VALUES (?,?,?,?,?,?,?,?,?)",
                (req_id, decision, user["username"], time.time(), row["action"],
                 row["sha"], row["inputs"], note, time.time() + WARRANT_TTL),
            )
            result["warrant_id"] = cur.lastrowid
            result["expires_in"] = WARRANT_TTL
            result["next_step"] = (
                "v0.2b records approvals but dispatches nothing: run the forge "
                "dispatch per [[request-a-privileged-run]], quoting warrant "
                f"#{cur.lastrowid} in the run's audit trail"
            )
        return result


@app.post("/api/requests/{req_id}/decision")
def decide(req_id: int, request: Request, body: dict | None = None) -> JSONResponse:
    user = _require_approver(request)
    body = body or {}
    return JSONResponse(_decide(req_id, body.get("decision", ""), body.get("note", ""), user))


@app.post("/requests/{req_id}/decide")
async def decide_form(req_id: int, request: Request) -> Response:
    """The UI buttons (form POST + CSRF; the JSON API above is for tools)."""
    user = _require_approver(request)
    form = await request.form()
    _check_csrf(str(form.get("csrf", "")))
    _decide(req_id, str(form.get("decision", "")), str(form.get("note", "")), user)
    resp = Response(status_code=303)
    resp.headers["Location"] = "/"
    return resp


@app.get("/api/warrants")
def list_warrants(limit: int = 50) -> list[dict]:
    with db() as conn:
        return [
            dict(r)
            for r in conn.execute(
                "SELECT * FROM warrants ORDER BY id DESC LIMIT ?", (min(limit, 500),)
            ).fetchall()
        ]


@app.get("/", response_class=HTMLResponse)
def index(request: Request) -> str:
    user = current_user(request)
    approver = user is not None and "admins" in (user.get("groups") or [])
    who = (
        f"signed in as <b>{user.get('username')}</b> · <a href=/auth/logout>logout</a>"
        if user
        else "<a href=/auth/login>sign in</a> (approvers)"
    )
    csrf = _csrf_token() if approver else ""

    def act_cell(r) -> str:
        if not (approver and r["status"] == "pending"):
            return ""
        return (
            f"<form method=post action=/requests/{r['id']}/decide style='display:inline'>"
            f"<input type=hidden name=csrf value='{csrf}'>"
            "<input name=note placeholder='note (optional)' size=18> "
            "<button name=decision value=deny>deny</button> "
            "<button name=decision value=approve>approve</button></form>"
        )

    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM requests ORDER BY id DESC LIMIT 100"
        ).fetchall()
        warrants = conn.execute(
            "SELECT * FROM warrants ORDER BY id DESC LIMIT 20"
        ).fetchall()
    items = "".join(
        f"<tr><td>{r['id']}</td><td>{r['status']}</td><td>{r['action']}</td>"
        f"<td><code>{r['sha'][:7]}</code></td><td>{r['pr'] or ''}</td>"
        f"<td>{r['why'][:120]}</td><td>{r['requester']}</td><td>{act_cell(r)}</td></tr>"
        for r in rows
    ) or "<tr><td colspan=8><em>queue empty</em></td></tr>"
    witems = "".join(
        f"<tr><td>{w['id']}</td><td>#{w['request_id']}</td><td>{w['action']}</td>"
        f"<td><code>{w['sha'][:7]}</code></td><td>{w['decided_by']}</td>"
        f"<td>{'consumed' if w['consumed'] else ('live' if w['expires_at'] > time.time() else 'expired')}</td>"
        f"<td>{w['note'][:60]}</td></tr>"
        for w in warrants
    ) or "<tr><td colspan=7><em>none yet</em></td></tr>"
    return f"""<!doctype html><html><head><title>warrant</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse;margin-bottom:1.5rem}}
td,th{{border:1px solid #ccc;padding:.4rem .7rem;text-align:left}}</style></head>
<body><h1>warrant <small>v{app.version}</small></h1>
<p>{who} · Approvals are recorded here; execution remains forge dispatch
([[request-a-privileged-run]]) until v0.2c.</p>
<h2>requests</h2>
<table><tr><th>id</th><th>status</th><th>action</th><th>sha</th><th>PR</th>
<th>why</th><th>requester</th><th></th></tr>{items}</table>
<h2>warrants</h2>
<table><tr><th>id</th><th>request</th><th>action</th><th>sha</th>
<th>decided by</th><th>state</th><th>note</th></tr>{witems}</table></body></html>"""
