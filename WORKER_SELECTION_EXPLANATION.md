# 🎯 How Celery Picks Workers: Regular vs High Priority

This document explains exactly how Celery determines which worker processes your tasks based on your configuration.

## 🏗️ Worker Configuration Overview

### **1. Regular Celery Worker**
```yaml
# docker-compose.yml
celery_worker:
  command: celery -A app.celery_app.celery_app worker --loglevel=info
  container_name: celery_worker_container
```

### **2. High Priority Worker**  
```yaml
# docker-compose.yml
high_priority_worker:
  command: celery -A app.celery_app.celery_app worker --loglevel=info --concurrency=4 -Q high_priority
  container_name: high_priority_worker_container
```

**Key Difference**: The `-Q high_priority` flag makes this worker **ONLY** listen to the `high_priority` queue.

---

## 🎯 Task Routing Configuration

### **From `celery_app.py`:**
```python
task_routes={
    "app.tasks.add": {"queue": "celery"},
    "app.tasks.failing_task": {"queue": "celery"},
    "app.tasks.important_task": {"queue": "high_priority"},  # 🎯 This goes to high priority!
    "app.tasks.long_running_task": {"queue": "celery"},
    "app.tasks.scheduled_task": {"queue": "celery"},
}
```

---

## 🔄 How Worker Selection Works

### **Step-by-Step Process:**

#### **1. Task Submission**
When you call `task_name.delay()`, Celery:
1. Checks the `task_routes` configuration
2. Determines which queue to send the task to
3. Publishes the task message to Redis with queue information

#### **2. Queue Assignment**
```python
# Example task calls and their queue destinations:

add.delay(5, 10)              → Queue: "celery"
failing_task.delay()          → Queue: "celery"  
important_task.delay()        → Queue: "high_priority"  # 🎯 Special routing!
long_running_task.delay()     → Queue: "celery"
scheduled_task.delay()        → Queue: "celery"
```

#### **3. Worker Listening**
```
┌─────────────────────┐    ┌─────────────────────┐
│   celery_worker     │    │ high_priority_worker│
│   container         │    │   container         │
├─────────────────────┤    ├─────────────────────┤
│ Listens to:         │    │ Listens to:         │
│ ✅ "celery" queue   │    │ ✅ "high_priority"  │
│ ✅ "high_priority"  │    │ ❌ "celery" (ignored│
│ ✅ ALL queues       │    │                     │
│   (default behavior)│    │                     │
└─────────────────────┘    └─────────────────────┘
```

#### **4. Task Pickup**
- **Regular Worker**: Picks up from ANY queue (including high_priority)
- **High Priority Worker**: ONLY picks up from "high_priority" queue

---

## 🎯 Detailed Examples

### **Example 1: `/add/5/10` Endpoint**
```python
# main.py
result = add.delay(5, 10)

# Flow:
add.delay(5, 10) 
→ task_routes: "app.tasks.add" → {"queue": "celery"}
→ Redis queue: "celery" 
→ Worker selection: celery_worker_container picks it up
→ Processing: One of 16 worker processes handles it
```

### **Example 2: `/important` Endpoint**
```python
# main.py  
result = important_task.delay()

# Flow:
important_task.delay()
→ task_routes: "app.tasks.important_task" → {"queue": "high_priority"}
→ Redis queue: "high_priority"
→ Worker selection: high_priority_worker_container picks it up
→ Processing: One of 4 dedicated worker processes handles it
```

---

## ⚡ Priority System Advantages

### **Why High Priority Works Better:**

#### **1. Dedicated Resources**
```
Regular Worker Pool:
┌─────────────────────────────────────────────────────────┐
│ 16 processes handling ALL regular tasks                 │
│ [add][failing][long_running][scheduled][important*]     │
│ *Can also handle high_priority if no dedicated worker  │
└─────────────────────────────────────────────────────────┘

High Priority Worker Pool:
┌─────────────────────────────────────────────────────────┐
│ 4 processes EXCLUSIVELY for high priority tasks        │
│ [important][important][important][important]            │
│ No competition from regular tasks                       │
└─────────────────────────────────────────────────────────┘
```

#### **2. No Queue Competition**
- **Regular tasks** may wait behind 100s of other tasks
- **High priority tasks** get immediate attention from dedicated workers

#### **3. Scalability**
```bash
# Scale regular workers
docker-compose up --scale celery_worker=3

# Scale high priority workers independently  
docker-compose up --scale high_priority_worker=2
```

---

## 🔍 Worker Commands Breakdown

### **Regular Worker Command:**
```bash
celery -A app.celery_app.celery_app worker --loglevel=info
```
- **`-A app.celery_app.celery_app`**: Points to your Celery app instance
- **`worker`**: Starts worker process
- **`--loglevel=info`**: Sets logging level
- **No `-Q` flag**: Listens to ALL queues (default: "celery", but also "high_priority")

### **High Priority Worker Command:**
```bash
celery -A app.celery_app.celery_app worker --loglevel=info --concurrency=4 -Q high_priority
```
- **`-A app.celery_app.celery_app`**: Points to your Celery app instance
- **`worker`**: Starts worker process  
- **`--loglevel=info`**: Sets logging level
- **`--concurrency=4`**: Limits to 4 worker processes (vs default 16)
- **`-Q high_priority`**: 🎯 **ONLY** listens to "high_priority" queue

---

## 📊 Task Distribution Summary

| Task Function | Endpoint | Queue | Worker Container | Concurrency |
|---------------|----------|-------|------------------|-------------|
| `add` | `/add/{x}/{y}` | `celery` | `celery_worker_container` | 16 processes |
| `failing_task` | `/retry` | `celery` | `celery_worker_container` | 16 processes |
| `long_running_task` | `/long-running` | `celery` | `celery_worker_container` | 16 processes |
| `scheduled_task` | (automatic) | `celery` | `celery_worker_container` | 16 processes |
| **`important_task`** | **`/important`** | **`high_priority`** | **`high_priority_worker_container`** | **4 processes** |

---

## 🔧 How to Verify Worker Behavior

### **1. Check Queue Assignment**
```python
# In Python shell
from app.tasks import important_task, add

# Check task routing
print(important_task.delay().queue)  # Should be 'high_priority'
print(add.delay(1,2).queue)          # Should be 'celery'
```

### **2. Monitor Worker Logs**
```bash
# Watch regular worker
docker-compose logs -f celery_worker

# Watch high priority worker  
docker-compose logs -f high_priority_worker
```

### **3. Redis Queue Inspection**
```bash
# Connect to Redis
docker exec -it redis_container redis-cli

# Check queue lengths
LLEN celery
LLEN high_priority

# View pending tasks
LRANGE celery 0 -1
LRANGE high_priority 0 -1
```

---

## 🎯 Key Takeaways

1. **Task Routing**: Determined by `task_routes` in `celery_app.py`
2. **Worker Specialization**: High priority worker ONLY handles `high_priority` queue
3. **Performance**: High priority tasks get dedicated resources and faster processing
4. **Flexibility**: You can add more queue types and specialized workers
5. **Monitoring**: Use logs and Redis inspection to verify behavior

The worker selection is **completely automatic** based on your configuration - no manual intervention needed!
