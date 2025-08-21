#!/bin/bash

# Simple Chain Workflow Test - Final Version
# This script properly demonstrates and tests Celery chains

echo "🔗 Chain Workflow Test - Final Version"
echo "======================================"
echo ""
echo "📖 Understanding Celery Chains:"
echo "   • Chain: add(x,y) → multiply(result, 2)"
echo "   • Chain returns nested structure: [[final_task_id, [intermediate_tasks]], null]"
echo "   • We extract the final_task_id to get the result"
echo ""

# Configuration
API_URL="http://localhost:8000"
X=8
Y=12
EXPECTED_RESULT=$((($X + $Y) * 2))  # (8+12)*2 = 40

echo "📊 Test: x=$X, y=$Y → Expected: ($X + $Y) * 2 = $EXPECTED_RESULT"
echo ""

# Step 1: Submit chain
echo "🚀 Step 1: Submit chain workflow..."
RESPONSE=$(curl -s "$API_URL/workflow/chain?x=$X&y=$Y")
CHAIN_TASK_ID=$(echo "$RESPONSE" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
echo "   Chain submitted: $CHAIN_TASK_ID"

# Step 2: Get chain structure and extract final task ID
echo ""
echo "⚙️  Step 2: Extract final task ID from chain..."
sleep 3  # Wait for chain setup

CHAIN_RESULT=$(curl -s "$API_URL/result/$CHAIN_TASK_ID")
echo "   Chain structure: $CHAIN_RESULT"

# Extract the final task ID (first UUID in the nested structure)
FINAL_TASK_ID=$(echo "$CHAIN_RESULT" | grep -o '[a-f0-9-]\{36\}' | head -2 | tail -1)
echo "   Final task ID: $FINAL_TASK_ID"

# Step 3: Wait for final result
echo ""
echo "⏳ Step 3: Wait for chain completion (~40 seconds)..."

for i in {1..15}; do
    echo "   Attempt $i/15..."
    
    FINAL_RESULT=$(curl -s "$API_URL/result/$FINAL_TASK_ID")
    
    if echo "$FINAL_RESULT" | grep -q '"result":[0-9]'; then
        ACTUAL_RESULT=$(echo "$FINAL_RESULT" | grep -o '"result":[0-9]*' | cut -d: -f2)
        echo ""
        echo "✅ SUCCESS! Chain completed"
        echo "   Final result: $ACTUAL_RESULT"
        
        if [ "$ACTUAL_RESULT" = "$EXPECTED_RESULT" ]; then
            echo "   ✅ VALIDATION PASSED: $ACTUAL_RESULT = $EXPECTED_RESULT"
        else
            echo "   ❌ VALIDATION FAILED: Expected $EXPECTED_RESULT, got $ACTUAL_RESULT"
        fi
        
        echo ""
        echo "🎯 Chain Execution Summary:"
        echo "   1. add($X, $Y) = $((X + Y)) (20 seconds)"
        echo "   2. multiply($((X + Y)), 2) = $ACTUAL_RESULT (20 seconds)"
        echo "   3. Total time: ~40 seconds"
        echo "   4. Final task: $FINAL_TASK_ID"
        break
    else
        echo "      Still processing... ($(($i * 3)) seconds)"
        sleep 3
    fi
    
    if [ $i -eq 15 ]; then
        echo ""
        echo "❌ TIMEOUT after 45 seconds"
        echo "   Chain task: $CHAIN_TASK_ID"
        echo "   Final task: $FINAL_TASK_ID"
        echo "   Manual check: curl $API_URL/result/$FINAL_TASK_ID"
    fi
done
