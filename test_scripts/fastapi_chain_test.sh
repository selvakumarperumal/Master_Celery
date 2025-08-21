#!/bin/bash

# FastAPI Chain Workflow Test - Simple and Clean!
# This script shows how to use FastAPI endpoints to get chain results easily

echo "🔗 FastAPI Chain Workflow - Easy Way!"
echo "====================================="
echo ""
echo "✨ NEW: Use /chain/result/{task_id} endpoint"
echo "   → No more complex bash parsing needed!"
echo "   → FastAPI handles all the complexity!"
echo ""

API_URL="http://localhost:8000"
X=12
Y=8
EXPECTED=$((($X + $Y) * 2))

echo "📊 Test: add($X, $Y) → multiply(result, 2)"
echo "   Expected result: ($X + $Y) * 2 = $EXPECTED"
echo ""

# Step 1: Submit chain workflow
echo "🚀 Step 1: Submit chain workflow"
RESPONSE=$(curl -s "$API_URL/workflow/chain?x=$X&y=$Y")
echo "   Response: $RESPONSE"

TASK_ID=$(echo "$RESPONSE" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
echo "   Task ID: $TASK_ID"
echo ""

# Step 2: Use the new chain result endpoint
echo "🎯 Step 2: Get result using new /chain/result endpoint"
echo "   (This endpoint handles all the complexity for you!)"
echo ""

for i in {1..15}; do
    echo "   Attempt $i/15..."
    
    RESULT=$(curl -s "$API_URL/chain/result/$TASK_ID")
    
    # Check if we have a final result
    if echo "$RESULT" | grep -q '"result":[0-9]'; then
        echo ""
        echo "✅ SUCCESS! Chain completed"
        echo "   Full response: $RESULT"
        
        # Extract result
        ACTUAL=$(echo "$RESULT" | grep -o '"result":[0-9]*' | cut -d: -f2)
        echo "   Final result: $ACTUAL"
        
        if [ "$ACTUAL" = "$EXPECTED" ]; then
            echo "   ✅ VALIDATION: Correct! ($ACTUAL = $EXPECTED)"
        else
            echo "   ❌ VALIDATION: Wrong! Expected $EXPECTED, got $ACTUAL"
        fi
        
        echo ""
        echo "🎉 FastAPI Chain Workflow Summary:"
        echo "  1. Submit: curl '$API_URL/workflow/chain?x=$X&y=$Y'"
        echo "  2. Get result: curl '$API_URL/chain/result/$TASK_ID'"
        echo "  3. No bash parsing needed - FastAPI does it all!"
        exit 0
    elif echo "$RESULT" | grep -q '"status".*executing'; then
        echo "      Chain executing... ($(($i * 3)) seconds)"
    elif echo "$RESULT" | grep -q '"status".*setting'; then
        echo "      Chain setting up... ($(($i * 3)) seconds)"
    else
        echo "      Status: $RESULT"
    fi
    
    sleep 3
done

echo ""
echo "❌ Timeout after 45 seconds"
echo "   Manual check: curl $API_URL/chain/result/$TASK_ID"
