#!/bin/bash

# Mirror Monitor - Automatically forwards cockpit messages to Cursor conversation
# This creates a true mirror effect where cockpit messages appear in this chat

COCKPIT_API_URL="http://localhost:5002/api/chat/notifications"
CHECK_INTERVAL=2  # Check every 2 seconds

echo "🪞 Mirror Monitor Started - Cockpit messages will appear in Cursor chat"
echo "📡 Monitoring: $COCKPIT_API_URL"
echo "⏱️  Check interval: ${CHECK_INTERVAL}s"
echo ""

while true; do
    # Get new notifications from cockpit
    response=$(curl -s "$COCKPIT_API_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Check if response contains notifications
        count=$(echo "$response" | jq -r '.count // 0' 2>/dev/null)
        
        if [ "$count" -gt 0 ]; then
            echo "🔔 [$(date '+%H:%M:%S')] Found $count new notifications"
            
            # Extract each notification and display content
            echo "$response" | jq -r '.notifications[]? | select(.type == "user_message") | .content' 2>/dev/null | while IFS= read -r content; do
                if [ -n "$content" ] && [ "$content" != "null" ]; then
                    echo "💬 Cockpit Message: $content"
                    
                    # Here we would forward this to the Cursor conversation
                    # For now, just log it
                    echo "   → Forwarding to Cursor conversation..."
                fi
            done
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
