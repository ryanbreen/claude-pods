# Claude Pods

Managed Ghostty terminal layouts for Claude Code development environments.

A Claude Pod is a Ghostty window (or tab) with a fixed 7-pane layout:

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
```

- **Left column:** 4 Claude Code instances, resuming your most recent sessions
- **Middle column:** Full-height zsh prompt (for servers, logs, etc.)
- **Right column:** lazygit on top, utility shell on bottom

## Requirements

- macOS
- [Ghostty](https://ghostty.org) terminal emulator
- [yabai](https://github.com/koekeishiya/yabai) window manager
- [lazygit](https://github.com/jesseduffield/lazygit)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Installation

### As a Claude Code skill (recommended)

Add this repo as a plugin directory in your Claude Code settings:

```json
{
  "plugins": [
    {
      "type": "local",
      "path": "/path/to/claude-pods"
    }
  ]
}
```

Then use natural language: "Open a Claude Pod for ~/code/myproject on workspace 7"

### Standalone CLI

```bash
git clone https://github.com/ryanbreen/claude-pods.git
cd claude-pods

# Build the countdown overlay (one-time)
cd countdown && swiftc -framework Cocoa Countdown.swift -o countdown && cd ..

# Open a pod
./claude-pod.sh open --dir ~/code/myproject --workspace 7

# Add a pod as a tab
./claude-pod.sh open --dir ~/code/myproject --workspace 3 --tab

# List pods
./claude-pod.sh list

# Reopen all pods after a restart
./claude-pod.sh reopen-all
```

## How It Works

Pod creation uses AppleScript to send keystrokes to Ghostty, building the split layout programmatically. A floating countdown overlay warns you to take your hands off the keyboard before it starts.

Pod state is tracked in `~/.claude-pods/state.json`, enabling lifecycle operations like close, reopen, and reopen-all across Ghostty restarts.

Claude sessions are discovered from `~/.claude/projects/` and resumed using `claude --resume <session-id>`, so your conversations persist across pod restarts.

## Commands

| Command | Description |
|---------|-------------|
| `open --dir <path> [--workspace N] [--tab]` | Create a new pod |
| `close --workspace N \| --dir <path> \| --id <id>` | Close a pod |
| `list [--active\|--inactive\|--all]` | List tracked pods |
| `status` | Health check and prune dead pods |
| `reopen --dir <path> \| --id <id>` | Reopen a closed pod |
| `reopen-all` | Reopen all closed pods |
