import logging

log = logging.getLogger(__name__)


def download(url):
    raise OSError(url)


def fetch(url):
    try:
        return download(url)
    except OSError as exc:
        log.warning("fetch failed: %s", exc)
