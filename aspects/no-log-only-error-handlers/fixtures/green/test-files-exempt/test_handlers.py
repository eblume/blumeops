import logging

log = logging.getLogger(__name__)


def boom():
    raise RuntimeError("boom")


def test_logs_only():
    try:
        boom()
    except RuntimeError:
        log.warning("expected in test")
