#!/busybox/sh
set -e

API_KEY_FILE="/var/lib/headscale/root_api_key"

# Function to generate API key
generate_api_key() {
    echo "Waiting for headscale to be ready..."
    sleep 10
    
    # Check if API key already exists
    if [ -f "$API_KEY_FILE" ]; then
        echo "API key already exists at $API_KEY_FILE"
        cat "$API_KEY_FILE"
    else
        echo "Generating new root API key..."
        # Generate a 999-day API key - output is just the key itself
        API_KEY=$(headscale apikeys create --expiration 999d 2>&1)
        
        if [ -n "$API_KEY" ] && [ "$API_KEY" != "" ]; then
            echo "$API_KEY" > "$API_KEY_FILE"
            chmod 600 "$API_KEY_FILE"
            echo "API key generated and saved to $API_KEY_FILE"
            echo "Key: $API_KEY"
        else
            echo "Failed to generate API key"
        fi
    fi
}

# Start API key generation in background
generate_api_key &

# Start headscale server
exec headscale serve

