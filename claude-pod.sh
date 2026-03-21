#!/usr/bin/env bash
# claude-pod.sh — Main entry point for Claude Pod management
#
# Commands:
#   open    --dir <path> [--workspace <N>] [--tab] [--tab-position <N>]
#   close   --workspace <N> | --dir <path> | --id <pod_id>
#   list    [--active|--inactive|--all]
#   status  (prune dead pods and show current state)
#   reopen  --id <pod_id> | --dir <path>
#   reopen-all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib/sessions.sh"
source "$SCRIPT_DIR/lib/workspace.sh"
source "$SCRIPT_DIR/lib/state.sh"

COUNTDOWN_BIN="$SCRIPT_DIR/countdown/countdown"
LAYOUT_SCRIPT="$SCRIPT_DIR/lib/layout.sh"

# ─── Helpers ──────────────────────────────────────────────────────────────────

usage() {
    cat <<'EOF'
Usage: claude-pod.sh <command> [options]

Commands:
  open         Create a new Claude Pod
    --dir <path>           Working directory (required)
    --workspace <N>        Target workspace number (1-9)
    --tab                  Add as tab to existing Ghostty window on target workspace
    --tab-position <N>     Position for the new tab (e.g., 3 for third tab)
    --delay <seconds>      Keystroke delay (default: 0.4)

  close        Close a Claude Pod
    --workspace <N>        Close pod on this workspace
    --dir <path>           Close pod for this directory
    --id <pod_id>          Close pod by ID

  list         List Claude Pods
    --active               Show only active pods (default)
    --inactive             Show only inactive pods
    --all                  Show all pods

  status       Check pod health, prune dead pods

  reopen       Reopen a previously closed pod
    --id <pod_id>          Reopen by pod ID
    --dir <path>           Reopen by directory

  reopen-all   Reopen all previously active pods
EOF
}

# Set the current tab's title via Cmd+I
# Usage: set_tab_title "My Title"
set_tab_title() {
    local title="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"Ghostty\"
                keystroke \"i\" using {command down}
                delay 1.0
                keystroke \"$title\"
                delay 0.3
                key code 36
            end tell
        end tell
    "
    sleep 0.3
}

# Type text into the focused Ghostty pane and press Return
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
    sleep 0.3
}

# Navigate to a specific pane using arrow key codes
# Usage: goto_pane <direction> [times]
# direction: up|down|left|right
goto_pane() {
    local direction="$1"
    local times="${2:-1}"
    local keycode
    case "$direction" in
        left)  keycode=123 ;;
        right) keycode=124 ;;
        down)  keycode=125 ;;
        up)    keycode=126 ;;
    esac
    for ((i=0; i<times; i++)); do
        osascript -e "
            tell application \"System Events\"
                tell process \"Ghostty\"
                    key code $keycode using {command down, option down}
                end tell
            end tell
        "
        sleep 0.2
    done
}

# Launch programs in all panes after layout is built
# Assumes cursor is in the bottom-left pane after layout construction
launch_programs() {
    local dir="$1"
    shift
    local sessions=("$@")

    echo "Launching programs in panes..."

    # After layout.sh, focus ends up in the last split pane (bottom of left column)
    # Pane map after construction + equalize:
    #   Left col (top to bottom): C1, C2, C3, C4
    #   Middle: M
    #   Right col: R_top, R_bottom
    #
    # Current position: C4 (bottom-left, where the last split happened)

    # C4 — launch claude (4th session or fresh)
    local cmd
    cmd="$(claude_command "${sessions[3]:-}")"
    echo "  C4 (bottom-left): $cmd"
    type_and_enter "$cmd"

    # Navigate to C3 (up one)
    goto_pane up
    cmd="$(claude_command "${sessions[2]:-}")"
    echo "  C3: $cmd"
    type_and_enter "$cmd"

    # Navigate to C2 (up one)
    goto_pane up
    cmd="$(claude_command "${sessions[1]:-}")"
    echo "  C2: $cmd"
    type_and_enter "$cmd"

    # Navigate to C1 (up one)
    goto_pane up
    cmd="$(claude_command "${sessions[0]:-}")"
    echo "  C1 (top-left): $cmd"
    type_and_enter "$cmd"

    # Navigate to R_top (right twice, should land in top-right area)
    goto_pane right 2
    # Make sure we're at the top
    goto_pane up
    echo "  R_top: lazygit"
    type_and_enter "lazygit"

    # Navigate to R_bottom (down one)
    goto_pane down
    echo "  R_bottom: (zsh prompt)"
    # Leave as-is

    # Navigate to Middle (left one from right column)
    goto_pane left
    echo "  Middle: (zsh prompt)"
    # Leave as-is — this is the main workspace pane

    echo "All programs launched."
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_open() {
    local dir="" workspace="" tab=false tab_position="" delay="0.4"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir) dir="$2"; shift 2 ;;
            --workspace) workspace="$2"; shift 2 ;;
            --tab) tab=true; shift ;;
            --tab-position) tab_position="$2"; shift 2 ;;
            --delay) delay="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$dir" ]]; then
        echo "Error: --dir is required" >&2
        return 1
    fi

    # Resolve to absolute path
    dir="$(cd "$dir" 2>/dev/null && pwd)"

    # Find recent Claude sessions for this directory
    local sessions=()
    while IFS= read -r sid; do
        [[ -n "$sid" ]] && sessions+=("$sid")
    done < <(find_recent_sessions "$dir" 4)

    echo "=== Opening Claude Pod ==="
    echo "Directory: $dir"
    echo "Workspace: ${workspace:-current}"
    echo "Mode: $(if $tab; then echo "tab"; else echo "standalone window"; fi)"
    echo "Sessions found: ${#sessions[@]}"
    echo ""

    # Step 1: Countdown
    echo "Starting countdown — hands off the keyboard!"
    "$COUNTDOWN_BIN" 3

    if $tab; then
        # ── Tab mode ──
        if [[ -z "$workspace" ]]; then
            workspace="$(current_space)"
        fi

        # Find the Ghostty window on the target workspace
        local target_window
        target_window="$(resolve_ghostty_window_on_space "$workspace")" || return 1

        # Focus that workspace and window (skip space focus if already there)
        local cur_space
        cur_space="$(current_space)"
        if [[ "$cur_space" != "$workspace" ]]; then
            focus_space "$workspace"
            sleep 0.3
        fi
        focus_window "$target_window"
        sleep 0.3

        # Create new tab
        osascript -e '
            tell application "System Events"
                tell process "Ghostty"
                    keystroke "t" using {command down}
                end tell
            end tell
        '
        sleep 0.8

        # cd to target directory
        type_and_enter "cd $dir"
        sleep 0.3

    else
        # ── Standalone window mode ──

        # Create fresh window in existing Ghostty
        osascript -e '
            tell application "Ghostty" to activate
            delay 0.5
            tell application "System Events"
                tell process "Ghostty"
                    keystroke "n" using {command down}
                end tell
            end tell
        '
        sleep 1.0

        # cd to target directory
        type_and_enter "cd $dir"
        sleep 0.3
    fi

    # Build the split layout
    bash "$LAYOUT_SCRIPT" "$delay"

    # Launch programs in each pane
    launch_programs "$dir" "${sessions[@]}"

    # Set the tab title to the directory basename
    local tab_title
    tab_title="$(basename "$dir")"
    echo "Setting tab title: $tab_title"
    set_tab_title "$tab_title"

    # Get the window ID of our new pod
    local window_id
    if $tab; then
        # Tab-mode pods share the parent window ID
        window_id="$target_window"
    else
        window_id="$(newest_ghostty_window)"
        # Move to target workspace if specified (standalone mode only)
        if [[ -n "$workspace" ]]; then
            echo "Moving to workspace $workspace..."
            move_window_to_space "$window_id" "$workspace"
            sleep 0.5
            # Re-query by workspace: yabai assigns new IDs after moving
            window_id="$(resolve_ghostty_window_on_space "$workspace" 2>/dev/null || echo "$window_id")"
        fi
    fi

    # Register the pod
    local pod_id
    pod_id="$(generate_pod_id)"
    local actual_workspace="${workspace:-$(current_space)}"
    local mode
    mode="$(if $tab; then echo "tab"; else echo "standalone"; fi)"
    register_pod "$pod_id" "$dir" "$actual_workspace" "$mode" "${window_id:-0}" "${sessions[@]}"

    echo ""
    echo "Pod $pod_id created successfully!"
    echo "  Directory: $dir"
    echo "  Workspace: $actual_workspace"
    echo "  Mode: $mode"
    echo "  Sessions: ${sessions[*]:-none}"
}

cmd_close() {
    local workspace="" dir="" pod_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --workspace) workspace="$2"; shift 2 ;;
            --dir) dir="$2"; shift 2 ;;
            --id) pod_id="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    # Find the pod to close
    local pod_json=""
    if [[ -n "$pod_id" ]]; then
        pod_json="$(python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for p in state['pods']:
    if p['id'] == '$pod_id' and p.get('active', True):
        print(json.dumps(p))
        break
")"
    elif [[ -n "$dir" ]]; then
        dir="$(cd "$dir" 2>/dev/null && pwd)"
        pod_json="$(find_pod_by_dir "$dir")"
    elif [[ -n "$workspace" ]]; then
        pod_json="$(find_pod_by_workspace "$workspace" | python3 -c "
import json, sys
pods = json.load(sys.stdin)
if len(pods) == 1:
    print(json.dumps(pods[0]))
elif len(pods) > 1:
    print('AMBIGUOUS')
")"
        if [[ "$pod_json" == "AMBIGUOUS" ]]; then
            echo "Error: Multiple pods on workspace $workspace. Use --id to specify." >&2
            return 1
        fi
    fi

    if [[ -z "$pod_json" ]]; then
        echo "Error: No matching active pod found." >&2
        return 1
    fi

    local target_id
    target_id="$(echo "$pod_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")"

    deactivate_pod "$target_id"
    echo "Pod $target_id closed (marked inactive)."
    echo "Note: The Ghostty window itself is not force-closed — close it manually or it will be pruned on next status check."
}

cmd_list() {
    local filter="active"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --active) filter="active"; shift ;;
            --inactive) filter="inactive"; shift ;;
            --all) filter="all"; shift ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    prune_dead_pods >/dev/null 2>&1 || true

    local pods
    pods="$(list_pods "$filter")"

    python3 -c "
import json
pods = json.loads('''$pods''')
if not pods:
    print('No ${filter} pods.')
else:
    for p in pods:
        status = 'active' if p.get('active', True) else 'inactive'
        print(f\"  [{status}] {p['id']}  ws:{p['workspace']}  {p['directory']}  ({p['mode']})\")
"
}

cmd_status() {
    echo "=== Claude Pod Status ==="
    prune_dead_pods
    echo ""
    echo "Active pods:"
    cmd_list --active
    echo ""
    echo "Inactive pods (available for reopen):"
    cmd_list --inactive
}

cmd_reopen() {
    local pod_id="" dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id) pod_id="$2"; shift 2 ;;
            --dir) dir="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    # Find the inactive pod
    local pod_json=""
    if [[ -n "$pod_id" ]]; then
        pod_json="$(python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for p in state['pods']:
    if p['id'] == '$pod_id' and not p.get('active', True):
        print(json.dumps(p))
        break
")"
    elif [[ -n "$dir" ]]; then
        dir="$(cd "$dir" 2>/dev/null && pwd)"
        pod_json="$(python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for p in reversed(state['pods']):
    if p['directory'] == '$dir' and not p.get('active', True):
        print(json.dumps(p))
        break
")"
    fi

    if [[ -z "$pod_json" ]]; then
        echo "Error: No matching inactive pod found." >&2
        return 1
    fi

    local target_dir target_workspace target_id
    target_dir="$(echo "$pod_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['directory'])")"
    target_workspace="$(echo "$pod_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace'])")"
    target_id="$(echo "$pod_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")"

    # Remove the old pod entry, open will create a new one
    remove_pod "$target_id"

    # Reopen with the same directory and workspace
    cmd_open --dir "$target_dir" --workspace "$target_workspace"
}

cmd_reopen_all() {
    local pods
    pods="$(inactive_pods)"

    local count
    count="$(echo "$pods" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"

    if [[ "$count" == "0" ]]; then
        echo "No inactive pods to reopen."
        return 0
    fi

    echo "Reopening $count pod(s)..."
    echo ""

    # Process each pod sequentially (each one needs keyboard control)
    echo "$pods" | python3 -c "
import json, sys
pods = json.load(sys.stdin)
for p in pods:
    print(f\"{p['id']}|{p['directory']}|{p['workspace']}\")
" | while IFS='|' read -r pod_id pod_dir pod_ws; do
        echo "--- Reopening pod $pod_id ($pod_dir on workspace $pod_ws) ---"
        remove_pod "$pod_id"
        cmd_open --dir "$pod_dir" --workspace "$pod_ws"
        echo ""
    done
}

# ─── Main dispatch ────────────────────────────────────────────────────────────

main() {
    if [[ $# -eq 0 ]]; then
        usage
        return 1
    fi

    local command="$1"
    shift

    case "$command" in
        open)       cmd_open "$@" ;;
        close)      cmd_close "$@" ;;
        list)       cmd_list "$@" ;;
        status)     cmd_status ;;
        reopen)     cmd_reopen "$@" ;;
        reopen-all) cmd_reopen_all ;;
        help|-h|--help) usage ;;
        *)
            echo "Unknown command: $command" >&2
            usage
            return 1
            ;;
    esac
}

main "$@"
