---
name: claude-pods
description: "when managing Claude Pod terminal layouts - opening, closing, listing, or reopening Ghostty development environments with Claude Code instances, lazygit, and utility panes"
version: "1.0.0"
---

# Claude Pods

Managed Ghostty terminal layouts for Claude Code development environments.

**Core principle:** A Claude Pod is a reproducible, stateful development environment. Open it once, close it, reopen it later — your Claude sessions, layout, and workspace assignment are always tracked.

## When to Use

Invoke this skill when the user wants to:
- Open a new Claude Pod (development terminal layout) for a project directory
- Add a Claude Pod as a tab to an existing Ghostty window
- Close, list, or check status of Claude Pods
- Reopen one or all previously closed Claude Pods
- Move a Claude Pod to a specific workspace

## What is a Claude Pod?

A Claude Pod is a Ghostty window (or tab) with this exact layout:

```
+-------------+--------------------------+-------------+
|  Claude     |                          |             |
|  Code 1     |                          |  lazygit    |
|  (newest)   |                          |             |
+-------------+                          |             |
|  Claude     |                          +-------------+
|  Code 2     |      Main Pane           |             |
|             |      (full height)       |             |
+-------------+                          |  Utility    |
|  Claude     |      zsh prompt          |  Shell      |
|  Code 3     |                          |  (zsh)      |
|             |                          |             |
+-------------+                          |             |
|  Claude     |                          |             |
|  Code 4     |                          |             |
|  (oldest)   |                          |             |
+-------------+--------------------------+-------------+
  Left col         Middle col               Right col
  4 Claude         Full-height zsh          lazygit + zsh
```

- **Left column (4 panes):** Claude Code instances, resuming the 4 most recent sessions for that directory. Most recent session at the top.
- **Middle column (full height):** Open zsh prompt for running servers, tailing logs, etc.
- **Right column (2 panes):** lazygit on top, utility zsh prompt on bottom.
- All panes share the same working directory.

## Prerequisites

This skill requires the following tools to be installed:

- **Ghostty** terminal emulator (macOS)
- **yabai** window manager (`brew install koekeishiya/formulae/yabai`)
- **lazygit** (`brew install lazygit`)
- **Claude Code** CLI (`claude`)

The skill's scripts live at `{skill_root}/../` (the repo root).

## IMPORTANT: Hands-Off Protocol

Pod creation uses AppleScript to send keystrokes to Ghostty. A **3-second floating countdown** appears before any keystrokes are sent. The user MUST take their hands off the keyboard during pod creation. Always warn the user:

> "I'm about to open a Claude Pod. A countdown will appear — please take your hands off the keyboard until it completes."

## Operations

### Open a Pod

```bash
bash {skill_root}/../claude-pod.sh open --dir <path> [--workspace <N>] [--tab] [--delay <seconds>]
```

**Standalone window** (default): Creates a new Ghostty window with the pod layout.

```bash
bash {skill_root}/../claude-pod.sh open --dir ~/code/myproject --workspace 7
```

**As a tab**: Adds the pod as a new tab to the Ghostty window on the specified workspace.

```bash
bash {skill_root}/../claude-pod.sh open --dir ~/code/myproject --workspace 3 --tab
```

Tab mode validation:
- If 0 Ghostty windows on the target workspace: errors
- If 1 Ghostty window: uses it
- If >1 Ghostty windows: errors with "Multiple Ghostty windows on workspace N"

If `--workspace` is omitted, the pod is placed on the user's current workspace.

### Close a Pod

```bash
bash {skill_root}/../claude-pod.sh close --workspace <N>
bash {skill_root}/../claude-pod.sh close --dir <path>
bash {skill_root}/../claude-pod.sh close --id <pod_id>
```

Marks the pod as inactive in state. The Ghostty window is not force-closed.

### List Pods

```bash
bash {skill_root}/../claude-pod.sh list [--active|--inactive|--all]
```

Shows tracked pods with their directory, workspace, and mode.

### Check Status

```bash
bash {skill_root}/../claude-pod.sh status
```

Prunes pods whose Ghostty windows no longer exist, then shows active and inactive pods.

### Reopen a Pod

```bash
bash {skill_root}/../claude-pod.sh reopen --dir <path>
bash {skill_root}/../claude-pod.sh reopen --id <pod_id>
```

Reopens a previously closed pod with the same directory and workspace. Discovers the latest Claude sessions for that directory.

### Reopen All Pods

```bash
bash {skill_root}/../claude-pod.sh reopen-all
```

Reopens every inactive pod. Useful after a Ghostty restart or system reboot.

## Natural Language Examples

Users will say things like:

| User says | Command |
|-----------|---------|
| "Open a Claude Pod for ~/code/breenix on workspace 7" | `open --dir ~/code/breenix --workspace 7` |
| "Add a pod tab for ~/code/penpot on workspace 3" | `open --dir ~/code/penpot --workspace 3 --tab` |
| "Open a pod here" | `open --dir <cwd>` |
| "Close the pod on workspace 5" | `close --workspace 5` |
| "What pods are running?" | `list --active` |
| "Reopen all my pods" | `reopen-all` |
| "Reopen the breenix pod" | `reopen --dir ~/code/breenix` |

## State Management

Pod state is persisted at `~/.claude-pods/state.json`. Each pod tracks:
- Unique pod ID
- Working directory
- Workspace number
- Mode (standalone or tab)
- Ghostty window ID
- Claude session IDs (for the 4 left-column panes)
- Active/inactive status

The state file enables pod lifecycle management across Ghostty restarts.

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| "Multiple Ghostty windows on workspace N" | Tab mode with ambiguous target | Ask user which window, or use standalone mode |
| "No Ghostty windows on workspace N" | Tab mode with no target | Fall back to standalone mode on that workspace |
| "Ghostty lost focus" | Something stole focus during layout | Retry — the layout script checks focus before each keystroke |
| "No matching active pod found" | Close/reopen with bad identifier | Run `list --all` to show available pods |

## Tips

- Pod creation takes ~8-10 seconds. The countdown gives you 3 seconds of warning before it starts.
- If a layout comes out wrong (missed split), close the window and reopen the pod — the session IDs are preserved in state.
- The `status` command automatically prunes pods whose windows have been closed manually.
- Session resume uses `claude --resume <id>`. If a session is very old, Claude may need a moment to load it.
