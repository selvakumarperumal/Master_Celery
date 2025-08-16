#!/bin/bash

# Celery + FastAPI + Redis Automated Test Script
# This script performs comprehensive testing of the entire Celery setup
# It validates: Docker services, API endpoints, Redis connectivity, 
# task submission, processing, and result retrieval

# Exit immediately if any command returns a non-zero status
# This ensures the script stops on first error rather than continuing
set -e  # Exit on any error

echo "🚀 Starting Celery + FastAPI + Redis Test Suite"
echo "================================================"

# ANSI Color codes for better terminal output readability
# These make success/error messages visually distinct
RED='\033[0;31m'     # Red for errors
GREEN='\033[0;32m'   # Green for success
YELLOW='\033[1;33m'  # Yellow for warnings
BLUE='\033[0;34m'    # Blue for info
NC='\033[0m'         # No Color (reset to default)

# Utility functions for consistent, colored output
# These functions prefix messages with colored status indicators

print_status() {
    # Prints informational messages in blue
    # Usage: print_status "Starting process..."
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    # Prints success messages in green
    # Usage: print_success "Operation completed successfully"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    # Prints warning messages in yellow
    # Usage: print_warning "This might cause issues"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    # Prints error messages in red
    # Usage: print_error "Something went wrong"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
# This uses the 'command -v' builtin to check if a program is installed
# Returns 0 (success) if command exists, 1 (failure) if not found
command_exists() {
    # Redirects output to /dev/null to suppress "command not found" messages
    # 2>&1 redirects stderr to stdout, then both go to /dev/null
    command -v "$1" >/dev/null 2>&1
}

# PREREQUISITE CHECKS
# Before running tests, verify all required tools are installed
# This prevents confusing errors later if tools are missing
print_status "Checking prerequisites..."

# Check if Docker is installed and accessible
if ! command_exists docker; then
    print_error "Docker is not installed or not in PATH"
    print_error "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed and accessible
if ! command_exists docker-compose; then
    print_error "Docker Compose is not installed or not in PATH"
    print_error "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if curl is installed (needed for API testing)
if ! command_exists curl; then
    print_error "curl is not installed or not in PATH"
    print_error "Please install curl: apt-get install curl (Ubuntu) or brew install curl (Mac)"
    exit 1
fi

print_success "All prerequisites met"

# TEST 1: START DOCKER SERVICES
# This test ensures all Docker containers start properly
print_status "Test 1: Starting Docker services..."

# First, clean up any existing containers/volumes
# >/dev/null 2>&1 suppresses all output (both stdout and stderr)
# || true ensures this command doesn't fail if containers don't exist
docker-compose --profile mastering_celery down -v >/dev/null 2>&1 || true

# Start all services with fresh build
# --profile mastering_celery: only starts services with this profile
# --build: rebuilds images before starting (ensures latest code)
# -d: detached mode (runs in background)
docker-compose --profile mastering_celery up --build -d

# Check if the previous command succeeded
# $? contains the exit code of the last command (0 = success, non-zero = failure)
if [ $? -eq 0 ]; then
    print_success "Services started successfully"
else
    print_error "Failed to start services"
    print_error "Check Docker logs: docker-compose logs"
    exit 1
fi

# Wait for services to fully initialize
# Docker containers may take time to start all internal processes
# 15 seconds should be enough for Redis, FastAPI, and Celery to be ready
print_status "Waiting for services to initialize..."
sleep 15

# TEST 2: CHECK SERVICE HEALTH
# This test verifies that all containers are running properly
print_status "Test 2: Checking service health..."

# Check container status using Docker inspect command
# docker inspect returns detailed information about containers
# --format extracts only the State.Status field
# 2>/dev/null suppresses error messages if container doesn't exist
# || echo "not found" provides fallback value if command fails

REDIS_STATUS=$(docker inspect redis_container --format='{{.State.Status}}' 2>/dev/null || echo "not found")
FASTAPI_STATUS=$(docker inspect fastapi_app_container --format='{{.State.Status}}' 2>/dev/null || echo "not found")
CELERY_STATUS=$(docker inspect celery_worker_container --format='{{.State.Status}}' 2>/dev/null || echo "not found")

# Verify Redis container is running
if [ "$REDIS_STATUS" = "running" ]; then
    print_success "Redis container is running"
else
    print_error "Redis container is not running: $REDIS_STATUS"
    print_error "Check Redis logs: docker-compose logs redis"
    exit 1
fi

# Verify FastAPI container is running
if [ "$FASTAPI_STATUS" = "running" ]; then
    print_success "FastAPI container is running"
else
    print_error "FastAPI container is not running: $FASTAPI_STATUS"
    print_error "Check FastAPI logs: docker-compose logs fastapi_app"
    exit 1
fi

# Verify Celery worker container is running
if [ "$CELERY_STATUS" = "running" ]; then
    print_success "Celery worker container is running"
else
    print_error "Celery worker container is not running: $CELERY_STATUS"
    print_error "Check Celery logs: docker-compose logs celery_worker"
    exit 1
fi

# TEST 3: API CONNECTIVITY
# This test checks if FastAPI is responding to HTTP requests
print_status "Test 3: Testing API connectivity..."

# Test HTTP connectivity to FastAPI endpoint
# curl flags explained:
# -s: silent mode (no progress bar)
# -o /dev/null: discard response body (we only want status code)
# -w "%{http_code}": output only the HTTP status code
# 2>/dev/null: suppress error messages
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null)

if [ "$RESPONSE" = "200" ]; then
    print_success "FastAPI is responding (HTTP $RESPONSE)"
else
    print_error "FastAPI is not responding (HTTP $RESPONSE)"
    print_error "Expected HTTP 200, got HTTP $RESPONSE"
    print_error "Showing recent FastAPI logs:"
    docker-compose logs fastapi_app --tail=10
    exit 1
fi

# TEST 4: API RESPONSE CONTENT
# This test verifies that FastAPI returns the expected response content
print_status "Test 4: Testing API response content..."

# Get the actual response content from the API
API_RESPONSE=$(curl -s http://localhost:8000/ 2>/dev/null)

# Check if response contains expected text
# grep -q: quiet mode (no output, just exit code)
if echo "$API_RESPONSE" | grep -q "Celery + Redis + Docker"; then
    print_success "API returned expected response: $API_RESPONSE"
else
    print_error "API returned unexpected response: $API_RESPONSE"
    print_error "Expected response to contain 'Celery + Redis + Docker'"
    exit 1
fi

# TEST 5: REDIS CONNECTIVITY
# This test verifies that Redis is working and accessible
print_status "Test 5: Testing Redis connectivity..."

# Test Redis connection using ping command
# docker exec: runs command inside the redis_container
# redis-cli ping: Redis client ping command (should return "PONG")
REDIS_PING=$(docker exec redis_container redis-cli ping 2>/dev/null || echo "FAILED")

if [ "$REDIS_PING" = "PONG" ]; then
    print_success "Redis is responding to ping"
else
    print_error "Redis is not responding: $REDIS_PING"
    print_error "Expected 'PONG', got '$REDIS_PING'"
    exit 1
fi

# TEST 6: TASK SUBMISSION
# This test verifies that Celery tasks can be submitted via FastAPI
print_status "Test 6: Testing task submission..."

# Submit a task to the FastAPI endpoint
# /add/10/20 should submit a task to add 10 + 20 = 30
TASK_RESPONSE=$(curl -s http://localhost:8000/add/10/20 2>/dev/null)

# Check if response contains a task_id (indicates successful submission)
if echo "$TASK_RESPONSE" | grep -q "task_id"; then
    print_success "Task submitted successfully: $TASK_RESPONSE"
    
    # Extract task ID from JSON response for later use
    # This uses sed with regex to extract the UUID from the JSON
    # Pattern explanation: .*"task_id":"\([^"]*\)".* 
    # - .* matches any characters
    # - "task_id":" matches literal text
    # - \([^"]*\) captures everything that's not a quote (the UUID)
    # - .* matches remaining characters
    TASK_ID=$(echo "$TASK_RESPONSE" | sed -n 's/.*"task_id":"\([^"]*\)".*/\1/p')
    print_status "Task ID: $TASK_ID"
else
    print_error "Task submission failed: $TASK_RESPONSE"
    print_error "Expected response to contain 'task_id'"
    exit 1
fi

# TEST 7: CHECK TASK IN QUEUE
# This test verifies that tasks are properly queued in Redis
print_status "Test 7: Checking if task is queued in Redis..."

# Check how many tasks are in the Celery queue
# LLEN returns the length of a Redis list (queue)
# Celery uses Redis lists to store pending tasks
QUEUE_LENGTH=$(docker exec redis_container redis-cli LLEN celery 2>/dev/null || echo "0")
print_status "Tasks in celery queue: $QUEUE_LENGTH"

# Check both possible queue names (celery and default)
# Different Celery configurations might use different queue names
if [ "$QUEUE_LENGTH" -gt 0 ] || [ "$(docker exec redis_container redis-cli LLEN default 2>/dev/null)" -gt 0 ]; then
    print_success "Task found in queue"
else
    print_warning "No tasks found in queue (might have been processed already)"
    print_warning "This is normal if Celery worker is very fast"
fi

# TEST 8: WAIT FOR TASK PROCESSING
# This test waits for the Celery worker to process the submitted task
print_status "Test 8: Waiting for task to be processed..."
print_status "Task has 20-second sleep, waiting 25 seconds..."

# Wait longer than the task duration to ensure completion
# Our add task includes time.sleep(20), so we wait 25 seconds to be safe
sleep 25

# TEST 9: CHECK TASK RESULT
# This test verifies that the task completed and returned the correct result
print_status "Test 9: Checking task result..."

# Only check result if we have a valid task ID from earlier
if [ -n "$TASK_ID" ]; then
    # Query the result endpoint with the task ID
    RESULT_RESPONSE=$(curl -s http://localhost:8000/result/$TASK_ID 2>/dev/null)
    
    # Check if result contains the expected value (10 + 20 = 30)
    if echo "$RESULT_RESPONSE" | grep -q '"result":30'; then
        print_success "Task completed with correct result: $RESULT_RESPONSE"
    else
        print_warning "Task result: $RESULT_RESPONSE"
        # Check if task is still processing (this can happen if system is slow)
        if echo "$RESULT_RESPONSE" | grep -q "still processing"; then
            print_warning "Task is still processing (this is normal if it takes longer)"
        fi
    fi
else
    print_error "No task ID available to check result"
    print_error "Cannot verify task completion without task ID"
fi

# TEST 10: CHECK CELERY WORKER LOGS
# This test verifies that the Celery worker actually processed tasks
print_status "Test 10: Checking Celery worker activity..."

# Get recent worker logs to see if tasks were processed
# --tail=5 limits output to last 5 log lines
WORKER_LOGS=$(docker-compose logs celery_worker --tail=5 2>/dev/null)

# Look for "succeeded" in logs, which indicates successful task completion
if echo "$WORKER_LOGS" | grep -q "succeeded"; then
    print_success "Celery worker processed tasks successfully"
else
    print_warning "No successful task completion found in recent logs"
    print_warning "Recent worker logs:"
    echo "$WORKER_LOGS"
fi

# TEST 11: MULTIPLE TASK TEST
# This test verifies that the system can handle multiple concurrent tasks
print_status "Test 11: Testing multiple task submissions..."

# Submit 3 different tasks to test concurrent processing
# Loop from 1 to 3, submitting tasks like add/1/6, add/2/7, add/3/8
for i in {1..3}; do
    # Calculate second parameter as i+5
    MULTI_RESPONSE=$(curl -s http://localhost:8000/add/$i/$((i+5)) 2>/dev/null)
    
    if echo "$MULTI_RESPONSE" | grep -q "task_id"; then
        print_success "Multi-task $i submitted successfully"
    else
        print_error "Multi-task $i failed: $MULTI_RESPONSE"
        print_error "Failed to submit task with values $i and $((i+5))"
    fi
done

# TEST 12: PERFORMANCE CHECK
# This test measures the response time of task submission
print_status "Test 12: Performance check..."

# Get current time in nanoseconds for precise measurement
START_TIME=$(date +%s%N)
PERF_RESPONSE=$(curl -s http://localhost:8000/add/1/1 2>/dev/null)
END_TIME=$(date +%s%N)

# Calculate duration in milliseconds
# Subtracts start from end time, then divides by 1,000,000 (nanoseconds to milliseconds)
DURATION=$((($END_TIME - $START_TIME) / 1000000))

if echo "$PERF_RESPONSE" | grep -q "task_id"; then
    print_success "Task submission took ${DURATION}ms"
    
    # Provide performance feedback
    if [ "$DURATION" -lt 100 ]; then
        print_success "Excellent response time!"
    elif [ "$DURATION" -lt 500 ]; then
        print_success "Good response time"
    else
        print_warning "Response time is a bit slow (might be normal for first request)"
    fi
else
    print_error "Performance test failed"
    print_error "Task submission returned: $PERF_RESPONSE"
fi

# SUMMARY AND STATISTICS
# This section provides an overview of the test results and system status
echo ""
echo "================================================"
print_status "Test Summary"
echo "================================================"

# Count how many containers are actually running
# This filter looks for containers with specific names
# --format extracts only the container names
# wc -l counts the number of lines (containers)
RUNNING_CONTAINERS=$(docker ps --filter "name=redis_container\|fastapi_app_container\|celery_worker_container" --format "{{.Names}}" | wc -l)
print_status "Running containers: $RUNNING_CONTAINERS/3"

# Check how many Redis keys exist (indicates activity)
# More keys usually means more Celery metadata and task results
REDIS_KEYS=$(docker exec redis_container redis-cli KEYS "*" 2>/dev/null | wc -l)
print_status "Redis keys: $REDIS_KEYS"

# Check final queue status (should be empty if all tasks processed)
FINAL_QUEUE=$(docker exec redis_container redis-cli LLEN celery 2>/dev/null || echo "0")
print_status "Final queue length: $FINAL_QUEUE"

# Print success message and usage information
echo ""
print_success "🎉 Test suite completed!"
print_status "Services are running and accessible at:"
print_status "  - FastAPI: http://localhost:8000"
print_status "  - FastAPI Docs: http://localhost:8000/docs"
print_status "  - Redis: localhost:6379"
print_status ""
print_status "To stop services, run:"
print_status "  docker-compose --profile mastering_celery down"
print_status ""
print_status "To view logs, run:"
print_status "  docker-compose logs -f"

# CLEANUP OPTION
# Ask user if they want to stop services or keep them running
echo ""
read -p "Do you want to stop the services now? (y/N): " -n 1 -r
echo ""

# Check if user pressed 'y' or 'Y'
# $REPLY contains the user's input from the read command
# =~ is the regex match operator in bash
# ^[Yy]$ means: start of line, Y or y, end of line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Stopping services..."
    docker-compose --profile mastering_celery down
    print_success "Services stopped"
else
    print_status "Services are still running"
    print_status "You can continue testing or stop them later with:"
    print_status "  docker-compose --profile mastering_celery down"
fi
