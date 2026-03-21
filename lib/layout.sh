#!/usr/bin/env bash
# layout.sh — Build the Claude Pod split layout in the focused Ghostty window
#
# Constructs a 3-column, 7-pane layout using AppleScript keystrokes:
#   Left (4 panes)  |  Middle (1 pane, full height)  |  Right (2 panes)
#
# Usage: bash layout.sh [delay]
#   delay: seconds between keystrokes (default: 0.3)

set -euo pipefail

DELAY="${1:-0.4}"

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

# Helper: type text into the current pane and press Return
type_and_enter() {
    local text="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"Ghostty\"
                keystroke \"$text\"
                delay 0.1
                key code 36
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

echo "Building Claude Pod layout..."

# Starting state: single pane (this will become the middle column)
# The strategy:
#   1. Split right to create [Left+Middle | Right]
#   2. Split left pane right to create [Left | Middle | Right]
#   3. Split Right down to create [Left | Middle | Right_top / Right_bot]
#   4. Split Left down 3 times to create 4 panes in left column
#   5. Equalize all splits

# Step 1: Cmd+D — split right → [A | B]
# A = future left+middle, B = future right column
echo "  Step 1: Split right (create right column)"
send_keystroke "d" "command down"

# Step 2: Focus left pane (Cmd+Alt+Left)
echo "  Step 2: Navigate to left pane"
send_keycode 123 "command down, option down"

# Step 3: Cmd+D — split right within left portion → [C | A | B]
# C = left column, A = middle column, B = right column
echo "  Step 3: Split right (create left column)"
send_keystroke "d" "command down"

# Step 4: Focus right column (navigate right twice to get to B)
echo "  Step 4: Navigate to right column"
send_keycode 124 "command down, option down"
send_keycode 124 "command down, option down"

# Step 5: Cmd+Shift+D — split down in right column → right has top/bottom
echo "  Step 5: Split right column down"
send_keystroke "d" "command down, shift down"

# Step 6: Navigate to left column (C) — go left twice
echo "  Step 6: Navigate to left column"
send_keycode 123 "command down, option down"
send_keycode 123 "command down, option down"

# Step 7: Cmd+Shift+D — split left column down → [C_top | C_bottom]
echo "  Step 7: Split left column down (2 panes)"
send_keystroke "d" "command down, shift down"

# Step 8: Focus C_top (up)
echo "  Step 8: Navigate to top-left pane"
send_keycode 126 "command down, option down"

# Step 9: Cmd+Shift+D — split C_top → [C1 | C2 | C_bottom]
echo "  Step 9: Split top-left down (3 panes)"
send_keystroke "d" "command down, shift down"

# Step 10: Focus C_bottom (navigate down to the bottom pane)
echo "  Step 10: Navigate to bottom-left pane"
send_keycode 125 "command down, option down"
send_keycode 125 "command down, option down"

# Step 11: Cmd+Shift+D — split C_bottom → [C1 | C2 | C3 | C4]
echo "  Step 11: Split bottom-left down (4 panes)"
send_keystroke "d" "command down, shift down"

# Step 12: Cmd+= — equalize all splits (key code 24 = the =/+ key)
echo "  Step 12: Equalize splits"
send_keycode 24 "command down"

echo "Layout complete!"
