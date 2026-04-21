---
name: copilot-agents
description: "Shared VS Code Copilot custom agent definitions for the drmclaw project — Code Review and Implement-and-Review workflows. Use this skill when setting up Copilot custom agents in a workspace, syncing agent definitions, configuring code review workflows, or when someone asks about the project's review process. Also use when a developer needs to understand how the Implement-and-Review loop works or wants to add a new custom agent."
---

# Copilot Agents

Shared VS Code Copilot custom agent definitions used across the drmclaw project. These agents enforce a structured code review workflow where every implementation goes through at least one review pass before completion.

## Agents

### Code Review

A read-only review specialist. Inspects diffs, changed files, or named code paths and returns severity-ranked findings. Never edits files.

**When to use:** Reviewing pull requests, current changes, regressions, security issues, API misuse, or code quality risks.

### Implement and Review

A coordinator that delegates edits to `Implement Changes` and review passes to `Code Review`, looping until zero material findings remain.

**When to use:** Any feature, bug fix, refactor, or documentation change where you want review built into the workflow.

### Implement Changes

A dedicated implementation worker. Makes focused edits per coordinator brief, runs validation, and returns a concise report.

**When to use:** Called by `Implement and Review` — not invoked directly.

## Setup

VS Code loads custom agents from the directories listed in the `chat.agentFilesLocations` setting (default: `.github/agents`). These paths resolve relative to each workspace folder. In a **multi-root workspace**, if you want agents available across all folders, put them in the workspace root's `.github/agents/` (the parent directory that contains each repo folder).

Copy the agent definitions from `agents/` within this skill to the appropriate runtime location:

- **Single-repo workspace:** the repo's own `.github/agents/`
- **Multi-root workspace:** the workspace root's `.github/agents/` (typically `../.github/agents` relative to this repo)

The target directory is gitignored — `agents/` in this skill is the canonical source. After copying, reload the VS Code window if agents don't appear immediately.

## Verification

**You must run this verification before considering the skill complete.**

Invoke the `Code Review` subagent to review any small file in the workspace. If the agent responds with findings (or "No findings."), the agents are loaded and working.

If the invocation fails with "agent doesn't exist" or similar:

1. Confirm files are in the right place — check `chat.agentFilesLocations` in the workspace file (`.code-workspace`) or `.vscode/settings.json`. Default is `.github/agents` relative to each workspace folder. Verify agent files exist at that resolved path.
2. Confirm YAML frontmatter is valid — each `.agent.md` must have `name` and `description` in the `---` block. Malformed frontmatter causes VS Code to silently skip the file.
3. Confirm source and deployed copies match — `diff` the skill's `agents/` directory against the deployed location to catch drift.

## Files

| Path | Purpose |
|---|---|
| `agents/code-review.agent.md` | Code Review agent definition |
| `agents/implement-and-review.agent.md` | Implement and Review agent definition |
| `agents/implement-changes.agent.md` | Implement Changes agent definition |

