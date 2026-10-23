# Keep the paren-wrapped shape: the docstring-looking value opener is the
# case under test, and ruff format would strip the parens.
# fmt: off
PROMPT = (
    """
    Ask eblume about the instance first.
    """
)
DEFAULT_HOST = "forge.example.com"
