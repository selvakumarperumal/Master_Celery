# Quick Reference - Celery Testing Commands

## 🚀 Quick Start
```bash
# Build only (without starting)
docker-compose --profile mastering_celery build

# Build clean (no cache)
docker-compose --profile mastering_celery build --no-cache

# Start everything
docker-compose --profile mastering_celery up --build -d

# Test API
curl http://localhost:8000/

# Submit task
curl http://localhost:8000/add/5/10

# Check result (replace task_id)
curl http://localhost:8000/result/YOUR_TASK_ID_HERE

# Stop everything
docker-compose --profile mastering_celery down
```

## 🏗️ Build Commands
```bash
# Standard build
docker-compose --profile mastering_celery build

# Build specific service
docker-compose build fastapi_app

# Clean build (when having issues)
docker-compose --profile mastering_celery build --no-cache

# Fast parallel build
docker-compose --profile mastering_celery build --parallel

# Check built images
docker images | grep master_celery
```

## 📊 Monitoring
```bash
# Watch logs
docker-compose logs -f

# Check worker status
docker-compose logs celery_worker --tail=10

# Check Redis queue
docker exec redis_container redis-cli LLEN celery
```

## 🔧 Debugging
```bash
# Restart services
docker-compose restart celery_worker fastapi_app

# Clear Redis
docker exec redis_container redis-cli FLUSHALL

# Check container status
docker-compose ps
```

## 🧪 Run Full Test Suite
```bash
# Execute automated test script
./test_script.sh
```

## 📝 Performance Testing
```bash
# Multiple tasks
for i in {1..5}; do curl http://localhost:8000/add/$i/$((i+1)); done

# Check processing
docker-compose logs celery_worker --tail=20
```
