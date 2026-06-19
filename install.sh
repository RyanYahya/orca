#!/bin/bash
# orca installer (Codex-only).
#
# Installs the per-repo .orca/ workspace (scripts, templates, profiles, workflow
# dirs), appends an AGENTS.md pointer, writes a scoped project .codex/config.toml,
# and copies the orca-exec / orca-audit profiles into your Codex home.
#
# The $orca / $simplify SKILLS come from the plugin itself:
#     codex plugin marketplace add RyanYahya/orca
#     codex plugin add orca@orca
#
# Run from a clone:   bash install.sh --target /path/to/repo
# Or bootstrap:       bash <(curl -fsSL https://raw.githubusercontent.com/RyanYahya/orca/main/install.sh)
#
# Flags: --target <dir> (default: cwd) · --source <plugin dir> · --force

set -euo pipefail

REPO_URL="https://github.com/RyanYahya/orca"
TARGET="$(pwd)"
SOURCE=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    -h|--help) echo "usage: install.sh [--target <repo>] [--source <plugin dir>] [--force]"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Resolve SOURCE: the plugins/orca dir. Use our own location if it looks like a
# clone; otherwise bootstrap-clone the repo to a temp dir.
if [[ -z "$SOURCE" ]]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  if [[ -n "$SELF_DIR" && -d "$SELF_DIR/plugins/orca/scripts" ]]; then
    SOURCE="$SELF_DIR/plugins/orca"               # run from a clone of the orca repo
  else
    command -v git >/dev/null 2>&1 || { echo "ERROR: git required to bootstrap" >&2; exit 1; }
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    echo "→ fetching orca…"
    git clone --depth 1 --branch main "$REPO_URL" "$TMP" >/dev/null \
      || { echo "ERROR: clone failed from $REPO_URL" >&2; exit 1; }
    SOURCE="$TMP/plugins/orca"
  fi
fi
[[ -d "$SOURCE/scripts" ]] || { echo "ERROR: source not found at $SOURCE" >&2; exit 1; }

TARGET="$(cd "$TARGET" && pwd)"
ORCA="$TARGET/.orca"
echo "→ installing orca into: $TARGET"

# 1. scripts (always refresh — they're code, not state)
mkdir -p "$ORCA/scripts"
cp -R "$SOURCE/scripts/." "$ORCA/scripts/"
chmod +x "$ORCA/scripts/"*.sh "$ORCA/scripts/lib/"*.sh 2>/dev/null || true

# 2. templates → .orca (don't clobber an existing audit-map/agents/schema)
cp -n "$SOURCE/templates/audit-map.json"   "$ORCA/audit-map.json"   2>/dev/null || true
cp    "$SOURCE/templates/audit.schema.json" "$ORCA/audit.schema.json"
mkdir -p "$ORCA/agents"
for f in "$SOURCE/templates/agents/"*.md; do cp -n "$f" "$ORCA/agents/$(basename "$f")" 2>/dev/null || true; done
mkdir -p "$ORCA/automations"
cp -n "$SOURCE/templates/automations/"*.json "$ORCA/automations/" 2>/dev/null || true
mkdir -p "$ORCA/worktree-templates"
cp -Rn "$SOURCE/templates/worktree/." "$ORCA/worktree-templates/" 2>/dev/null || true

# 3. workflow dirs
mkdir -p "$ORCA/workflows/current" "$ORCA/workflows/archived"

# 4. profiles → Codex home (named files; additive, not edits to your config.toml)
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME"
for p in orca-exec orca-audit; do
  if [[ -f "$CODEX_HOME/$p.config.toml" && "$FORCE" -ne 1 ]]; then
    echo "  · kept existing $CODEX_HOME/$p.config.toml (use --force to overwrite)"
  else
    cp "$SOURCE/profiles/$p.config.toml" "$CODEX_HOME/$p.config.toml"
  fi
done

# 5. scoped project config (the app + CLI inherit this when the project is trusted)
if [[ ! -f "$TARGET/.codex/config.toml" ]]; then
  mkdir -p "$TARGET/.codex"
  cat > "$TARGET/.codex/config.toml" <<'EOF'
# orca requirements for this project (Codex reads this when the project is trusted).
approval_policy = "never"
sandbox_mode = "workspace-write"   # a read-only sandbox makes phases fail to write/commit

[features]
multi_agent = true                 # native subagent audit fan-out

[agents]
max_threads = 6
max_depth = 1
EOF
  echo "  · wrote .codex/config.toml (workspace-write + multi_agent)"
else
  echo "  · .codex/config.toml exists — ensure it has: sandbox_mode=\"workspace-write\", [features] multi_agent=true, [agents] max_threads/max_depth"
fi

# 6. AGENTS.md pointer (idempotent; create if none)
AGENTS="$TARGET/AGENTS.md"
if ! { [[ -f "$AGENTS" ]] && grep -q "## Orca" "$AGENTS"; }; then
  cat >> "$AGENTS" <<'EOF'

## Orca

This repo uses the orca workflow. State lives in `.orca/` — never recreate it from memory; `.orca/workflows/current/status.json` is the single source of truth. Use `$orca plan`, `$orca execute`, `$orca resolve`, `$orca archive` (see the orca skill). Every executed phase gets a mandatory parallel subagent audit before it is committed; respect `.orca/workflows/current/.lock`.
EOF
  echo "  · appended Orca pointer to AGENTS.md"
fi

# 7. gitignore the live workflow (keep archived/ tracked)
GI="$TARGET/.gitignore"
if ! { [[ -f "$GI" ]] && grep -q "^.orca/workflows/current/" "$GI"; }; then
  printf '\n# orca live workflow state\n.orca/workflows/current/\n' >> "$GI"
  echo "  · added .orca/workflows/current/ to .gitignore"
fi

echo
echo "✓ orca installed."
echo "  Skills:   codex plugin marketplace add RyanYahya/orca && codex plugin add orca@orca"
echo "  Plan:     \$orca plan <task>"
echo "  App:      \$orca app-setup   (desktop Automations + worktree)"
echo "  CLI run:  bash .orca/scripts/phase-runner.sh"
echo "  Codex will ask to trust this project on first use — approve it so .codex/config.toml loads."
