#!/bin/sh
set -e

API_KEY_FILE="/var/lib/headscale/root_api_key"
MAX_WAIT=60
ELAPSED=0

echo "Waiting for API key file to be created..."

# Initial wait for API key file
while [ ! -f "$API_KEY_FILE" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo "Still waiting... ($ELAPSED/$MAX_WAIT seconds)"
done

if [ ! -f "$API_KEY_FILE" ]; then
    echo "Timeout waiting for API key"
    exit 1
fi

# Load initial API key and export it
ROOT_API_KEY=$(cat "$API_KEY_FILE")
export ROOT_API_KEY
echo "API key loaded successfully: ${ROOT_API_KEY:0:10}..."

# Function to start headplane
start_headplane() {
    ROOT_API_KEY="$1" docker-entrypoint.sh node /app/build/server/index.js &
    echo $!
}

# Start headplane with the API key
HEADPLANE_PID=$(start_headplane "$ROOT_API_KEY")

echo "Headplane started with PID $HEADPLANE_PID, watching for API key changes..."

# Watch for changes to API key file
LAST_MTIME=$(stat -c %Y "$API_KEY_FILE" 2>/dev/null || echo "0")

while kill -0 $HEADPLANE_PID 2>/dev/null; do
    sleep 5
    
    if [ -f "$API_KEY_FILE" ]; then
        CURRENT_MTIME=$(stat -c %Y "$API_KEY_FILE" 2>/dev/null || echo "0")
        
        if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
            echo "API key file changed, reloading..."
            NEW_KEY=$(cat "$API_KEY_FILE")
            
            if [ "$NEW_KEY" != "$ROOT_API_KEY" ]; then
                ROOT_API_KEY="$NEW_KEY"
                export ROOT_API_KEY
                echo "New API key detected: ${ROOT_API_KEY:0:10}..."
                echo "Restarting Headplane..."
                
                # Kill old process
                kill $HEADPLANE_PID 2>/dev/null || true
                wait $HEADPLANE_PID 2>/dev/null || true
                
                # Start new process with updated API key
                HEADPLANE_PID=$(start_headplane "$ROOT_API_KEY")
                echo "Headplane restarted with PID $HEADPLANE_PID"
            fi
            
            LAST_MTIME=$CURRENT_MTIME
        fi
    fi
done

echo "Headplane process ended"
wait $HEADPLANE_PID
