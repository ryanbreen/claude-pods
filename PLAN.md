# Claude Pods — Design Plan

## What is a Claude Pod?

A Claude Pod is a pre-configured Ghostty window layout for a specific working directory.
It provides a consistent multi-pane development environment with Claude Code instances,
a main workspace pane, lazygit, and a utility shell — all pointed at the same directory.

A Claude Pod is also a **managed entity** — the system tracks which pods are open, where
they live, and what Claude sessions they contain, enabling operations like "reopen all
my Claude Pods" after a Ghostty update.

## Target Layout

```
┌─────────────┬──────────────────────────┬─────────────┐
│             │                          │             │
│  Claude     │                          │             │
│  Code 1     │                          │  lazygit    │
│  (resume)   │                          │             │
├─────────────┤                          │             │
│             │                          │             │
│  Claude     │                          ├─────────────┤
│  Code 2     │      Main Pane           │             │
│  (resume)   │      (full height)       │             │
├─────────────┤                          │             │
│             │      zsh prompt,         │  Utility    │
│  Claude     │      logs, tmux,         │  Shell      │
│  Code 3     │      server — whatever   │  (zsh)      │
│  (resume)   │      you need            │             │
├─────────────┤                          │             │
│             │                          │             │
│  Claude     │                          │             │
│  Code 4     │                          │             │
│  (resume)   │                          │             │
└─────────────┴──────────────────────────┴─────────────┘
```

After layout construction, `Cmd+=` equalizes all splits proportionally.

### Column breakdown

| Column | Rows | Contents                                          |
|--------|------|---------------------------------------------------|
| Left   | 4    | 4x Claude Code instances (resumed from recent)    |
| Middle | 1    | Main pane (full height zsh)                        |
| Right  | 2    | Top: lazygit, Bottom: utility zsh prompt           |

All panes share the same working directory.

## Architecture Discovery

### Ghostty capabilities (confirmed on this system)

- **No IPC/socket**: Ghostty has no programmatic API for sending actions
- **AppleScript works**: Can address Ghostty via `System Events` for keystrokes and menus
- **macOS native tabs**: Window menu includes "Merge All Windows" and tab management
- **Split actions**: `Cmd+D` = split right, `Cmd+Shift+D` = split down
- **Navigation**: `Cmd+Alt+Arrow` = goto split, `Cmd+Ctrl+Arrow` = resize split
- **Equalize**: `Cmd+=` equalizes all splits proportionally
- **New window**: `open -na Ghostty.app --args --working-directory=<path>`
- **Run command**: `-e <command>` runs a specific command in the terminal
- **New tab in window**: `Cmd+T` creates a new tab in the focused window

### yabai capabilities (confirmed, v7.1.17)

- **9 spaces**: All 9 workspaces active
- **Window query**: `yabai -m query --windows` returns window ID, app, title, space
- **Move to space**: `yabai -m window <WINDOW_ID> --space <N>`
- **Focus space**: `yabai -m space --focus <N>`
- **Query by space**: `yabai -m query --windows --space <N>` filters by workspace

### Claude Code session management (confirmed)

- **Active sessions**: `~/.claude/sessions/*.json` contains `{pid, sessionId, cwd, startedAt}`
- **Session transcripts**: `~/.claude/projects/<encoded-path>/<uuid>.jsonl` sorted by mtime
- **Resume by ID**: `claude --resume <sessionId>` resumes a specific conversation
- **Continue most recent**: `claude --continue` resumes the most recent in the cwd
- **Session IDs are UUIDs**: Can be extracted from the `.jsonl` filenames in project dirs
- **4 most recent sessions per directory** can be found by sorting `.jsonl` files by mtime

### Available tools

- `ghostty` CLI, `yabai`, `skhd`, `osascript`, `lazygit`, `claude`, `swift`

## Implementation Strategy

### Pod construction sequence

Ghostty splits are binary (each split divides the current pane). Construction order:

```
Step 1: Start with one pane [A]
Step 2: Cmd+D (split right)          → [A | B]
Step 3: Focus A (Cmd+Alt+Left)
Step 4: Cmd+D (split right)          → [C | A | B]   (C = left col, A = middle)
Step 5: Focus B (Cmd+Alt+Right x2 or Cmd+])
Step 6: Cmd+Shift+D (split down)     → right col now has [B_top | B_bot]
Step 7: Focus C (Cmd+Alt+Left x2)
Step 8: Cmd+Shift+D (split down)     → left col: [C_top | C_bot]
Step 9: Focus C_top, Cmd+Shift+D     → left col: [C1 | C2 | C_bot]
Step 10: Focus C_bot, Cmd+Shift+D    → left col: [C1 | C2 | C3 | C4]
Step 11: Cmd+= (equalize splits)
```

Final pane map:
- C1, C2, C3, C4 = Claude Code instances (left column)
- A = Main pane (middle column)
- B_top = lazygit (top right)
- B_bot = utility shell (bottom right)

### Launching programs in panes

After layout construction, navigate to each pane and type commands:
- C1-C4: `claude --resume <sessionId>` (4 most recent sessions for this directory)
- B_top: `lazygit`
- A, B_bot: left as zsh prompts

If there are fewer than 4 recent sessions, the remaining panes get `claude` (fresh).

### Two modes of operation

#### Mode 1: Standalone window

1. Open new Ghostty window: `open -na Ghostty.app --args --working-directory=<path>`
2. Wait for window, get its yabai window ID
3. Build split layout via AppleScript keystrokes
4. Launch programs
5. Move to target workspace: `yabai -m window <id> --space <N>`

#### Mode 2: New tab in existing Ghostty window

1. Query yabai for Ghostty windows on target workspace
2. **Validation**:
   - If 0 Ghostty windows on that workspace → error or fall back to standalone mode
   - If 1 Ghostty window → use it
   - If >1 Ghostty windows → error: "Multiple Ghostty windows on workspace N, specify which one"
3. Focus the target Ghostty window via yabai
4. `Cmd+T` to create a new tab (optionally at a specific position)
5. Type `cd <path>` to set working directory
6. Build split layout
7. Launch programs

Optional: tab position (e.g., "as the 3rd tab") — after creating the tab, use
`Cmd+Shift+[` or `Cmd+Shift+]` to reorder, or drag via AppleScript.

### Hands-off countdown

Before AppleScript takes over the keyboard, display a **3-second floating countdown**
overlay so the user knows to release the keyboard. Implementation options:

- **Swift overlay**: Compile a small SwiftUI app that shows a transparent, borderless
  window with large centered countdown numbers (3... 2... 1...) then exits
- Ships as a pre-compiled binary in the repo

### State management / bookkeeping

All pod state lives in `~/.claude-pods/state.json`:

```json
{
  "pods": [
    {
      "id": "uuid",
      "directory": "/Users/wrb/fun/code/breenix",
      "workspace": 7,
      "mode": "standalone",
      "ghosttyWindowId": 1873,
      "createdAt": "2026-03-21T12:00:00Z",
      "claudeSessions": [
        "8279fa0c-77e3-45a9-8051-94cf0b5d24ce",
        "e281a493-8a27-4770-b5bb-a2f0dcb87ec7",
        "99feba0f-7993-46bb-952a-087a525b2360",
        "bdd64bb2-a5fd-4691-a0a3-fac24572e6f6"
      ]
    }
  ]
}
```

The state file supports these operations:
- **`pod open`** — create a new pod, register it
- **`pod close`** — close a pod's Ghostty window/tab, deregister it
- **`pod list`** — show all active pods with their directories and workspaces
- **`pod reopen`** — reopen a specific closed pod (re-reads last known sessions)
- **`pod reopen-all`** — reopen all pods from the last known state
- **`pod status`** — check which pods are alive (verify PIDs/window IDs still exist)

On every `pod open`, the state is saved. On `pod close`, the pod is marked as closed
but retained in history so `reopen` can restore it. Periodic `pod status` checks prune
pods whose Ghostty windows no longer exist.

## File Structure

```
claude-pods/
├── README.md
├── PLAN.md
├── claude-pod.sh              # Main entry point script
├── lib/
│   ├── layout.sh              # AppleScript generation for split construction
│   ├── sessions.sh            # Claude session discovery and resume logic
│   ├── workspace.sh           # yabai workspace queries and window movement
│   ├── state.sh               # Pod state management (read/write state.json)
│   └── countdown.sh           # Launch the countdown overlay
├── countdown/
│   ├── Countdown.swift        # SwiftUI floating overlay source
│   └── build.sh               # Compile the Swift binary
├── skill/
│   └── SKILL.md               # Claude Code skill definition
└── install.sh                 # Installation script
```

## Skill Interface

The skill will support natural language like:

- "Open a Claude Pod in ~/code/breenix on workspace 7"
- "Add a Claude Pod tab for ~/code/penpot on workspace 3"
- "Close the Claude Pod on workspace 7"
- "Reopen all my Claude Pods"
- "List my Claude Pods"
- "What pods are running?"

The skill translates these into `claude-pod.sh` invocations:

```bash
claude-pod.sh open --dir ~/code/breenix --workspace 7
claude-pod.sh open --dir ~/code/penpot --workspace 3 --tab
claude-pod.sh close --workspace 7
claude-pod.sh reopen-all
claude-pod.sh list
claude-pod.sh status
```

## Phases

### Phase 1: Prototype the split layout
- Get the AppleScript keystroke sequence working reliably
- Determine timing delays needed between actions
- Verify the pane navigation order is deterministic

### Phase 2: Core script with state management
- Implement `claude-pod.sh` with open/close/list/reopen
- Implement Claude session discovery and resume
- Implement yabai workspace integration
- Build the countdown overlay

### Phase 3: Tab mode
- Implement the "add as tab to Ghostty window on workspace N" flow
- Implement Ghostty window discovery via yabai queries
- Handle ambiguity (multiple windows on same workspace)

### Phase 4: Skill + polish
- Write the Claude Code skill definition
- Installation script
- README and documentation
- Create the GitHub repository

## Open Questions for Prototyping

1. **Split tree order**: Need to verify the exact pane navigation after each split
2. **Timing**: What delay between keystrokes is reliable? Start with 0.3s, tune down
3. **Tab creation**: Does Cmd+T create a fresh pane? Does `cd <path>` in it work for
   subsequent splits?
4. **Window ID discovery**: After `open -na Ghostty.app`, how quickly does yabai see
   the new window? Polling strategy needed
5. **Tab positioning**: Can we reliably move a tab to a specific position?
6. **Session freshness**: If a session was last active 2 weeks ago, should we still
   resume it, or start fresh? Need a staleness threshold
