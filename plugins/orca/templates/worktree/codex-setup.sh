#!/bin/bash
# orca worktree / Local Environment setup script.
#
# Point the Codex app's Local Environment setup at this (or copy to .codex/), so
# every fresh worktree boots with deps installed and is buildable — which is what
# a phase's `verify.auto` (typecheck/test/lint) relies on. Runs once per worktree.
#
# It auto-detects the package manager; extend it for your project's real build.

set -euo pipefail
cd "${1:-$(pwd)}"

if   [[ -f pnpm-lock.yaml ]];      then corepack enable >/dev/null 2>&1 || true; pnpm install --frozen-lockfile || pnpm install
elif [[ -f yarn.lock ]];           then corepack enable >/dev/null 2>&1 || true; yarn install --frozen-lockfile || yarn install
elif [[ -f bun.lockb ]];           then bun install
elif [[ -f package-lock.json ]];   then npm ci || npm install
elif [[ -f package.json ]];        then npm install
fi

[[ -f pyproject.toml && -d .venv ]] && { . .venv/bin/activate 2>/dev/null || true; }
[[ -f requirements.txt ]] && pip install -r requirements.txt || true
[[ -f Cargo.toml ]] && cargo fetch || true
[[ -f go.mod ]] && go mod download || true

echo "orca worktree setup complete: $(pwd)"
