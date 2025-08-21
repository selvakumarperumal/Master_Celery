from celery import Celery
import os

# Get broker and backend URLs from environment variables
# Default to localhost Redis if not set
CELERY_BROKER_URL = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/0')

# Create Celery app instance
celery_app = Celery('celery_app')

# Configure Celery with broker and backend
celery_app.conf.update(
    broker_url=CELERY_BROKER_URL,
    result_backend=CELERY_RESULT_BACKEND,
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_routes={
        "app.tasks.add": {"queue": "default"},  # Default queue
        "app.tasks.failing_task": {"queue": "default"},
        "app.tasks.important_task": {"queue": "high_priority"},
        "app.tasks.long_running_task": {"queue": "default"},
        "app.tasks.scheduled_task": {"queue": "default"},
        "app.tasks.cpu_burn": {"queue": "default"},
        "app.tasks.io_bound_task": {"queue": "default"},
        "app.tasks.multiply": {"queue": "default"},
        "app.tasks.summarize": {"queue": "default"},
        "app.tasks.run_chain": {"queue": "default"},
        "app.tasks.run_chord": {"queue": "default"},
        "app.tasks.run_group": {"queue": "default"},
        "app.tasks.limited_task": {"queue": "default"}

    },
    # beat_schedule={
    #     "scheduled_task": {
    #         "task": "app.tasks.scheduled_task",
    #         "schedule": 60.0,  # Run every 60 seconds
    #     },
    # },

    task_soft_time_limit=30,  # Soft time limit for tasks
    task_time_limit=60,  # Hard time limit for tasks

    result_expires=3600,  # Results expire after 1 hour
    result_persistent=False,  # Store results persistently
    result_accept_content=['json'],  # Accept only JSON content

    worker_prefetch_multiplier=4,  # Prefetch multiplier for workers
)

# Import tasks to register them with Celery
# This must be done after the app is configured
from app import tasks  # noqa: F401 - Import needed for task registration