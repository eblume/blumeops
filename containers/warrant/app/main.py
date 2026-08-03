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
frozen {action, sha, inputs}. When ``WARRANT_DISPATCH_ENABLED`` is set the
warrant is then consumed to dispatch its workflow as ``warrant-bot``;
otherwise the record stands and a human dispatches. Approving goes through
a confirm page — privileged actions are never one click from a list view.
"""

import json
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

app = FastAPI(title="warrant", version="0.3.2")
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
                consumed INTEGER NOT NULL DEFAULT 0,
                run_number INTEGER,
                run_url TEXT
            )"""
        )
        # Added after the table shipped; SQLite has no IF NOT EXISTS for
        # columns, so tolerate the duplicate on already-migrated databases.
        for column in ("run_number INTEGER", "run_url TEXT"):
            try:
                conn.execute(f"ALTER TABLE warrants ADD COLUMN {column}")
            except sqlite3.OperationalError:
                pass


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
    return {
        "ok": True,
        "version": app.version,
        # Readiness of the power, not the secret itself.
        "dispatch": (
            "armed" if DISPATCH_ENABLED and DISPATCH_TOKEN
            else "armed-no-token" if DISPATCH_ENABLED
            else "disarmed"
        ),
    }


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
    with db() as conn:
        cur = conn.execute(
            "INSERT INTO requests (created_at, requester, action, sha, inputs, why, pr)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (time.time(), requester, body.action, body.sha,
             json.dumps(body.inputs), body.why, body.pr),
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

# ── v0.2c: dispatch ────────────────────────────────────────────────────────
# The only place Warrant holds power. Disabled by default so deploying the
# capability and arming it are separate, revertible decisions.
DISPATCH_ENABLED = os.environ.get("WARRANT_DISPATCH_ENABLED") == "1"
DISPATCH_TOKEN = os.environ.get("WARRANT_DISPATCH_TOKEN", "")
FORGE_API = os.environ.get("WARRANT_FORGE_API", "https://forge.eblu.me/api/v1")
REPO_OWNER = os.environ.get("WARRANT_REPO_OWNER", "eblume")
REPO_NAME = os.environ.get("WARRANT_REPO_NAME", "blumeops")


def _policy_allows(action: str) -> tuple[bool, str]:
    """Re-check warrant-policy.yaml ON MAIN at dispatch time. An action
    demoted to `deny` after its warrant was minted does not run."""
    import yaml

    url = f"{FORGE_API}/repos/{REPO_OWNER}/{REPO_NAME}/raw/main/warrant-policy.yaml"
    try:
        resp = httpx.get(
            url, headers={"Authorization": f"token {DISPATCH_TOKEN}"}, timeout=15.0
        )
        resp.raise_for_status()
        entry = (yaml.safe_load(resp.text).get("actions") or {}).get(action)
    except (httpx.HTTPError, yaml.YAMLError) as exc:
        return False, f"policy fetch failed: {exc}"
    if entry is None:
        return False, f"{action} has no policy entry (deny by default)"
    if entry.get("class") == "deny":
        return False, f"{action} is class deny: {entry.get('note', '')}"
    return True, ""


def consume_and_dispatch(warrant_id: int) -> dict:
    """Consume a warrant exactly once and trigger its workflow.

    Single-use is enforced by the conditional UPDATE: concurrent callers
    race in SQLite and exactly one sees rowcount 1. Everything dispatched
    comes from the warrant row — never from the caller — so nothing between
    approval and execution can alter what runs.
    """
    if not DISPATCH_ENABLED:
        return {"dispatched": False, "reason": "dispatch disarmed"}
    if not DISPATCH_TOKEN:
        # Armed but tokenless: the ExternalSecret didn't materialize. Loud,
        # because the failure is otherwise indistinguishable from disarmed.
        return {"dispatched": False, "reason": "ARMED BUT NO DISPATCH TOKEN — check the warrant-dispatch ExternalSecret"}

    with db() as conn:
        w = conn.execute("SELECT * FROM warrants WHERE id = ?", (warrant_id,)).fetchone()
        if w is None:
            return {"dispatched": False, "reason": "no such warrant"}
        if w["expires_at"] <= time.time():
            return {"dispatched": False, "reason": "warrant expired"}
        allowed, why = _policy_allows(w["action"])
        if not allowed:
            return {"dispatched": False, "reason": why}
        cur = conn.execute(
            "UPDATE warrants SET consumed = 1 WHERE id = ? AND consumed = 0", (warrant_id,)
        )
        if cur.rowcount != 1:
            return {"dispatched": False, "reason": "warrant already consumed"}
        action, inputs, request_id = w["action"], json.loads(w["inputs"]), w["request_id"]

    url = f"{FORGE_API}/repos/{REPO_OWNER}/{REPO_NAME}/actions/workflows/{action}/dispatches"
    try:
        resp = httpx.post(
            url,
            headers={"Authorization": f"token {DISPATCH_TOKEN}"},
            json={"ref": "main", "inputs": inputs},
            timeout=30.0,
        )
        ok = resp.status_code in (201, 204)
        detail = "" if ok else f"{resp.status_code}: {resp.text[:200]}"
    except httpx.HTTPError as exc:
        ok, detail = False, str(exc)

    # Failure is terminal: the warrant stays consumed and the request is
    # marked failed. Re-running requires a fresh human decision.
    run_number, run_url = (_find_run(action) if ok else (None, None))
    with db() as conn:
        conn.execute(
            "UPDATE requests SET status = ? WHERE id = ?",
            ("dispatched" if ok else "dispatch_failed", request_id),
        )
        conn.execute(
            "UPDATE warrants SET run_number = ?, run_url = ?, note = ? WHERE id = ?",
            (run_number, run_url,
             w["note"] if ok else (w["note"] + f" | dispatch FAILED: {detail}"),
             warrant_id),
        )
    return {"dispatched": ok, "reason": detail, "run_url": run_url}


def _find_run(action: str) -> tuple[int | None, str | None]:
    """The run this dispatch just created. The dispatch API answers 204 with
    no body, so the run is identified by polling for the newest run of this
    workflow. Best-effort: a missing link never fails a successful dispatch,
    it just leaves the warrant pointing at the workflow's run list."""
    listing = f"https://forge.eblu.me/{REPO_OWNER}/{REPO_NAME}/actions?workflow={action}"
    for _ in range(6):
        try:
            resp = httpx.get(
                f"{FORGE_API}/repos/{REPO_OWNER}/{REPO_NAME}/actions/tasks",
                headers={"Authorization": f"token {DISPATCH_TOKEN}"},
                timeout=10.0,
            )
            resp.raise_for_status()
            runs = [
                r for r in (resp.json().get("workflow_runs") or [])
                if r.get("workflow_id") == action
            ]
            if runs:
                newest = max(runs, key=lambda r: r["id"])
                n = newest["run_number"]
                return n, f"https://forge.eblu.me/{REPO_OWNER}/{REPO_NAME}/actions/runs/{n}"
        except httpx.HTTPError:
            pass
        time.sleep(1)
    return None, listing


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
    if result.get("warrant_id"):
        outcome = consume_and_dispatch(result["warrant_id"])
        result["dispatch"] = outcome
        if not outcome["dispatched"]:
            result["next_step"] = (
                "not dispatched (" + outcome["reason"] + ") — run the forge "
                "dispatch per [[request-a-privileged-run]], quoting warrant "
                f"#{result['warrant_id']}"
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


@app.get("/requests/{req_id}/confirm", response_class=HTMLResponse)
def confirm(req_id: int, request: Request) -> str:
    """Approval is a deliberate act: the full input set and a link to the
    diff, on their own page. The list view can deny but not approve."""
    _require_approver(request)
    with db() as conn:
        r = conn.execute("SELECT * FROM requests WHERE id = ?", (req_id,)).fetchone()
    if r is None:
        raise HTTPException(404, "no such request")
    if r["status"] != "pending":
        raise HTTPException(409, f"request is already {r['status']}")
    inputs = json.loads(r["inputs"])
    rows = "".join(f"<tr><td>{k}</td><td><code>{v}</code></td></tr>" for k, v in inputs.items())
    effect = (
        "<b>This will dispatch the workflow immediately.</b>"
        if DISPATCH_ENABLED and DISPATCH_TOKEN
        else "This records the approval; dispatch is currently disabled."
    )
    return f"""<!doctype html><html><head><title>approve #{req_id}</title>
<style>body{{font-family:system-ui;margin:2rem;max-width:52rem}}
td,th{{border:1px solid #ccc;padding:.4rem .7rem;text-align:left}}
table{{border-collapse:collapse;margin:1rem 0}}</style></head>
<body><h1>approve request #{req_id}?</h1>
<p><b>{r['action']}</b> at {_sha_link(r['sha'])} · {_pr_links(r['pr'], r['sha'])}</p>
<p><i>{r['why']}</i></p>
<table><tr><th>input</th><th>value</th></tr>{rows or '<tr><td colspan=2><em>none</em></td></tr>'}</table>
<p>{effect}</p>
<form method=post action=/requests/{req_id}/decide>
<input type=hidden name=csrf value='{_csrf_token()}'>
<input type=hidden name=decision value=approve>
<input name=note placeholder='note (optional)' size=40><br><br>
<button type=submit>approve</button> <a href=/>cancel</a></form>
</body></html>"""


@app.get("/api/warrants")
def list_warrants(limit: int = 50) -> list[dict]:
    with db() as conn:
        return [
            dict(r)
            for r in conn.execute(
                "SELECT * FROM warrants ORDER BY id DESC LIMIT ?", (min(limit, 500),)
            ).fetchall()
        ]


FORGE_REPO_URL = os.environ.get(
    "WARRANT_FORGE_REPO_URL", "https://forge.eblu.me/eblume/blumeops"
)


def _sha_link(sha: str) -> str:
    """The commit itself — approving means having read this."""
    return f"<a href='{FORGE_REPO_URL}/commit/{sha}'><code>{sha[:7]}</code></a>"


def _run_link(w) -> str:
    """The run an approval caused — the first thing worth clicking after
    approving."""
    url = w["run_url"] if "run_url" in w.keys() else None
    if not url:
        return ""
    label = f"run {w['run_number']}" if w["run_number"] else "runs"
    return f"<a href='{url}'>{label}</a>"


def _pr_links(pr: int | None, sha: str) -> str:
    """PR + its diff. Tying the decision to the code change is the substance
    of the approve-fatigue answer; the ergonomics half comes later."""
    if not pr:
        return ""
    return (
        f"<a href='{FORGE_REPO_URL}/pulls/{pr}'>#{pr}</a> "
        f"<a href='{FORGE_REPO_URL}/pulls/{pr}/files' title='review the diff'>diff</a>"
    )


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
            "<button name=decision value=deny>deny</button></form> "
            f"<a href='/requests/{r['id']}/confirm'>approve…</a>"
        )

    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM requests ORDER BY id DESC LIMIT 100"
        ).fetchall()
        warrants = conn.execute(
            "SELECT * FROM warrants ORDER BY id DESC LIMIT 20"
        ).fetchall()
    items = "".join(
        f"<tr><td>{r['id']}</td><td>{r['status']}</td>"
        f"<td><a href='{FORGE_REPO_URL}/src/branch/main/.forgejo/workflows/{r['action']}'>{r['action']}</a></td>"
        f"<td>{_sha_link(r['sha'])}</td><td>{_pr_links(r['pr'], r['sha'])}</td>"
        f"<td>{r['why'][:120]}</td><td>{r['requester']}</td><td>{act_cell(r)}</td></tr>"
        for r in rows
    ) or "<tr><td colspan=8><em>queue empty</em></td></tr>"
    witems = "".join(
        f"<tr><td>{w['id']}</td><td>#{w['request_id']}</td><td>{w['action']}</td>"
        f"<td>{_sha_link(w['sha'])}</td><td>{w['decided_by']}</td>"
        f"<td>{'consumed' if w['consumed'] else ('live' if w['expires_at'] > time.time() else 'expired')}</td>"
        f"<td>{_run_link(w)}</td>"
        f"<td>{w['note'][:60]}</td></tr>"
        for w in warrants
    ) or "<tr><td colspan=8><em>none yet</em></td></tr>"
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
<th>decided by</th><th>state</th><th>run</th><th>note</th></tr>{witems}</table></body></html>"""
