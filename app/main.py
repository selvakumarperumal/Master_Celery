from fastapi import FastAPI
from app.tasks import add

app = FastAPI()

@app.get("/")
async def home():
    """Home endpoint."""
    return {"message": "Celery + Redis + Docker !"}

@app.get("/add/{x}/{y}")
async def add_numbers(x: int, y: int):
    """Add two numbers using Celery."""
    result = add.delay(x, y)
    return {"task_id": result.id, "status": "Task submitted"}

@app.get("/result/{task_id}")
async def get_result(task_id: str):
    """Get the result of a Celery task."""
    from app.celery_app import celery_app
    result = celery_app.AsyncResult(task_id)
    if result.ready():
        return {"task_id": task_id, "result": result.result}
    else:
        return {"task_id": task_id, "status": "Task is still processing"}