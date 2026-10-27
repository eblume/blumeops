import logging

log = logging.getLogger(__name__)


class _Counter:
    def labels(self, **_kw):
        return self

    def inc(self):
        return None


FAILURES = _Counter()
PATH = "/dev/null"


def remove(path):
    raise FileNotFoundError(path)


def ntfy_send(message):
    return message


def job():
    raise RuntimeError("boom")


def reraises(path):
    try:
        return open(path).read()
    except OSError as exc:
        log.warning("read failed: %s", exc)
        raise


def returns_none(path):
    try:
        return open(path).read()
    except OSError:
        log.warning("read failed")
        return None


def counts(job):
    try:
        job()
    except RuntimeError:
        log.exception("job failed: %s", FAILURES.labels(kind="job").inc())


def notifies(job):
    try:
        job()
    except RuntimeError:
        log.exception("job failed: %s", ntfy_send("job failed"))


def empty_handler(path):
    try:
        remove(path)
    except FileNotFoundError:
        pass
