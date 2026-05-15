---
name: agent-shell
description: "Fast, minimal shell wrapper that gives VS Code Copilot agent terminals access to dev tools (node, pnpm, python3, brew, cargo) on macOS without shell-init overhead. Use this skill when setting up a new development machine, configuring VS Code for AI agent workflows, troubleshooting agent terminal PATH issues, terminal cwd drift, broken terminal stdout/prompt state after multiline agent commands, or when a Copilot agent terminal can't find node/pnpm/python3. Also use when someone asks about optimizing VS Code terminal startup time or making LLM coding agents more efficient."
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
  - `/opt/homebrew/opt/mysql-client/bin` (stable Homebrew client tool path)
   - `~/.local/bin` (user-local scripts)
   - `~/.cargo/bin` (Rust toolchain)

3. **Python fallback** — if `/Library/Frameworks/Python.framework/Versions/` has numbered subdirectories, prepend the `bin/` of the latest version (by version sort). Homebrew python3 is already covered by step 2.

4. **nvm node resolution** — resolve the default node version **without sourcing `nvm.sh`** (it's too slow). If `~/.nvm/versions/node` exists, read `~/.nvm/alias/default` to get the alias, follow one level of indirection from `~/.nvm/alias/<value>` if present, strip any leading `v`, glob-match `~/.nvm/versions/node/v<version>*`, and pick the latest. If alias resolution fails, fall back to the latest installed version under `~/.nvm/versions/node/`. Prepend the resolved `bin/` directory and export `NVM_DIR`.

5. **Sync stable system env from the real profile** — if `/Library/Developer/CommandLineTools` exists, export `DEVELOPER_DIR=/Library/Developer/CommandLineTools`. Only copy stable path/env facts from the real shell profile; do not source interactive shell init files.

6. **Repair cwd from an explicit handoff env var** — if `AGENT_SHELL_CWD` is set and points to an existing directory, `cd "$AGENT_SHELL_CWD"` before launching bash. This protects agent terminals from a real failure mode where VS Code starts the wrapper from a temp directory like `/private/tmp`; without an explicit cwd handoff, relative paths can resolve under the wrong directory.

7. **Repair terminal state before launch** — clear shell/debug variables that can leak from reused terminals, then normalize tty settings when possible. At minimum: `unset PROMPT_COMMAND`, `unset PS0`, export `TERM=dumb` only if the incoming `TERM` is empty, and run `stty sane 2>/dev/null || true`. This protects the agent shell from a real failure mode where an earlier multiline or half-interpreted command leaves the persistent terminal with a broken prompt or missing stdout.

8. **Launch bash** — set `SHELL=/bin/bash`, set `BASH_SILENCE_DEPRECATION_WARNING=1`, then `exec /bin/bash --norc --noprofile "$@"`.

Keep the wrapper self-describing: this skill is used during setup, but later debugging and runtime inspection often happen by opening `~/.local/bin/drmclaw-agent-shell` directly. Short comments beside non-obvious runtime safeguards such as `AGENT_SHELL_CWD`, prompt-state cleanup, and `stty sane` should remain in the shell script itself, not only here.

Foreground, timed-out, and background-retrieved agent terminal calls all go through the same wrapper process. That means two constraints matter for agent reliability: preserve incoming shell args verbatim with `"$@"`, and keep startup output minimal and deterministic so VS Code can detect command start, completion, and idle states correctly.

Add opt-in runtime introspection instead of startup banners. The wrapper should support `~/.local/bin/drmclaw-agent-shell --about` to print a short summary of its behavior and exit. This gives agents and humans a runtime way to inspect the wrapper without polluting normal command output.

Why `"$@"` matters: VS Code may pass shell arguments such as `-c`, login flags, or shell-integration startup parameters when it spawns automation and agent terminals. If the wrapper drops those args, the terminal can start incorrectly or terminate immediately.

Why use `AGENT_SHELL_CWD`: the wrapper cannot trust `PWD` alone, because the shell rewrites `PWD` to the process's actual cwd before the script runs. A dedicated env var set by the terminal profile is stable and lets the wrapper recover the intended workspace even when the launch cwd is `/private/tmp`.

Why add a preserve-cwd escape hatch: when you manually invoke `~/.local/bin/drmclaw-agent-shell` from inside an existing agent terminal for debugging, the parent terminal may already export `AGENT_SHELL_CWD`. In that nested case, an unconditional `cd "$AGENT_SHELL_CWD"` hides the caller's real cwd. Support `DRMCLAW_AGENT_SHELL_PRESERVE_CWD=1` so manual nested tests can preserve the current directory without weakening normal agent launches.

Why silence the deprecation warning: macOS's bundled bash prints a one-time "default interactive shell is now zsh" banner unless `BASH_SILENCE_DEPRECATION_WARNING=1` is set. That extra banner pollutes terminal startup output and can confuse log parsing or lightweight command wrappers.

Why reset terminal state: agent sessions often reuse a persistent terminal after sending multiline snippets, heredocs, or partially echoed inline commands. If the shell is left in a bad tty or prompt state, later commands can appear to hang, lose stdout, or interleave old prompt text into new commands. The wrapper should start each spawned shell from a known-clean baseline instead of inheriting that damage.

Why not source `.zshrc` / `.bash_profile`: agent terminals must stay deterministic and fast. Copy only the stable path facts the machine actually relies on, such as fixed Homebrew prefixes, framework Python bins, `mysql-client`, and `DEVELOPER_DIR`.

Python policy: prefer exposing a single unambiguous `python3` on PATH. Do not add `conda` or a conda base `bin/` directory to the agent shell unless the machine explicitly depends on conda for routine CLI work and there is no stable direct `python3` available. The wrapper should not choose an environment manager on the agent's behalf.

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

Merge the settings from [`references/drmclaw.vscode-settings.jsonc`](references/drmclaw.vscode-settings.jsonc) into your User or Workspace settings. The critical entries are:

```json
"chat.tools.terminal.terminalProfile.osx": {
  "path": "~/.local/bin/drmclaw-agent-shell",
  "env": {
    "AGENT_SHELL_CWD": "${workspaceFolder}"
  }
},
"terminal.integrated.automationProfile.osx": {
  "path": "~/.local/bin/drmclaw-agent-shell"
}
```

Keep `AGENT_SHELL_CWD` scoped to `chat.tools.terminal.terminalProfile.osx`. Tasks and debug sessions may intentionally set their own working directory, and forcing a workspace-root `cd` via `terminal.integrated.automationProfile.osx` can break those launches.

## Verification

Do not treat shell syntax or a single happy-path command as sufficient validation. An agent-ready shell should be verified against the actual terminal behaviors that agents depend on: clean startup, deterministic cwd, reliable stdout, and correct handling of both short-lived and long-lived terminal calls.

### 1. Verify environment resolution

Confirm that the shell exposes the expected developer tools without sourcing interactive init files. The important outcome is not a specific command line, but that an agent terminal can immediately resolve the required toolchain from PATH and continue executing work without additional shell bootstrapping.

Pass criteria:
- The shell resolves the expected toolchain consistently.
- The resolved tools come from the intended stable locations.
- The shell does not depend on `.zshrc`, `.bash_profile`, `nvm.sh`, or other interactive startup scripts.

### 2. Verify startup cost

Measure repeated startup time for fresh shell launches. Agent workflows create many terminal sessions, so shell overhead must stay low enough that the wrapper does not dominate command latency.

Pass criteria:
- Repeated launches stay comfortably below the team's acceptable per-terminal overhead budget.
- The wrapper remains meaningfully close to bare `bash --norc --noprofile` startup time.
- No unnecessary subprocesses, shell-init loads, or slow filesystem probes dominate launch latency.

### 3. Verify agent terminal call patterns

Test the shell the way an agent actually uses terminals. The wrapper should support all three agent-side call patterns:

1. Foreground one-shot calls, where the agent waits for output immediately.
2. Long-running calls started directly in the background, where the agent retrieves output later.
3. Calls started in the foreground that time out and are then continued in the background.

For each pattern, verify these properties:
- Output appears promptly and without extra startup chatter.
- The shell preserves incoming arguments exactly as the terminal tool supplied them.
- Relative paths resolve from the intended working directory.
- Long-running sessions remain inspectable after backgrounding or timeout handoff.
- The wrapper does not emit banners, prompts, or debug text that would confuse later output retrieval.

### 4. Verify recovery-oriented behaviors

An agent-ready shell should also be tested against the failure modes agents actually hit during iterative terminal use.

Test these scenarios conceptually:
- Cwd repair: confirm the shell can recover the intended workspace when VS Code launches it from a temp directory.
- Terminal-state repair: confirm reused terminals still print stdout and prompts cleanly after multiline snippets, heredocs, or partially interpreted commands.
- Nested manual debugging: confirm there is a deliberate way to preserve the caller's current cwd when manually invoking the wrapper from inside an existing agent terminal.
- Runtime introspection: confirm the wrapper exposes a quiet, opt-in way to explain itself at runtime without polluting normal command execution.

### 5. Debugging approach

When validation fails, debug in this order:

1. Confirm the wrapper exists, is executable, and is the file VS Code is actually launching.
2. Reproduce the failure with the smallest terminal pattern that still shows it: tool resolution, cwd drift, missing stdout, or background retrieval.
3. Use shell tracing or targeted probes only long enough to identify the broken stage.
4. Re-run the same behavior-scoped validation after each fix instead of switching to a different scenario.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Agent terminal cannot find expected tools | Diagnose whether the wrapper is being launched at all, then verify that PATH construction exposes the intended stable tool locations without relying on interactive shell init |
| VS Code appears to ignore the wrapper | Diagnose the settings path first: make sure both the agent terminal profile and the automation profile point to the wrapper, and only then inspect the shell itself |
| Terminal exits immediately or the wrapper fails at startup | Treat this as an argument-forwarding or `set -e` safety problem first: verify the wrapper preserves incoming shell args exactly and that every conditional/helper path is safe under non-zero test results |
| Relative paths resolve from a temp directory instead of the workspace | Diagnose cwd handoff before PATH or shell syntax: confirm the agent terminal profile provides an explicit workspace cwd handoff and that only the chat terminal profile applies that repair |
| Reused agent terminals show mangled prompts, partial old commands, or missing stdout | Treat this as terminal-state corruption: verify the wrapper resets prompt/debug variables, best-effort restores sane tty state, and starts the next shell from a clean baseline |
| Manual nested wrapper tests keep jumping back to the workspace root | Diagnose inherited cwd handoff leakage: nested manual tests inside an existing agent terminal may need the preserve-cwd escape hatch so you can inspect the caller's actual directory |
| nvm node resolution is wrong or missing | Diagnose alias resolution before changing PATH rules: confirm the default alias exists, indirect aliases resolve cleanly, and the fallback logic selects the latest installed nvm version when the alias is unusable |

## Files

| Path | Purpose |
|---|---|
| `references/drmclaw.vscode-settings.jsonc` | Recommended VS Code settings for agent workflows |
