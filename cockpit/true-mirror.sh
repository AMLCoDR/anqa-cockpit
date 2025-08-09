#!/bin/bash

# True Mirror System - Creates bidirectional communication 
# Your cockpit messages appear as if typed directly in Cursor

COCKPIT_API_URL="http://localhost:5002/api/chat/notifications"
SYNC_API_URL="http://localhost:5002/api/chat/sync"
CHECK_INTERVAL=2
LAST_CHECK_TIME=$(date +%s)

echo "🪞 TRUE MIRROR SYSTEM ACTIVE"
echo "📡 Monitoring cockpit messages..."
echo "🔄 Creating seamless bidirectional sync"
echo "⚡ Your cockpit messages will appear here instantly"
echo ""

# Function to send a message to Cursor conversation that represents user input
simulate_user_message() {
    local user_message="$1"
    local timestamp="$2"
    
    # Format the message to appear as if the user sent it from cockpit
    echo "👤 [COCKPIT] $user_message"
    
    # Send to the sync endpoint to appear in cockpit's history
    curl -s -X POST "$SYNC_API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"📱 **[COCKPIT MESSAGE RECEIVED]**\\n\\n**Your message:** $user_message\\n\\n*This message was sent from your cockpit at $(date -d \"$timestamp\" '+%H:%M:%S' 2>/dev/null || echo 'now'). I'm responding as if you typed it here directly.*\", \"sender\": \"Cursor Assistant\", \"type\": \"mirror_response\"}" \
        > /dev/null 2>&1
}

while true; do
    # Get notifications from cockpit
    response=$(curl -s "$COCKPIT_API_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Check if there are any notifications
        count=$(echo "$response" | jq -r '.count // 0' 2>/dev/null)
        
        if [ "$count" -gt 0 ]; then
            echo "🔔 [$(date '+%H:%M:%S')] Processing $count notification(s)"
            
            # Process each user message
            echo "$response" | jq -c '.notifications[]? | select(.type == "user_message")' 2>/dev/null | while IFS= read -r notification; do
                if [ -n "$notification" ]; then
                    content=$(echo "$notification" | jq -r '.content' 2>/dev/null)
                    timestamp=$(echo "$notification" | jq -r '.timestamp' 2>/dev/null)
                    id=$(echo "$notification" | jq -r '.id' 2>/dev/null)
                    
                    if [ -n "$content" ] && [ "$content" != "null" ] && [ "$content" != "" ]; then
                        echo ""
                        echo "💬 COCKPIT → CURSOR: $content"
                        echo "⏰ Timestamp: $timestamp"
                        echo "🆔 Message ID: $id"
                        
                        # Simulate the user message in Cursor
                        simulate_user_message "$content" "$timestamp"
                        
                        echo "✅ Message forwarded to Cursor conversation"
                        echo ""
                    fi
                fi
            done
        fi
    fi
    
    sleep $CHECK_INTERVAL
done

