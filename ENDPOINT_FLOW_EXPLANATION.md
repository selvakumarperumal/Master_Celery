# FastAPI + Celery + Redis + Docker - Endpoint Flow Explanation

This document explains what happens when you call each endpoint in the application, with detailed flow diagrams and explanations.

## 🏗️ System Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │    │   FastAPI   │    │    Redis    │    │   Celery    │
│  (Browser)  │────│   Server    │────│   Broker    │────│   Workers   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Components:**
- **FastAPI Server**: Handles HTTP requests and responses
- **Redis**: Acts as message broker and result backend
- **Celery Workers**: Process background tasks asynchronously
- **Docker**: Containerizes all services

---

## 📍 Endpoint 1: GET `/`

### **What Happens:**
```
Client → FastAPI → Immediate Response
```

### **Detailed Flow:**
1. **Client Request**: `curl http://localhost:8000/`
2. **FastAPI Processing**: 
   - Route handler: `home()` function
   - No external dependencies
   - Synchronous processing
3. **Response**: `{"message": "Celery + Redis + Docker !"}`

### **Timeline:** < 1ms
### **No Background Processing Required**

---

## 📍 Endpoint 2: GET `/add/{x}/{y}`

### **What Happens:**
```
Client → FastAPI → Celery Task → Redis Queue → Celery Worker → Redis Result → Client Query
```

### **Detailed Flow:**

#### **Step 1: Initial Request**
```bash
curl http://localhost:8000/add/5/10
```

#### **Step 2: FastAPI Processing**
1. **Route Handler**: `add_numbers(x=5, y=10)`
2. **Task Submission**: `add.delay(5, 10)`
3. **Task ID Generation**: UUID created (e.g., `"abc123-def456-..."`)
4. **Immediate Response**: `{"task_id": "abc123...", "status": "Task submitted"}`

#### **Step 3: Background Task Flow**
```
add.delay(5, 10) → Redis (celery queue) → celery_worker_container → Processing → Redis (result)
```

#### **Step 4: Task Processing (Background)**
1. **Queue Routing**: Task goes to `"celery"` queue
2. **Worker Selection**: `celery_worker_container` picks up task
3. **Task Execution**: 
   ```python
   def add(x, y):
       time.sleep(20)  # Simulate long processing
       return x + y    # Returns 15
   ```
4. **Result Storage**: Result saved to Redis with task_id

#### **Step 5: Result Retrieval**
```bash
curl http://localhost:8000/result/abc123...
```
- **Before completion**: `{"task_id": "abc123...", "status": "Task is still processing"}`
- **After completion**: `{"task_id": "abc123...", "result": 15}`

### **Timeline:** 
- Response: < 100ms
- Task completion: ~20 seconds

### **Container Involved:** `celery_worker_container`

---

## 📍 Endpoint 3: GET `/retry`

### **What Happens:**
```
Client → FastAPI → Celery Task → Redis Queue → Celery Worker → (Random Success/Retry) → Result
```

### **Detailed Flow:**

#### **Step 1: Initial Request**
```bash
curl http://localhost:8000/retry
```

#### **Step 2: FastAPI Processing**
1. **Route Handler**: `retry_task()`
2. **Task Submission**: `failing_task.delay()`
3. **Immediate Response**: `{"task_id": "xyz789...", "status": "Retry task submitted"}`

#### **Step 3: Background Task Flow with Retry Logic**
```
failing_task.delay() → Redis (celery queue) → celery_worker_container → Random Logic → Success/Retry
```

#### **Step 4: Task Processing (Background)**
1. **Queue Routing**: Task goes to `"celery"` queue
2. **Worker Selection**: `celery_worker_container` picks up task
3. **Task Execution**:
   ```python
   @celery_app.task(bind=True, max_retries=3, default_retry_delay=5)
   def failing_task(self):
       if random.choice([True, False]):  # 50% chance
           raise self.retry(exc=ValueError("Random failure"))
       return "Succeeded"
   ```

#### **Step 5: Possible Outcomes**
- **Success (50% chance)**: Returns `"Succeeded"`
- **Failure (50% chance)**: Retries up to 3 times with 5-second delays
- **Final Failure**: After 3 retries, task fails permanently

### **Timeline:**
- Response: < 100ms
- Task completion: 0-20 seconds (depending on retries)

### **Container Involved:** `celery_worker_container`

---

## 📍 Endpoint 4: GET `/important`

### **What Happens:**
```
Client → FastAPI → Celery Task → Redis (high_priority queue) → High Priority Worker → Result
```

### **Detailed Flow:**

#### **Step 1: Initial Request**
```bash
curl http://localhost:8000/important
```

#### **Step 2: FastAPI Processing**
1. **Route Handler**: `run_important_task()`
2. **Task Submission**: `important_task.delay()`
3. **Immediate Response**: `{"task_id": "imp123...", "status": "Important task submitted"}`

#### **Step 3: High Priority Queue Flow**
```
important_task.delay() → Redis (high_priority queue) → high_priority_worker_container → Fast Processing
```

#### **Step 4: Task Processing (Background)**
1. **Queue Routing**: Task goes to `"high_priority"` queue (via task_routes)
2. **Worker Selection**: `high_priority_worker_container` (dedicated worker)
3. **Task Execution**:
   ```python
   def important_task():
       print("This is an important task.")
       return "Important task executed"
   ```
4. **Fast Processing**: No artificial delays, completes immediately

#### **Step 5: Priority Benefits**
- **Dedicated Resources**: 4 worker processes exclusively for high priority
- **No Queue Competition**: Doesn't wait behind regular tasks
- **Faster Response**: Immediate processing

### **Timeline:**
- Response: < 100ms  
- Task completion: < 1 second

### **Container Involved:** `high_priority_worker_container`

---

## 📍 Endpoint 5: GET `/long-running`

### **What Happens:**
```
Client → FastAPI → Celery Task → Redis Queue → Celery Worker → 30-second Processing → Result
```

### **Detailed Flow:**

#### **Step 1: Initial Request**
```bash
curl http://localhost:8000/long-running
```

#### **Step 2: FastAPI Processing**
1. **Route Handler**: `run_long_running_task()`
2. **Task Submission**: `long_running_task.delay()`
3. **Immediate Response**: `{"task_id": "long123...", "status": "Long-running task submitted"}`

#### **Step 3: Background Task Flow**
```
long_running_task.delay() → Redis (celery queue) → celery_worker_container → 30s Processing → Result
```

#### **Step 4: Task Processing (Background)**
1. **Queue Routing**: Task goes to `"celery"` queue
2. **Worker Selection**: `celery_worker_container` picks up task
3. **Task Execution**:
   ```python
   def long_running_task():
       time.sleep(30)  # Simulate very long processing
       return "Long-running task completed"
   ```
4. **Extended Processing**: 30-second delay simulates heavy computation

### **Timeline:**
- Response: < 100ms
- Task completion: ~30 seconds

### **Container Involved:** `celery_worker_container`

---

## 📍 Endpoint 6: GET `/result/{task_id}`

### **What Happens:**
```
Client → FastAPI → Redis Result Backend → Query Result → Response
```

### **Detailed Flow:**

#### **Step 1: Result Query**
```bash
curl http://localhost:8000/result/abc123-def456-...
```

#### **Step 2: FastAPI Processing**
1. **Route Handler**: `get_result(task_id)`
2. **Celery Query**: `celery_app.AsyncResult(task_id)`
3. **Redis Lookup**: Check task status and result in Redis
4. **Result Evaluation**:
   ```python
   if result.ready():  # Task completed
       return {"task_id": task_id, "result": result.result}
   else:               # Task still processing
       return {"task_id": task_id, "status": "Task is still processing"}
   ```

#### **Step 3: Possible Responses**
- **Task Processing**: `{"task_id": "...", "status": "Task is still processing"}`
- **Task Completed**: `{"task_id": "...", "result": <actual_result>}`
- **Task Failed**: `{"task_id": "...", "error": <error_details>}`

### **Timeline:** < 50ms (direct Redis query)

### **No Background Processing Required**

---

## 🔄 Scheduled Tasks (Background)

### **What Happens:**
```
Celery Beat → Redis Queue → Celery Worker → Execution (Every 60 seconds)
```

### **Detailed Flow:**

#### **Step 1: Beat Scheduler**
- **Container**: `beat_container`
- **Schedule**: Every 60 seconds
- **Task**: `app.tasks.scheduled_task`

#### **Step 2: Automatic Execution**
```python
@celery_app.task
def scheduled_task():
    print("This task runs on a schedule.")
    return "Scheduled task executed by Celery Beat"
```

#### **Step 3: Observable Logs**
```bash
docker-compose logs beat
docker-compose logs celery_worker
```

### **Timeline:** Runs every 60 seconds automatically

---

## 🎯 Summary Table

| Endpoint | Response Time | Task Duration | Queue | Worker Container | Purpose |
|----------|---------------|---------------|-------|------------------|---------|
| `/` | < 1ms | N/A | None | N/A | Health check |
| `/add/{x}/{y}` | < 100ms | ~20s | celery | celery_worker | Math operations |
| `/retry` | < 100ms | 0-20s | celery | celery_worker | Retry logic demo |
| `/important` | < 100ms | < 1s | high_priority | high_priority_worker | Priority tasks |
| `/long-running` | < 100ms | ~30s | celery | celery_worker | Heavy processing |
| `/result/{id}` | < 50ms | N/A | None | N/A | Status check |

---

## 🐳 Container Responsibilities

### **fastapi_app_container**
- Handles HTTP requests
- Routes tasks to appropriate queues
- Returns immediate responses
- Manages task result queries

### **redis_container**
- Message broker for task queues
- Result backend for storing task outcomes
- Persistent data storage

### **celery_worker_container**
- Processes regular tasks from "celery" queue
- Handles: `/add`, `/retry`, `/long-running`
- Concurrency: 16 worker processes

### **high_priority_worker_container**
- Processes only "high_priority" queue tasks
- Handles: `/important`
- Concurrency: 4 dedicated worker processes
- Faster response times

### **beat_container**
- Schedules periodic tasks
- Sends scheduled tasks to appropriate queues
- Runs independently of other containers

---

## 🔍 Monitoring Commands

### **Check Container Status**
```bash
docker-compose ps
```

### **View Real-time Logs**
```bash
# All containers
docker-compose logs -f

# Specific containers
docker-compose logs -f celery_worker
docker-compose logs -f high_priority_worker
docker-compose logs -f beat
```

### **Test All Endpoints**
```bash
# Use the provided test script
bash test_script/phase1.sh
```

This comprehensive flow explanation shows exactly what happens when each endpoint is called, from the initial HTTP request to the final result storage and retrieval.
