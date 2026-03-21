#!/usr/bin/env bash
# test-layout.sh — Test the pod layout construction
# Creates a fresh Ghostty window (via Cmd+N in existing instance), builds the split layout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${1:-$(pwd)}"
DELAY="${2:-0.4}"

echo "=== Claude Pod Layout Test ==="
echo "Working directory: $WORKING_DIR"
echo "Keystroke delay: ${DELAY}s"
echo ""

# Step 1: Countdown FIRST — before anything visible happens
echo "Starting countdown — hands off the keyboard!"
"$SCRIPT_DIR/countdown/countdown" 3

# Step 2: Create a new window in the EXISTING Ghostty instance
echo "Creating fresh Ghostty window via Cmd+N..."
osascript -e '
    tell application "Ghostty" to activate
    delay 0.5
    tell application "System Events"
        tell process "Ghostty"
            keystroke "n" using {command down}
        end tell
    end tell
'

# Step 3: Wait for the new window to appear
sleep 1.0

# Step 4: cd to the working directory in the fresh pane
echo "Setting working directory..."
osascript -e "
    tell application \"System Events\"
        tell process \"Ghostty\"
            keystroke \"cd $WORKING_DIR\"
            delay 0.1
            key code 36
        end tell
    end tell
"
sleep 0.5

# Step 5: Build the layout
bash "$SCRIPT_DIR/lib/layout.sh" "$DELAY"

echo ""
echo "Done! Check your new Ghostty window."
