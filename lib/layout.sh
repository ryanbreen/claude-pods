#!/usr/bin/env bash
# layout.sh — Build the Claude Pod split layout in the focused Ghostty window
#
# Constructs a 3-column layout using AppleScript keystrokes:
#   Left (N panes)  |  Middle (1 pane, full height)  |  Right (2 panes)
#
# Usage: bash layout.sh [delay] [claude_count]
#   delay: seconds between keystrokes (default: 0.4)
#   claude_count: number of Claude panes in the left column (default: 4)

set -euo pipefail

DELAY="${1:-0.4}"
CLAUDE_COUNT="${2:-4}"

# Ensure Ghostty is focused before every action
ensure_focus() {
    osascript -e '
        tell application "Ghostty" to activate
        delay 0.1
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            if frontApp is not "Ghostty" then
                error "Ghostty lost focus — aborting"
            end if
        end tell
    '
}

# Helper: send a keystroke to Ghostty via AppleScript
send_keystroke() {
    local key="$1"
    local modifiers="${2:-}"

    local modifier_clause=""
    if [[ -n "$modifiers" ]]; then
        modifier_clause="using {$modifiers}"
    fi

    ensure_focus
    osascript -e "
        tell application \"System Events\"
            tell process \"Ghostty\"
                keystroke \"$key\" $modifier_clause
            end tell
        end tell
    "
    sleep "$DELAY"
}

# Helper: send a key code (for arrow keys etc)
send_keycode() {
    local code="$1"
    local modifiers="${2:-}"

    local modifier_clause=""
    if [[ -n "$modifiers" ]]; then
        modifier_clause="using {$modifiers}"
    fi

    ensure_focus
    osascript -e "
        tell application \"System Events\"
            tell process \"Ghostty\"
                key code $code $modifier_clause
            end tell
        end tell
    "
    sleep "$DELAY"
}

# Key codes for reference:
# 123 = Left arrow
# 124 = Right arrow
# 125 = Down arrow
# 126 = Up arrow
# 36  = Return

echo "Building Claude Pod layout ($CLAUDE_COUNT Claude panes)..."

# Step 1: Cmd+D — split right → [A | B]
# A = future left+middle, B = future right column
echo "  Split right (create right column)"
send_keystroke "d" "command down"

# Step 2: Focus left pane (Cmd+Alt+Left)
echo "  Navigate to left pane"
send_keycode 123 "command down, option down"

# Step 3: Cmd+D — split right within left portion → [C | A | B]
# C = left column, A = middle column, B = right column
echo "  Split right (create left column)"
send_keystroke "d" "command down"

# Step 4: Focus right column (navigate right twice to get to B)
echo "  Navigate to right column"
send_keycode 124 "command down, option down"
send_keycode 124 "command down, option down"

# Step 5: Cmd+Shift+D — split down in right column → right has top/bottom
echo "  Split right column down"
send_keystroke "d" "command down, shift down"

# Step 6: Navigate to left column (C) — go left twice
echo "  Navigate to left column"
send_keycode 123 "command down, option down"
send_keycode 123 "command down, option down"

# Step 7: Split left column into N panes
# Each split-down divides the focused pane. Focus moves to the new bottom pane.
# So N-1 splits from the left column pane gives us N panes, with focus on the bottom.
if [[ "$CLAUDE_COUNT" -gt 1 ]]; then
    for ((i=1; i<CLAUDE_COUNT; i++)); do
        echo "  Split left column down ($((i+1)) of $CLAUDE_COUNT panes)"
        send_keystroke "d" "command down, shift down"
    done
fi

# Step 8: Cmd+= — equalize all splits (key code 24 = the =/+ key)
echo "  Equalize splits"
send_keycode 24 "command down"

echo "Layout complete!"
