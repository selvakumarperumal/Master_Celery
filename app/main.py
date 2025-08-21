from fastapi import FastAPI
from pydantic import BaseModel
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from app.tasks import (
    add,
    failing_task,
    important_task,
    long_running_task,
    cpu_burn,
    io_bound_task,
    run_chain,
    run_chord,
    run_group
)

from app.celery_app import celery_app

app = FastAPI()

# Pydantic models for POST request bodies
class ChainRequest(BaseModel):
    x: int
    y: int

class ChordRequest(BaseModel):
    numbers: List[int]

class GroupRequest(BaseModel):
    numbers: List[int]

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

# Alternative query parameter versions (for compatibility with test scripts)
@app.get("/workflow/chain")
async def run_chain_workflow_query(x: int, y: int):
    """Run a chain workflow with query parameters."""
    task = run_chain.delay(x, y)
    return {"task_id": task.id, "status": "Chain task submitted"}

@app.get("/workflow/chord")
async def run_chord_workflow_default():
    """Run a chord workflow with default numbers."""
    # Use default numbers for testing
    numbers = [1, 2, 3]
    task = run_chord.delay(numbers)
    return {"task_id": task.id, "status": "Chord task submitted"}

@app.get("/workflow/group")
async def run_group_workflow_default():
    """Run a group workflow with default numbers."""
    # Use default numbers for testing  
    numbers = [i for i in range(1, 2000)]  # Example: [1, 2, 3]
    task = run_group.delay(numbers)
    return {"task_id": task.id, "status": "Group task submitted"}

# ============================================================================
# POST ENDPOINTS (RECOMMENDED) - Better for task submission
# ============================================================================

@app.post("/workflow/chain")
async def run_chain_workflow_post(request: ChainRequest):
    """Run a chain workflow using POST with JSON body."""
    task = run_chain.delay(request.x, request.y)
    return {"task_id": task.id, "status": "Chain task submitted", "input": {"x": request.x, "y": request.y}}

@app.post("/workflow/chord")
async def run_chord_workflow_post(request: ChordRequest):
    """Run a chord workflow using POST with JSON body."""
    task = run_chord.delay(request.numbers)
    return {"task_id": task.id, "status": "Chord task submitted", "input": {"numbers": request.numbers}}

@app.post("/workflow/group")
async def run_group_workflow_post(request: GroupRequest):
    """Run a group workflow using POST with JSON body."""
    task = run_group.delay(request.numbers)
    return {"task_id": task.id, "status": "Group task submitted", "input": {"numbers": request.numbers}}

@app.get("/chain/result/{task_id}")
async def get_chain_result(task_id: str):
    """
    Get the final result of a chain workflow by extracting the final task ID.
    
    This endpoint handles the complexity of chain results for you:
    1. Gets the chain structure from the main task
    2. Extracts the final task ID 
    3. Returns the final result directly
    
    Usage: GET /chain/result/{chain_task_id}
    Returns: Final chain result or status
    """
    from app.celery_app import celery_app
    
    try:
        # Get the chain task result
        chain_result = celery_app.AsyncResult(task_id)
        
        if not chain_result.ready():
            return {
                "task_id": task_id,
                "status": "Chain is still setting up...",
                "type": "chain"
            }
        
        # Extract the chain structure
        chain_data = chain_result.result
        
        # Chain structure: [["final_task_id", [["intermediate_task_id", ...], ...]], ...]
        if isinstance(chain_data, list) and len(chain_data) > 0:
            final_task_info = chain_data[0]
            if isinstance(final_task_info, list) and len(final_task_info) > 0:
                final_task_id = final_task_info[0]
                
                # Get the final task result
                final_result = celery_app.AsyncResult(final_task_id)
                
                if final_result.ready():
                    return {
                        "task_id": task_id,
                        "final_task_id": final_task_id,
                        "result": final_result.result,
                        "type": "chain",
                        "status": "completed"
                    }
                else:
                    return {
                        "task_id": task_id,
                        "final_task_id": final_task_id,
                        "status": "Chain is executing...",
                        "type": "chain"
                    }
        
        # If we can't parse the chain structure, return raw result
        return {
            "task_id": task_id,
            "result": chain_data,
            "type": "chain",
            "status": "completed_raw"
        }
        
    except Exception as e:
        return {
            "task_id": task_id,
            "error": str(e),
            "type": "chain",
            "status": "error"
        }


