#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir="$script_dir"
repo_root=$(CDPATH= cd -- "$source_dir/../.." && pwd)
workspace_root=$(CDPATH= cd -- "$repo_root/.." && pwd)
target_dir="$workspace_root/.github/agents"

mkdir -p "$target_dir"
cp "$source_dir"/*.agent.md "$target_dir"/

printf 'Synced Copilot agents from %s to %s\n' "$source_dir" "$target_dir"