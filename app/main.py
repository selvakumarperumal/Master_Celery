from fastapi import FastAPI
from app.tasks import (
    add,
    failing_task,
    important_task,
    long_running_task,
    cpu_burn,
    io_bound_task
)

app = FastAPI()

@app.get("/")
async def home():
    """Home endpoint."""
    return {"message": "Celery + Redis + Docker !"}

# FastAPI (/add/{x}/{y}) → add.delay(x, y) → celery queue → celery_worker → Result
@app.get("/add/{x}/{y}")
async def add_numbers(x: int, y: int):
    """Add two numbers using Celery."""
    result = add.delay(x, y)
    return {"task_id": result.id, "status": "Task submitted"}

# FastAPI (/retry) → failing_task.delay() → celery queue → celery_worker → Result
@app.get("/retry")
def retry_task():
    """Retry a task with random failure."""
    result = failing_task.delay()
    return {"task_id": result.id, "status": "Retry task submitted"}

# FastAPI (/important) → important_task.delay() → high_priority queue → high_priority_worker → Result
@app.get("/important")
async def run_important_task():
    """Run an important task."""
    result = important_task.delay()
    return {"task_id": result.id, "status": "Important task submitted"}

# FastAPI (/long-running) → long_running_task.delay() → celery queue → celery_worker → Result
@app.get("/long-running")
async def run_long_running_task():
    """Run a long-running task."""
    result = long_running_task.delay()
    return {"task_id": result.id, "status": "Long-running task submitted"}


@app.get("/result/{task_id}")
async def get_result(task_id: str):
    """Get the result of a Celery task."""
    from app.celery_app import celery_app
    result = celery_app.AsyncResult(task_id)
    if result.ready():
        return {"task_id": task_id, "result": result.result}
    else:
        return {"task_id": task_id, "status": "Task is still processing"}
    
@app.get("/bulk/cpu")
async def bulk_cpu_tasks(count: int = 500, n: int = 200):
    ids = [cpu_burn.delay(n).id for _ in range(count)]
    return {"task_ids": ids, "status": "Bulk CPU tasks submitted"}

@app.get("/bulk/io")
async def run_io_bound_task(count: int = 500, ms: int = 200):
    ids = [io_bound_task.delay(ms).id for _ in range(count)]
    return {"task_ids": ids, "status": "Bulk I/O tasks submitted"}
