# Test script for important task with high priority
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

# Function to test the important task endpoint
# This function sends a GET request to /important and extracts the task ID
test_important_task() {
    print_info "Testing important task endpoint"
    response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/important")
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

get_task_results() {
    print_info "Getting results for all tasks"
    for task_id in "${TASK_IDS[@]}"; do
        response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/result/$task_id")
        http_code=$(echo "$response" | tail -n1)  # Get last line (HTTP status code)
        body=$(echo "$response" | head -n -1)  # Get all except last line (response body)
        print_info "HTTP Status Code: $http_code"
        print_info "Response Body: $body"
    done
}

# Main script execution
print_info "Starting important task test script"
test_important_task  # Test the important task endpoint
print_info "Waiting for task to complete (may take a few seconds)"
sleep 5  # Wait for the task to complete (adjust as needed)
print_info "Fetching task results"
get_task_results  # Get results for all tasks
print_success "Important task test script completed successfully"

# worker logs
# print_info "Checking worker logs for task execution"
# docker logs celery_worker  # Replace with your worker container name if different
# echo ""  # Add blank line for better readability