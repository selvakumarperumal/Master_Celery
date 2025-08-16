# Celery + FastAPI + Redis Testing Commands

This file contains all the testing commands used to validate the Celery, FastAPI, and Redis setup.

## 1. Docker Compose Management

### Building Containers Only (Without Starting)

```bash
# Build all services (recommended for first-time setup)
# This builds both fastapi_app and celery_worker services defined in docker-compose.yml
# --profile mastering_celery ensures only services with this profile are built
docker-compose --profile mastering_celery build

# Build with no cache (clean build - rebuilds everything from scratch)
# Use this when you want to ensure fresh build or having build issues
# Ignores all previously cached layers and downloads/installs everything again
docker-compose --profile mastering_celery build --no-cache

# Build specific service only (faster when you only changed one service)
# Only builds the specified service, not all services
# Useful when you only modified fastapi_app code but not celery_worker
docker-compose build fastapi_app
docker-compose build celery_worker

# Build multiple specific services (but not all)
# Builds only the services you specify, saves time
docker-compose build fastapi_app celery_worker

# Build in parallel (faster for multiple services)
# Builds multiple services simultaneously instead of one after another
# Significantly faster when building multiple services
docker-compose --profile mastering_celery build --parallel

# Build with progress output (detailed build information)
# Shows detailed step-by-step build process instead of simplified output
# Useful for debugging build issues or understanding what's happening
docker-compose --profile mastering_celery build --progress=plain

# Build and show build context (for debugging)
# Combines detailed progress with no-cache for maximum visibility
# Use when troubleshooting complex build problems
docker-compose --profile mastering_celery build --progress=plain --no-cache

# Force rebuild (ignore cache completely and remove intermediate containers)
# Most aggressive build option - cleans up everything and rebuilds
# Use when having persistent build issues or corrupted cache
docker-compose --profile mastering_celery build --force-rm --no-cache
```

### Alternative Building Methods

```bash
# Using docker build directly (manual approach)
# This reads the Dockerfile in current directory and tags the image
# The "." at the end means "use current directory as build context"
docker build -t master_celery-fastapi_app .
docker build -t master_celery-celery_worker .

# Build with custom tag (useful for versioning or different environments)
# Instead of auto-generated name, you specify your own image name
docker build -t my-custom-celery-app .
docker build -t my-app:v1.0 .
docker build -t my-app:latest .

# Build with build arguments (pass variables to Dockerfile)
# These args can be used in Dockerfile with ARG instruction
# Example: ARG PYTHON_VERSION=3.11 in Dockerfile
docker build --build-arg PYTHON_VERSION=3.11 -t celery-app .
docker build --build-arg ENV=production --build-arg DEBUG=false -t celery-app .

# Build for specific platform (useful for multi-architecture)
# Forces build for specific CPU architecture (ARM, Intel, etc.)
docker build --platform linux/amd64 -t celery-app .
docker build --platform linux/arm64 -t celery-app .

# Build with custom context and Dockerfile location
# -f specifies Dockerfile path, last argument is build context
docker build -f ./docker/Dockerfile -t celery-app ./app
docker build -f ./Dockerfile.prod -t celery-app .
```

### Build Verification

```bash
# List built images (see what Docker images exist locally)
# Shows all images with "master_celery" in the name
# Displays: Repository, Tag, Image ID, Creation time, Size
docker images | grep master_celery

# Inspect image details (deep dive into image configuration)
# Shows complete JSON metadata: environment variables, ports, volumes, etc.
# Useful for verifying build configuration and troubleshooting
docker inspect master_celery-fastapi_app
docker inspect master_celery-celery_worker

# Check image size (see how much disk space images use)
# Displays formatted table with repository, tag, and size
# Helps identify bloated images that need optimization
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Show image layers (understand what's inside the image)
# Displays each layer: commands that created them, size, time
# Useful for optimizing Dockerfile and understanding build process
docker history master_celery-fastapi_app

# Test image functionality without compose (quick validation)
# Runs a simple command inside the image to verify it works
# Exits immediately after test, doesn't start full application
docker run --rm master_celery-fastapi_app python -c "import app.celery_app; print('Build OK')"
```

### Start Services
```bash
# Start all services with the mastering_celery profile
docker-compose --profile mastering_celery up --build -d

# Start services without building (if images already exist)
docker-compose --profile mastering_celery up -d

### Build and Start Combined

```bash
# Build and start in one command (most common development workflow)
# First builds all images, then starts all containers
# Equivalent to: build + up, but more convenient
docker-compose --profile mastering_celery up --build -d

# Build, start, and recreate containers (force restart everything)
# Stops existing containers, rebuilds images, creates new containers
# Use when containers are in weird state or config changed significantly
docker-compose --profile mastering_celery up --build --force-recreate -d

# Build specific service and start all (selective rebuild)
# Only rebuilds fastapi_app but starts all services (including celery_worker, redis)
# Useful when you only changed one service but need the full stack running
docker-compose build fastapi_app && docker-compose --profile mastering_celery up -d
```

### Build Troubleshooting

```bash
# Clean build (remove intermediate containers and rebuild from scratch)
# --force-rm removes intermediate containers even if build fails
# --no-cache ignores all cached layers and rebuilds everything
# Use when builds are failing mysteriously or behaving inconsistently
docker-compose --profile mastering_celery build --force-rm --no-cache

# Check build logs for errors (verbose build output)
# --progress=plain shows detailed step-by-step build process
# Helps identify exactly where builds are failing
# Look for red ERROR messages or failed RUN commands
docker-compose --profile mastering_celery build --progress=plain

# Remove dangling images and rebuild (clean up orphaned images)
# docker image prune removes unused images taking up disk space
# Then rebuilds cleanly without conflicting old images
docker image prune -f
docker-compose --profile mastering_celery build

# Complete cleanup and rebuild (nuclear option)
# docker system prune removes ALL unused Docker resources
# Use when Docker environment is completely messed up
# WARNING: This removes all unused containers, networks, images!
docker system prune -f
docker-compose --profile mastering_celery build --no-cache
```

### Development Build Workflows

```bash
# Quick development rebuild (only changed layers)
# Docker's smart caching only rebuilds layers that actually changed
# If you only modified Python code, won't reinstall dependencies
# Fastest option for iterative development
docker-compose build

# Development with volume mounting (no rebuild needed for code changes)
# Volume mounts sync your local code directory with container
# Code changes appear instantly without rebuilding image
# Perfect for development - change code, refresh browser, see changes
docker-compose --profile mastering_celery up -d
# Code changes are reflected immediately due to volume mounts in docker-compose.yml

# Production build (optimized, no development shortcuts)
# --no-cache ensures completely fresh build
# --no-build prevents accidental rebuilds during startup
# Creates clean, optimized images for deployment
docker-compose --profile mastering_celery build --no-cache
docker-compose --profile mastering_celery up -d --no-build

# Build with specific dockerfile (when you have multiple Dockerfiles)
# -f specifies which docker-compose file to use
# Useful for different environments (dev, staging, prod)
docker-compose -f docker-compose.yml build
docker-compose -f docker-compose.prod.yml build
```

### Multi-Stage Build Scenarios

```bash
# If using multi-stage Dockerfile, build specific stage
# Multi-stage Dockerfiles have multiple FROM statements
# --target specifies which stage to build (development vs production)
# Example: FROM python:3.11 AS development, FROM python:3.11 AS production
docker build --target development -t celery-app-dev .
docker build --target production -t celery-app-prod .

# Build with build context from different directory
# -f specifies Dockerfile location, last argument is build context
# Build context determines which files are available during build
# Useful when Dockerfile is in subdirectory but needs access to parent files
docker build -f ./docker/Dockerfile -t celery-app ./app

# Build with build secrets (if using BuildKit for secure builds)
# DOCKER_BUILDKIT enables advanced Docker features
# --secret provides secure access to files during build
# Secrets are not stored in final image layers (more secure)
DOCKER_BUILDKIT=1 docker build --secret id=requirements,src=requirements.txt .
```

### Understanding Docker Build Command Structure

```bash
# Basic structure: docker build [OPTIONS] PATH
# PATH is the "build context" - the directory containing files for the build

# What happens when you run: docker build -t master_celery-fastapi_app .
# 1. Docker looks for "Dockerfile" in current directory (.)
# 2. Reads each instruction in Dockerfile and executes them in order
# 3. Each instruction creates a new layer in the image
# 4. -t tags the final image with name "master_celery-fastapi_app"
# 5. The "." means "use current directory as build context"

# Build context explained:
# Everything in the build context directory gets sent to Docker daemon
# Only files in build context can be COPY'd or ADD'ed to image
# Use .dockerignore to exclude files (like .git, node_modules, etc.)

# Example Dockerfile execution flow:
# FROM python:3.11-slim     → Downloads base Python image
# WORKDIR /app              → Sets working directory to /app
# COPY requirements.txt .   → Copies requirements.txt from build context to /app/
# RUN pip install -r requirements.txt → Installs Python packages
# COPY app/ .               → Copies app/ directory from build context to /app/
# CMD ["uvicorn", "main:app"] → Sets default command to run when container starts
```

### Stop Services
```bash
# Stop all services
docker-compose --profile mastering_celery down

# Stop and remove volumes (clean slate)
docker-compose --profile mastering_celery down -v
```

### Restart Specific Services
```bash
# Restart Celery worker and FastAPI app
docker-compose restart celery_worker fastapi_app

# Restart all services
docker-compose --profile mastering_celery restart
```

## 2. Service Health Checks

### Check Container Status
```bash
# List running containers
docker-compose ps

# Check specific service status
docker-compose logs fastapi_app
docker-compose logs celery_worker
docker-compose logs redis
```

### Check Service Logs
```bash
# View recent logs (last 20 lines)
docker-compose logs --tail=20

# View logs for specific service
docker-compose logs fastapi_app --tail=10
docker-compose logs celery_worker --tail=10

# Follow logs in real-time
docker-compose logs celery_worker -f

# View logs from last X seconds
docker-compose logs celery_worker --since=30s
```

## 3. API Testing

### Basic Health Checks
```bash
# Test FastAPI home endpoint
curl http://localhost:8000/

# Expected response: {"message":"Celery + Redis + Docker !"}
```

### Task Submission
```bash
# Submit addition tasks
curl http://localhost:8000/add/5/10
curl http://localhost:8000/add/7/8
curl http://localhost:8000/add/20/30

# Expected response: {"task_id":"uuid-string","status":"Task submitted"}
```

### Task Result Checking
```bash
# Check task result (replace with actual task_id)
curl http://localhost:8000/result/a3e866eb-432d-4c64-b5c1-733e764a67e8

# Expected responses:
# While processing: {"task_id":"uuid","status":"Task is still processing"}
# When complete: {"task_id":"uuid","result":15}
```

## 4. Redis Debugging

### Check Redis Connection
```bash
# Access Redis CLI
docker exec redis_container redis-cli

# Check all keys in Redis
docker exec redis_container redis-cli KEYS "*"

# Check queue length
docker exec redis_container redis-cli LLEN default
docker exec redis_container redis-cli LLEN celery

# Check specific queue contents
docker exec redis_container redis-cli LRANGE default 0 -1
```

### Redis Queue Management
```bash
# Monitor Redis operations in real-time
docker exec redis_container redis-cli MONITOR

# Get Redis info
docker exec redis_container redis-cli INFO

# Check memory usage
docker exec redis_container redis-cli INFO memory
```

## 5. Celery Debugging

### Direct Celery Commands
```bash
# Execute Celery commands inside worker container
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect active
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect stats
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect reserved

# Check registered tasks
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect registered
```

### Worker Management
```bash
# Check worker status
docker exec celery_worker_container celery -A app.celery_app.celery_app status

# Purge all tasks from queues
docker exec celery_worker_container celery -A app.celery_app.celery_app purge

# Control worker operations
docker exec celery_worker_container celery -A app.celery_app.celery_app control shutdown
```

## 6. Load Testing

### Multiple Task Submission
```bash
# Submit multiple tasks quickly
for i in {1..5}; do curl http://localhost:8000/add/$i/$((i+1)); done

# Submit tasks with different values
curl http://localhost:8000/add/100/200
curl http://localhost:8000/add/1000/2000
curl http://localhost:8000/add/50/75
```

### Stress Testing
```bash
# Submit many tasks in parallel (requires parallel tool or xargs)
seq 1 10 | xargs -I {} -P 5 curl http://localhost:8000/add/{}/{}

# Or using a simple loop
for i in {1..20}; do curl http://localhost:8000/add/$i/$((i*2)) & done; wait
```

## 7. Container Debugging

### Enter Container Shells
```bash
# Enter FastAPI app container
docker exec -it fastapi_app_container /bin/bash

# Enter Celery worker container
docker exec -it celery_worker_container /bin/bash

# Enter Redis container
docker exec -it redis_container /bin/bash
```

### Check Container Resources
```bash
# Check container stats
docker stats

# Check specific container resources
docker exec fastapi_app_container ps aux
docker exec celery_worker_container ps aux
```

## 8. Network Testing

### Container Network Connectivity
```bash
# Test connectivity between containers
docker exec fastapi_app_container ping redis
docker exec celery_worker_container ping redis
docker exec fastapi_app_container ping celery_worker_container

# Check port accessibility
docker exec fastapi_app_container nc -zv redis 6379
```

### Host Network Testing
```bash
# Test from host machine
curl -v http://localhost:8000/
telnet localhost 8000
telnet localhost 6379
```

## 9. Troubleshooting Commands

### When Tasks Are Not Processing
```bash
# 1. Check if tasks are in queue
docker exec redis_container redis-cli LLEN celery
docker exec redis_container redis-cli LLEN default

# 2. Check worker registration
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect registered

# 3. Check worker active tasks
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect active

# 4. Restart worker
docker-compose restart celery_worker
```

### When API Returns Errors
```bash
# 1. Check FastAPI logs
docker-compose logs fastapi_app --tail=50

# 2. Check if Redis is accessible from FastAPI
docker exec fastapi_app_container nc -zv redis 6379

# 3. Test Redis connection from app container
docker exec fastapi_app_container python -c "import redis; r=redis.Redis(host='redis', port=6379, db=0); print(r.ping())"
```

### When Containers Won't Start
```bash
# 1. Check Docker images
docker images | grep master_celery

# 2. Force rebuild
docker-compose --profile mastering_celery build --no-cache

# 3. Check for port conflicts
netstat -tulpn | grep :8000
netstat -tulpn | grep :6379

# 4. Clean up and restart
docker-compose --profile mastering_celery down -v
docker system prune -f
docker-compose --profile mastering_celery up --build -d
```

## 10. Performance Monitoring

### Real-time Monitoring
```bash
# Monitor all logs in real-time
docker-compose logs -f

# Monitor specific service performance
docker stats fastapi_app_container celery_worker_container redis_container

# Monitor Redis operations
docker exec redis_container redis-cli MONITOR
```

### Task Performance Testing
```bash
# Time task execution
time curl http://localhost:8000/add/1/2

# Test with larger numbers
curl http://localhost:8000/add/999999/1000001
```

## 11. Cleanup Commands

### Clean Environment
```bash
# Stop all services and remove volumes
docker-compose --profile mastering_celery down -v

# Remove all related images
docker rmi $(docker images | grep master_celery | awk '{print $3}')

# Clean up Docker system
docker system prune -f
docker volume prune -f
```

### Reset Database/Queue
```bash
# Clear all Redis data
docker exec redis_container redis-cli FLUSHALL

# Purge all Celery tasks
docker exec celery_worker_container celery -A app.celery_app.celery_app purge -f
```

## Sample Test Workflow

Here's a complete test workflow to validate the system:

```bash
# 1. Start services
docker-compose --profile mastering_celery up --build -d

# 2. Wait for services to be ready
sleep 10

# 3. Test basic connectivity
curl http://localhost:8000/

# 4. Submit a test task
TASK_RESPONSE=$(curl -s http://localhost:8000/add/5/10)
echo "Task submitted: $TASK_RESPONSE"

# 5. Extract task ID (requires jq)
TASK_ID=$(echo $TASK_RESPONSE | jq -r '.task_id')
echo "Task ID: $TASK_ID"

# 6. Wait for task to complete (20 seconds + buffer)
sleep 25

# 7. Check result
curl http://localhost:8000/result/$TASK_ID

# 8. Check logs
docker-compose logs celery_worker --tail=5

# 9. Clean up
docker-compose --profile mastering_celery down
```

## Common Issues and Solutions

### Issue: Connection Refused
**Solution**: Check environment variables and ensure Redis is running
```bash
docker-compose logs redis
docker exec fastapi_app_container env | grep CELERY
```

### Issue: Tasks Not Processing
**Solution**: Check queue routing and worker registration
```bash
docker exec redis_container redis-cli KEYS "*"
docker exec celery_worker_container celery -A app.celery_app.celery_app inspect registered
```

### Issue: Import Errors
**Solution**: Check Python path and module structure
```bash
docker exec fastapi_app_container python -c "from app.celery_app import celery_app; print('OK')"
docker exec celery_worker_container python -c "from app.tasks import add; print('OK')"
```

## Build Commands Quick Reference

### Most Common Build Commands

```bash
# 🚀 Standard build (most common)
docker-compose --profile mastering_celery build

# 🔄 Clean build (when having issues)
docker-compose --profile mastering_celery build --no-cache

# ⚡ Fast parallel build
docker-compose --profile mastering_celery build --parallel

# 🏗️ Build specific service only
docker-compose build fastapi_app

# 🔧 Build and start together
docker-compose --profile mastering_celery up --build -d

# 🧹 Complete clean build
docker system prune -f && docker-compose --profile mastering_celery build --no-cache
```

### Build Status and Verification

```bash
# Check what images were built
docker images | grep master_celery

# Verify image details
docker inspect master_celery-fastapi_app | grep -A 5 Config

# Check build history
docker history master_celery-fastapi_app --no-trunc

# Test image without compose
docker run --rm master_celery-fastapi_app python -c "import app.celery_app; print('Build OK')"
```

### When to Use Each Build Command

| Scenario | Command | When to Use |
|----------|---------|-------------|
| **First time setup** | `docker-compose --profile mastering_celery build` | Initial project setup |
| **Code changes** | Volume mounts handle this automatically | No rebuild needed |
| **Dependency changes** | `docker-compose build` | When requirements.txt changes |
| **Build issues** | `docker-compose build --no-cache` | When builds fail or behave strangely |
| **Complete reset** | `docker system prune -f && docker-compose build --no-cache` | Nuclear option - clean everything |
| **Specific service** | `docker-compose build fastapi_app` | Only one service needs rebuilding |
| **Development** | `docker-compose up --build` | Quick build + start for testing |
| **Production** | `docker-compose build --no-cache && docker-compose up -d` | Clean build for deployment |
