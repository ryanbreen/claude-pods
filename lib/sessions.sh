#!/usr/bin/env bash
# sessions.sh — Claude Code session discovery and resume logic
#
# Functions for finding recent Claude sessions for a given directory
# and generating the appropriate resume commands.

set -euo pipefail

# Convert a directory path to Claude's project directory encoding
# /Users/wrb/fun/code/breenix → -Users-wrb-fun-code-breenix
encode_project_path() {
    local dir="$1"
    echo "$dir" | sed 's|/|-|g'
}

# Find the N most recent Claude session IDs for a directory
# Usage: find_recent_sessions <directory> [count]
# Returns: newline-separated session UUIDs, most recent first
find_recent_sessions() {
    local dir="$1"
    local count="${2:-4}"
    local encoded
    encoded="$(encode_project_path "$dir")"
    local project_dir="$HOME/.claude/projects/$encoded"

    if [[ ! -d "$project_dir" ]]; then
        return 0
    fi

    # List .jsonl files sorted by modification time (newest first)
    # Extract UUIDs from filenames
    ls -t "$project_dir"/*.jsonl 2>/dev/null \
        | head -n "$count" \
        | while read -r f; do
            basename "$f" .jsonl
        done
}

# Generate the claude command to launch in a pane
# If a session ID is provided, resume it; otherwise start fresh
# Usage: claude_command [session_id]
claude_command() {
    local session_id="${1:-}"
    if [[ -n "$session_id" ]]; then
        echo "claude --resume $session_id"
    else
        echo "claude"
    fi
}

# Check if a Claude session PID is still running
# Usage: is_session_alive <pid>
is_session_alive() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

# List currently active Claude sessions for a directory
# Usage: active_sessions_for_dir <directory>
active_sessions_for_dir() {
    local dir="$1"
    for f in "$HOME/.claude/sessions"/*.json; do
        [[ -f "$f" ]] || continue
        local cwd
        cwd="$(python3 -c "import json; print(json.load(open('$f'))['cwd'])" 2>/dev/null || true)"
        if [[ "$cwd" == "$dir" ]]; then
            cat "$f"
        fi
    done
}
