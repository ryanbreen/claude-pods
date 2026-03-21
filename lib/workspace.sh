#!/usr/bin/env bash
# workspace.sh — yabai workspace queries and window movement
#
# Functions for discovering Ghostty windows, moving them between
# workspaces, and resolving workspace targets.

set -euo pipefail

# Get all Ghostty windows as JSON array
ghostty_windows() {
    yabai -m query --windows | python3 -c "
import json, sys
data = json.load(sys.stdin)
ghostty = [w for w in data if w.get('app') == 'Ghostty']
print(json.dumps(ghostty))
"
}

# Get Ghostty windows on a specific workspace
# Usage: ghostty_windows_on_space <space_number>
ghostty_windows_on_space() {
    local space="$1"
    yabai -m query --windows --space "$space" | python3 -c "
import json, sys
data = json.load(sys.stdin)
ghostty = [w for w in data if w.get('app') == 'Ghostty']
print(json.dumps(ghostty))
"
}

# Count Ghostty windows on a specific workspace
# Usage: ghostty_window_count_on_space <space_number>
ghostty_window_count_on_space() {
    local space="$1"
    ghostty_windows_on_space "$space" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))"
}

# Get the single Ghostty window ID on a workspace (errors if 0 or >1)
# Usage: resolve_ghostty_window_on_space <space_number>
# Returns: window ID, or exits with error message
resolve_ghostty_window_on_space() {
    local space="$1"
    local result
    result="$(ghostty_windows_on_space "$space" | python3 -c "
import json, sys
windows = json.load(sys.stdin)
if len(windows) == 0:
    print('ERROR:No Ghostty windows on workspace $space')
elif len(windows) == 1:
    print(windows[0]['id'])
else:
    titles = ', '.join([w.get('title', 'untitled') for w in windows])
    print(f'ERROR:Multiple Ghostty windows on workspace $space: {titles}')
")"

    if [[ "$result" == ERROR:* ]]; then
        echo "${result#ERROR:}" >&2
        return 1
    fi
    echo "$result"
}

# Move a window to a specific workspace
# Usage: move_window_to_space <window_id> <space_number>
move_window_to_space() {
    local window_id="$1"
    local space="$2"
    yabai -m window "$window_id" --space "$space"
}

# Focus a specific workspace
# Usage: focus_space <space_number>
focus_space() {
    local space="$1"
    yabai -m space --focus "$space"
}

# Focus a specific window
# Usage: focus_window <window_id>
focus_window() {
    local window_id="$1"
    yabai -m window --focus "$window_id"
}

# Get the most recently created Ghostty window ID
# (useful right after creating a new window)
# Usage: newest_ghostty_window
newest_ghostty_window() {
    yabai -m query --windows | python3 -c "
import json, sys
data = json.load(sys.stdin)
ghostty = [w for w in data if w.get('app') == 'Ghostty']
if ghostty:
    # The window with the highest ID is typically the newest
    newest = max(ghostty, key=lambda w: w['id'])
    print(newest['id'])
else:
    print('')
"
}

# Get the current workspace number
current_space() {
    yabai -m query --spaces | python3 -c "
import json, sys
spaces = json.load(sys.stdin)
for s in spaces:
    if s.get('has-focus'):
        print(s['index'])
        break
"
}
