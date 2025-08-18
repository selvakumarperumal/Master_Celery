# Testing long-running tasks in FastAPI with Celery
#!/bin/bash

# Bash compatibility check
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash. Please run with: bash $0"
    exit 1
fi

# Configuration
API_BASE_URL="http://localhost:8000"  # Base URL for the FastAPI application
declare -a TASK_IDS                   # Array to store task IDs

# ANSI Color codes for formatted terminal output
GREEN='\033[0;32m'  # Green color for success messages
BLUE='\033[0;34m'   # Blue color for info messages
NC='\033[0m'        # No Color - resets terminal color to default

# Function to print informational messages in blue
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
# Function to print success messages in green
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to test the long-running task endpoint
# This function sends a GET request to /long-running and extracts the task ID
test_long_running_task() {
    print_info "Testing long-running task endpoint"
    response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/long-running")
    http_code=$(echo "$response" | tail -n1)  # Get last line (HTTP status code)
    body=$(echo "$response" | head -n -1)  # Get all except last line (response body)
    print_info "HTTP Status Code: $http_code"
    print_info "Response Body: $body"
    # Extract task ID from JSON response using grep and cut
    task_id=$(echo "$body" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)  # Extract task ID
    if [ -n "$task_id" ]; then  # If task ID is not empty
        TASK_IDS+=("$task_id")  # Append to array
        print_success "Task ID extracted and stored: $task_id"
    else
        print_info "Could not extract task ID from response"
    fi
}

# Function to get results for all tasks
get_task_results() {
    print_info "Getting results for all tasks"
    for task_id in "${TASK_IDS[@]}"; do
        response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/result/$task_id")
        http_code=$(echo "$response" | tail -n1)  # Get last line (HTTP status code)
        body=$(echo "$response" | head -n -1)  # Get all except last line (response body)
        print_info "HTTP Status Code: $http_code"
        print_info "Response Body: $body"
        # Check if the task is still running or has completed
        if [[ "$http_code" -eq 200 ]]; then
            print_success "Task $task_id completed successfully."
        elif [[ "$http_code" -eq 202 ]]; then
            print_info "Task $task_id is still running."
        else
            print_info "Task $task_id failed or returned an unexpected status code: $http_code"
        fi
    done
}

# Main script execution
print_info "Starting long-running task test script"
test_long_running_task  # Test the long-running task endpoint
print_info "Waiting for task to complete (may take a few seconds)"
sleep 10  # Wait for the task to complete (adjust as needed)
print_info "Fetching task results"
get_task_results  # Get results for all tasks
sleep 30
print_info "Fetching task results"
get_task_results  # Get results for all tasks
print_success "Long-running task test script completed successfully"
exit 0  # Exit script successfully
