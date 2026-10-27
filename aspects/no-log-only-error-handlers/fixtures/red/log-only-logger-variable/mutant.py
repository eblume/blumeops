import logging

LOGGER = logging.getLogger(__name__)


def _mutant(fn):
    try:
        return fn()
    except ValueError as exc:
        LOGGER.warning("mutant: %s", exc)
