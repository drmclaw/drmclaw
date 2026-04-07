---
name: agent-shell
description: "Fast, minimal shell wrapper that gives VS Code Copilot agent terminals access to dev tools (node, pnpm, python3, brew, cargo) on macOS without shell-init overhead. Use this skill when setting up a new development machine, configuring VS Code for AI agent workflows, troubleshooting agent terminal PATH issues, or when a Copilot agent terminal can't find node/pnpm/python3. Also use when someone asks about optimizing VS Code terminal startup time or making LLM coding agents more efficient."
---

# Agent Shell

A shell wrapper that launches a fast, clean bash session with all dev tool paths resolved — designed for VS Code Copilot agent terminals and automation profiles on macOS.

## Why this exists

VS Code's Copilot agent spawns terminals to run commands. On macOS, interactive shells with plugin managers and version-manager init scripts (oh-my-zsh, nvm.sh, etc.) add significant startup overhead per terminal and sometimes fail entirely in automation profiles that skip init files. This wrapper resolves tool directories directly into PATH and launches `bash --norc --noprofile` for fast, predictable execution.

## Setup

### 1. Write and install the shell wrapper

Create an executable script at `~/.local/bin/drmclaw-agent-shell`. The script must be written in POSIX `sh` (not bash) with `set -e`, and must do the following **in this order**:

1. **Deduplicate the inherited PATH** — remove duplicate `:` separated entries, preserving order.

2. **Prepend essential macOS directories** (only if they exist and aren't already in PATH):
   - `/opt/homebrew/bin`, `/opt/homebrew/sbin` (Apple Silicon Homebrew)
   - `/usr/local/bin` (Intel Homebrew / system)
   - `~/.local/bin` (user-local scripts)
   - `~/.cargo/bin` (Rust toolchain)

3. **Python fallback** — if `/Library/Frameworks/Python.framework/Versions/` has numbered subdirectories, prepend the `bin/` of the latest version (by version sort). Homebrew python3 is already covered by step 2.

4. **nvm node resolution** — resolve the default node version **without sourcing `nvm.sh`** (it's too slow). Read `~/.nvm/alias/default` to get the alias. If the alias is indirect (e.g. `lts/iron`), follow one level by reading `~/.nvm/alias/<value>`. Strip any leading `v` prefix. Glob-match `~/.nvm/versions/node/v<version>*` and pick the latest. If alias resolution fails, fall back to the latest installed version under `~/.nvm/versions/node/`. Prepend the resolved `bin/` directory and export `NVM_DIR`.

5. **Launch bash** — `exec /bin/bash --norc --noprofile`. Also set `SHELL=/bin/bash`.

**Important constraints:**
- The script runs under `set -e`. Every helper function and conditional must be safe — no `[ test ] && action` patterns (use `if/then/fi` instead). A failed test in `&&` kills the script.
- Use a helper function for "prepend if exists and not already in PATH" — it's called ~7 times and should use `case` for the membership check (POSIX-compatible, no bashisms).
- Clean up all temporary variables and functions before `exec`.

After writing the script:
```sh
mkdir -p ~/.local/bin
chmod +x ~/.local/bin/drmclaw-agent-shell
```

### 2. Configure VS Code

Merge the settings from [`references/drmclaw.vscode-settings.jsonc`](references/drmclaw.vscode-settings.jsonc) into your User or Workspace settings. The critical entry is:

```json
"chat.tools.terminal.terminalProfile.osx": {
  "path": "~/.local/bin/drmclaw-agent-shell"
}
```

## Verification

**You must run both checks before considering the skill complete.** If either fails, diagnose and fix the script until both pass.

### 1. Tool resolution

```sh
echo 'which node pnpm python3 brew && echo AGENT_SHELL_OK' | ~/.local/bin/drmclaw-agent-shell
```

**Pass:** Absolute paths for `node`, `pnpm`, `python3`, and `brew`, followed by `AGENT_SHELL_OK`. If a tool is missing, check it's installed on the system (e.g. `brew install pnpm`) before blaming the script.

### 2. Startup speed

```sh
for i in 1 2 3; do /usr/bin/time -p sh -c 'echo exit | ~/.local/bin/drmclaw-agent-shell >/dev/null 2>&1' 2>&1; done
```

**Pass:** Each run completes in under 200ms (`real 0.xx`). The script adds ~80-100ms over bare `bash --norc --noprofile` (~40ms) for PATH resolution. If startup exceeds 200ms, something in the script is spawning unnecessary subprocesses or hitting a slow filesystem path.

### Debugging failures

1. Check the script is executable: `ls -la ~/.local/bin/drmclaw-agent-shell`
2. Run with debug tracing: `echo 'which node' | sh -x ~/.local/bin/drmclaw-agent-shell`
3. Fix the issue and re-run both checks.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Agent terminal can't find node/pnpm/python3 | Check `~/.local/bin/drmclaw-agent-shell` exists and is executable |
| VS Code ignores the wrapper | Verify settings: `"chat.tools.terminal.terminalProfile.osx": { "path": "~/.local/bin/drmclaw-agent-shell" }` |
| nvm node not found | Check `~/.nvm/alias/default` exists; alias chains like `lts/iron` are followed automatically; if unresolvable, the latest installed version is used as fallback |

## Files

| Path | Purpose |
|---|---|
| `references/drmclaw.vscode-settings.jsonc` | Recommended VS Code settings for agent workflows |
