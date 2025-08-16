from app.celery_app import celery_app
import time

@celery_app.task
def add(x, y):
    """Add two numbers."""
    time.sleep(20)  # Simulate a long-running task
    return x + y
