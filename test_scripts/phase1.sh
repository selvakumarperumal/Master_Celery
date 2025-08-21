#!/bin/bash

# FastAPI Add Endpoint Testing Script
# This script tests the FastAPI /add/{x}/{y} endpoint with various numeric inputs
# and then retrieves the results using the /result/{task_id} endpoint

# ===== BASH COMPATIBILITY CHECK =====
# This section ensures the script runs with bash instead of sh or other shells
# 
# Why this check is necessary:
# - This script uses bash-specific features like 'declare -a' for arrays
# - The script uses bash array syntax: array+=("element") and "${array[@]}"
# - Running with /bin/sh would cause "declare: not found" and syntax errors
# 
# How it works:
# - $BASH_VERSION is an environment variable set only when running in bash
# - If BASH_VERSION is empty (-z test), we're not running in bash
# - The script exits with error code 1 and shows proper usage instructions
#
# Common scenarios where this helps:
# - User runs: ./script.sh (uses system default shell, often /bin/sh)
# - User runs: sh script.sh (explicitly uses /bin/sh)
# - System has dash, zsh, or other shell as /bin/sh
#
# Proper usage examples:
# - bash script.sh (explicitly uses bash)
# - ./script.sh (if system properly recognizes #!/bin/bash shebang)
if [ -z "$BASH_VERSION" ]; then  # Test if BASH_VERSION variable is empty
    echo "This script requires bash. Please run with: bash $0"
    exit 1  # Exit with error code 1 to indicate failure
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

# Function to test the add endpoint with two numbers
# Parameters: x (first number), y (second number)
# This function sends a GET request to /add/{x}/{y} and extracts the task ID
test_add_endpoint() {
    local x=$1  # First number parameter
    local y=$2  # Second number parameter
    
    print_info "Testing add endpoint with x=$x, y=$y"
    
    # Make HTTP GET request to the add endpoint
    # -s: silent mode (no progress bar)
    # -w "\n%{http_code}": append HTTP status code to response
    RESPONSE=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/add/$x/$y")  # Send GET request
    
    # Extract HTTP status code from the last line of response
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)  # Get last line (status code)
    
    # Extract response body (everything except the last line)
    BODY=$(echo "$RESPONSE" | head -n -1)  # Get all except last line (response body)
    
    print_info "HTTP Status Code: $HTTP_CODE"
    print_info "Response Body: $BODY"
    
    # Extract task ID from JSON response using grep and cut
    # grep -o: only output the matching part
    # '"task_id":"[^"]*"': matches "task_id":"any_characters_except_quotes"
    # cut -d'"' -f4: split by quotes and get the 4th field (the actual task ID)
    TASK_ID=$(echo "$BODY" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)  # Extract task ID
    
    # Check if task ID was successfully extracted
    if [ -n "$TASK_ID" ]; then  # If TASK_ID is not empty
        # Add task ID to our array
        TASK_IDS+=("$TASK_ID")  # Append to array
        print_success "Task ID extracted and stored: $TASK_ID"
    else
        print_info "Could not extract task ID from response"
    fi
    
    echo ""  # Add blank line for better readability
}

# Function to retrieve results for all stored task IDs
# This function iterates through all collected task IDs and checks their status/results
get_task_results() {
    print_info "Getting results for all stored task IDs..."
    
    # Iterate through each task ID in the array
    for task_id in "${TASK_IDS[@]}"; do  # Loop through array elements
        print_info "Getting result for task: $task_id"
        
        # Make HTTP GET request to the result endpoint
        RESPONSE=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/result/$task_id")
        
        # Extract HTTP status code and response body
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | head -n -1)
        
        print_info "HTTP Status Code: $HTTP_CODE"
        print_info "Response Body: $BODY"
        echo ""  # Add blank line between each result
    done
}

# Test cases with various numeric inputs
# Using pipe-separated values for easy parsing
# Format: "x y|x y|x y..." where each pair represents numbers to add
declare -a test_cases=("5 10" "0 0" "-5 15" "100 200" "1 1" "-10 -20" "999 1")  # Array of test cases

# ===== MAIN EXECUTION STARTS HERE =====

print_info "Starting add endpoint tests with various inputs..."
echo ""

# Process each test case
# Loop through the array of test cases
for test_case in "${test_cases[@]}"; do  # Loop through array elements
    # Extract x and y values from each test case using read command
    read -r x y <<< "$test_case"  # Split test case into x and y variables
    
    # Call the test function with extracted values
    test_add_endpoint "$x" "$y"  # Run the test
done

# Display summary of created tasks
print_info "Total tasks created: ${#TASK_IDS[@]}"  # Get array length
print_info "Task IDs: ${TASK_IDS[*]}"  # Display all array elements
echo ""

# ===== TASK RESULT CHECKING PHASE =====
# Celery tasks are asynchronous, so we need to wait and check results multiple times

# First check: Wait 8 seconds for initial task processing
print_info "Waiting 8 seconds for tasks to process..."
sleep 8

# Check results after initial wait
get_task_results

# Second check: Wait additional 10 seconds for slower tasks
print_info "Waiting 10 seconds for tasks to process..."
sleep 10

# Check results again (some tasks might still be processing)
get_task_results

# Final check: Wait 3 more seconds for any remaining tasks
print_info "Waiting 3 seconds for tasks to process..."
sleep 3

# Final result check - all tasks should be completed by now
get_task_results