"""Warrant — the approval broker for agent-requested privileged runs.

v0.1 SCAFFOLD ([[warrant-approval-gated-runs]] Phase 3). This version is a
request queue with a read-only UI, deliberately WITHOUT an approval path:

- POST /api/requests   — agents file requests, authenticated by an Authentik
                         ``agents-m2m`` client-credentials JWT (JWKS-verified)
- GET  /api/requests   — list (newest first, filterable by status)
- GET  /               — human-readable queue (tailnet-only via ingress)
- POST /api/requests/{id}/decision — **501 Not Implemented**, on purpose.

The approve/deny flow lands in v0.2 behind an Authentik session + passkey
step-up, together with the dispatch credential. Until then this service
holds NO privileged credentials of any kind — it can record intent, not act
on it. That ordering is the point: the queue can go live and mirror into
heph while the auth design is still being verified.
"""

import os
import sqlite3
import time
from contextlib import contextmanager

import jwt
from fastapi import FastAPI, Header, HTTPException, Request
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

app = FastAPI(title="warrant", version="0.1.0")
_jwks_client: jwt.PyJWKClient | None = None


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
    return str(claims.get("sub", "unknown"))


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True, "version": app.version}


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


@app.post("/api/requests/{req_id}/decision")
def decide(req_id: int, request: Request) -> JSONResponse:
    # v0.2: Authentik session + WebAuthn/passkey step-up mints a single-use
    # warrant bound to {action, sha, inputs}; the broker then dispatches and
    # leases scoped secrets. v0.1 holds no credentials and refuses.
    return JSONResponse(
        status_code=501,
        content={
            "error": "approval is not implemented in the v0.1 scaffold",
            "how_to_approve": "dispatch the workflow from the forge UI per "
            "[[request-a-privileged-run]] — dispatch-as-approval remains the "
            "Phase 1 path until Warrant v0.2 lands the passkey flow",
        },
    )


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM requests ORDER BY id DESC LIMIT 100"
        ).fetchall()
    items = "".join(
        f"<tr><td>{r['id']}</td><td>{r['status']}</td><td>{r['action']}</td>"
        f"<td><code>{r['sha'][:7]}</code></td><td>{r['pr'] or ''}</td>"
        f"<td>{r['why'][:120]}</td><td>{r['requester']}</td></tr>"
        for r in rows
    ) or "<tr><td colspan=7><em>queue empty</em></td></tr>"
    return f"""<!doctype html><html><head><title>warrant</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse}}
td,th{{border:1px solid #ccc;padding:.4rem .7rem;text-align:left}}</style></head>
<body><h1>warrant <small>v{app.version} (scaffold — read-only)</small></h1>
<p>Approvals still happen via forge dispatch ([[request-a-privileged-run]]).</p>
<table><tr><th>id</th><th>status</th><th>action</th><th>sha</th><th>PR</th>
<th>why</th><th>requester</th></tr>{items}</table></body></html>"""
