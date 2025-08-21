#!/bin/bash

# Simple Chain Workflow Test - Understanding Celery Chains
# This script demonstrates how Celery chains work and properly extracts results

echo "🔗 Chain Workflow Test - Understanding Celery Chains!"
echo "=================================================="
echo ""
echo "ℹ️  How Celery Chains Work:"
echo "   1. run_chain() creates a chain of tasks: add(x,y) | multiply(result, 2)"
echo "   2. The chain returns a nested structure with task IDs"
echo "   3. We need to follow the chain to get the final result"
echo ""

# Configuration
API_URL="http://localhost:8000"
X=5
Y=10
EXPECTED_RESULT=$((($X + $Y) * 2))  # (5+10)*2 = 30

echo "📊 Test Parameters:"
echo "   Input: x=$X, y=$Y"
echo "   Expected Chain Result: ($X + $Y) * 2 = $EXPECTED_RESULT"
echo ""

# Step 1: Submit the chain workflow
echo "🚀 Step 1: Submit chain workflow..."
RESPONSE=$(curl -s "$API_URL/workflow/chain?x=$X&y=$Y")
echo "   Response: $RESPONSE"

# Extract task ID from response
TASK_ID=$(echo "$RESPONSE" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
echo "   Chain Task ID: $TASK_ID"
echo ""

# Step 2: Get the chain structure and extract the final task ID
echo "⏳ Step 2: Getting chain structure..."
sleep 5  # Wait a moment for chain to be set up

CHAIN_RESPONSE=$(curl -s "$API_URL/result/$TASK_ID")
echo "   Chain Structure: $CHAIN_RESPONSE"

# Extract the final task ID from the chain structure
# The chain structure is: [["final_task_id", [["intermediate_task_id", null], null]], null]
FINAL_TASK_ID=$(echo "$CHAIN_RESPONSE" | grep -o '"[a-f0-9-]\{36\}"' | head -1 | tr -d '"')
echo "   Final Task ID: $FINAL_TASK_ID"
echo ""

# Step 3: Monitor the final task for completion
echo "⏳ Step 3: Waiting for chain execution..."
echo "   (Chain takes ~40 seconds: 20s for add + 20s for multiply)"

MAX_ATTEMPTS=15
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "   Checking attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    FINAL_RESPONSE=$(curl -s "$API_URL/result/$FINAL_TASK_ID")
    
    # Check if we have a numeric result
    if echo "$FINAL_RESPONSE" | grep -q '"result":[0-9]'; then
        echo ""
        echo "✅ Chain Completed Successfully!"
        echo "   Final Task Response: $FINAL_RESPONSE"
        
        # Extract the actual result number
        ACTUAL_RESULT=$(echo "$FINAL_RESPONSE" | grep -o '"result":[0-9]*' | cut -d: -f2)
        echo "   Final Result: $ACTUAL_RESULT"
        
        # Validate the result
        if [ "$ACTUAL_RESULT" = "$EXPECTED_RESULT" ]; then
            echo "   ✅ PASS: Result matches expected value ($EXPECTED_RESULT)"
        else
            echo "   ❌ FAIL: Expected $EXPECTED_RESULT, got $ACTUAL_RESULT"
        fi
        
        echo ""
        echo "🎯 Chain Workflow Summary:"
        echo "   1. add($X, $Y) = $((X + Y)) (first task in chain)"
        echo "   2. multiply($((X + Y)), 2) = $ACTUAL_RESULT (second task in chain)"
        echo "   3. Chain execution: ~40 seconds total"
        echo "   4. Result retrieved from final task ID: $FINAL_TASK_ID"
        exit 0
    elif echo "$FINAL_RESPONSE" | grep -q "still processing"; then
        echo "      Still processing... ($(( ATTEMPT * 3 )) seconds elapsed)"
    else
        echo "      Response: $FINAL_RESPONSE"
    fi
    
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

# If we get here, the task timed out
echo ""
echo "❌ Timeout: Chain did not complete within 45 seconds"
echo "   Chain task ID: $TASK_ID"
echo "   Final task ID: $FINAL_TASK_ID"
echo "   You can manually check the results with:"
echo "   curl $API_URL/result/$TASK_ID"
echo "   curl $API_URL/result/$FINAL_TASK_ID"
