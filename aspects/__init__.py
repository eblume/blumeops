"""The instance aspect suite (docs/explanation/talos-v0.5/aspects.md).

A package so each aspect's test modules keep unique dotted names under
pytest's prepend import mode (two aspects sharing a test module basename
would otherwise collide on import).
"""
