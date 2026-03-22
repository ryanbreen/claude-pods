#!/usr/bin/env bash
# state.sh — Pod state management (read/write state.json)
#
# Manages the persistent state file at ~/.claude-pods/state.json
# The state file is a declaration of what pods should exist.
# Only `pod open` and `pod close` change active status.

set -euo pipefail

STATE_DIR="$HOME/.claude-pods"
STATE_FILE="$STATE_DIR/state.json"

# Ensure state directory and file exist
init_state() {
    mkdir -p "$STATE_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"pods":[]}' > "$STATE_FILE"
    fi
}

# Read the full state
read_state() {
    init_state
    cat "$STATE_FILE"
}

# Write the full state
write_state() {
    local json="$1"
    init_state
    echo "$json" > "$STATE_FILE"
}

# Register a new pod
# Usage: register_pod <id> <directory> <workspace> <mode> <main_cmd> <session1> <session2> ...
register_pod() {
    local pod_id="$1"
    local directory="$2"
    local workspace="$3"
    local mode="$4"
    local main_cmd="$5"
    shift 5
    local sessions=("$@")

    init_state
    local sessions_json
    sessions_json="$(printf '%s\n' "${sessions[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")"

    POD_MAIN_CMD="$main_cmd" python3 -c "
import json, datetime, os
with open('$STATE_FILE') as f:
    state = json.load(f)
main_cmd = os.environ.get('POD_MAIN_CMD', '')
pod = {
    'id': '$pod_id',
    'directory': '$directory',
    'workspace': $workspace,
    'mode': '$mode',
    'mainCmd': main_cmd if main_cmd else None,
    'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'claudeSessions': $sessions_json,
    'active': True
}
state['pods'].append(pod)
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Mark a pod as inactive (closed)
# Usage: deactivate_pod <pod_id>
deactivate_pod() {
    local pod_id="$1"
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for pod in state['pods']:
    if pod['id'] == '$pod_id':
        pod['active'] = False
        break
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# Remove a pod entirely
# Usage: remove_pod <pod_id>
remove_pod() {
    local pod_id="$1"
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
state['pods'] = [p for p in state['pods'] if p['id'] != '$pod_id']
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
}

# List all pods (active, inactive, or all)
# Usage: list_pods [active|inactive|all]
list_pods() {
    local filter="${1:-all}"
    init_state
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
pods = state['pods']
if '$filter' == 'active':
    pods = [p for p in pods if p.get('active', True)]
elif '$filter' == 'inactive':
    pods = [p for p in pods if not p.get('active', True)]
print(json.dumps(pods, indent=2))
"
}

# Find a pod by directory
# Usage: find_pod_by_dir <directory>
find_pod_by_dir() {
    local directory="$1"
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for pod in state['pods']:
    if pod['directory'] == '$directory' and pod.get('active', True):
        print(json.dumps(pod, indent=2))
        break
"
}

# Find a pod by workspace
# Usage: find_pod_by_workspace <workspace_number>
find_pod_by_workspace() {
    local workspace="$1"
    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
matches = [p for p in state['pods'] if p['workspace'] == $workspace and p.get('active', True)]
print(json.dumps(matches, indent=2))
"
}

# Get all inactive pods (for reopen-all)
inactive_pods() {
    list_pods inactive
}

# Generate a short pod ID
generate_pod_id() {
    python3 -c "import uuid; print(str(uuid.uuid4())[:8])"
}
