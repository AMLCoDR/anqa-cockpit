#!/bin/bash

# Live Ping Monitor for Cockpit Chat
# Checks for new messages every 3 seconds and displays them

LAST_MESSAGE_ID=0
CHAT_API="http://localhost:5002/api/chat/recent"

echo "🔄 Starting Live Ping Monitor..."
echo "💬 Monitoring cockpit chat messages..."
echo "Press Ctrl+C to stop"
echo "=================================="

while true; do
    # Get recent messages
    RESPONSE=$(curl -s "$CHAT_API" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
        # Parse messages using jq if available, otherwise basic grep
        if command -v jq >/dev/null 2>&1; then
            # Extract new user messages
            NEW_MESSAGES=$(echo "$RESPONSE" | jq -r --argjson last_id "$LAST_MESSAGE_ID" '
                .[] | select(.id > $last_id and .sender == "user") | 
                "\(.timestamp | strftime("%H:%M:%S")) - \(.sender): \(.content)"
            ')
            
            # Update last message ID
            LATEST_ID=$(echo "$RESPONSE" | jq -r 'max_by(.id).id // 0')
            if [ "$LATEST_ID" -gt "$LAST_MESSAGE_ID" ]; then
                LAST_MESSAGE_ID=$LATEST_ID
            fi
        else
            # Fallback without jq
            NEW_MESSAGES=$(echo "$RESPONSE" | grep -o '"sender":"user"' | wc -l)
        fi
        
        # Display new messages
        if [ -n "$NEW_MESSAGES" ] && [ "$NEW_MESSAGES" != "" ]; then
            echo "🔔 NEW MESSAGE:"
            echo "$NEW_MESSAGES"
            echo "=================================="
        fi
    fi
    
    sleep 3
done

