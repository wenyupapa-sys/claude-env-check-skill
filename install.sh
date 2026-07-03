#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/claude-env-check"
DEST_PARENT="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
DEST="$DEST_PARENT/claude-env-check"

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "Cannot find skill source at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST_PARENT"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
chmod +x "$DEST/scripts/claude-env-check.sh"

echo "Installed claude-env-check to $DEST"
echo 'Try: Use $claude-env-check to audit my Claude Code proxy, timezone, DNS, and environment-variable risk.'
