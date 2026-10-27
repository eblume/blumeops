import logging

logger = logging.getLogger(__name__)


def run_job(job):
    try:
        job.execute()
    except Exception:
        logger.exception("job %s crashed", job.name)
