from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "shortsforge",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.workers.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_default_retry_delay=30,
    worker_concurrency=settings.CELERY_CONCURRENCY,
    # Requires a `celery ... beat` process running alongside the worker (see
    # docker-compose.yml's `beat` service) — the worker alone never fires
    # scheduled tasks on its own.
    beat_schedule={
        "daily-algorithm-digest": {
            "task": "app.workers.tasks.send_algorithm_digest_task",
            "schedule": crontab(hour=settings.DIGEST_HOUR_UTC, minute=0),
        },
    },
)
