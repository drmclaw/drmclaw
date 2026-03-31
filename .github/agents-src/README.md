# Copilot Agent Sources

This directory is the git-tracked source of truth for the shared Copilot custom agents used in the workspace.

The runtime copies that VS Code currently recognizes in this workspace live in the workspace root at `.github/agents/`, which is not itself git-tracked.

After editing any `*.agent.md` file here, sync the runtime copies with:

```sh
./.github/agents-src/sync-copilot-agents.sh
```

The sync script copies all `*.agent.md` files from this directory into the workspace-root `.github/agents/` folder.