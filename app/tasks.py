from app.celery_app import celery_app
import time
import random

@celery_app.task
def add(x, y):
    """Add two numbers."""
    time.sleep(20)  # Simulate a long-running task
    return x + y

# Task with retries
@celery_app.task(bind=True, max_retries=3, default_retry_delay=5)
def failing_task(self):
    """Random failure example task."""
    if random.choice([True, False]):
        raise self.retry(exc=ValueError("Random failure"))
    return "Succeeded"

# Scheduled task example
@celery_app.task
def scheduled_task():
    """Example of a scheduled task."""
    print("This task runs on a schedule.")
    return "Scheduled task executed by Celery Beat"

# Routed Task go to the high priority queue
@celery_app.task
def important_task():
    """Example of a task that goes to a high priority queue."""
    print("This is an important task.")
    return "Important task executed"

# Task with a long-running operation
@celery_app.task
def long_running_task():
    """Example of a task with a long-running operation."""
    time.sleep(30)  # Simulate a long-running task
    return "Long-running task completed"

# Wokrload variety for tuning Celery
@celery_app.task
def cpu_burn(n: int = 5_000_00):
    """Simple cpu bound loop to burn CPU cycles."""
    s = 0
    for i in range(n):
        s += i
    return s

@celery_app.task
def io_bound_task(ms: int = 200):
    """Example of an I/O bound task."""
    time.sleep(ms / 1000)
    return f"IO bound task completed after {ms} ms"