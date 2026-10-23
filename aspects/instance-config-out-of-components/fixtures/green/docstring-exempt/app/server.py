"""The server module for the instance dashboard.

Serves the instance dashboard (forge.ops.eblu.me) for the deployment
playbook; real hosts come from instance configuration. Endpoints are
documented in docs/.
"""

# The publishing pipeline (eblume/horkos#54) shells out to the runner.
DEFAULT_HOST = "forge.example.com"
DEFAULT_PORT = 8080


def serve(host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> str:
    """Serve on a neutral default; real hosts come from instance config."""
    return f"http://{host}:{port}"
