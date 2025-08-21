from app.celery_app import celery_app
from celery.result import AsyncResult

def unwrap_result(task_id):
    current = AsyncResult(id=task_id,
                          app=celery_app)

    while current.ready() and isinstance(current.result, str) and len(current.result) == 36:
        current = AsyncResult(id=current.result, app=celery_app)

    return current