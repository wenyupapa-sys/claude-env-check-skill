#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-${0:-}}"
ROOT="$(cd "$(dirname "$SCRIPT_SOURCE")" 2>/dev/null && pwd || pwd)"
REPO_URL="${CLAUDE_ENV_CHECK_REPO_URL:-https://github.com/wenyupapa-sys/claude-env-check-skill.git}"
DEST_PARENT="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
DEST="$DEST_PARENT/claude-env-check"
BIN_PARENT="${CLAUDE_ENV_CHECK_BIN_DIR:-$HOME/.local/bin}"
BIN="$BIN_PARENT/claude-env-check"
TMP_DIR=""

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [ -f "$ROOT/claude-env-check/SKILL.md" ]; then
  SRC="$ROOT/claude-env-check"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required for remote installation." >&2
    exit 1
  fi
  TMP_DIR="$(mktemp -d)"
  git clone --depth=1 "$REPO_URL" "$TMP_DIR/claude-env-check-skill" >/dev/null
  SRC="$TMP_DIR/claude-env-check-skill/claude-env-check"
fi

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "Cannot find skill source at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST_PARENT"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
chmod +x "$DEST/scripts/claude-env-check.sh"

mkdir -p "$BIN_PARENT"
cat > "$BIN" <<EOF
#!/usr/bin/env bash
exec "$DEST/scripts/claude-env-check.sh" "\$@"
EOF
chmod +x "$BIN"

echo "Installed claude-env-check to $DEST"
echo "Installed CLI to $BIN"
case ":$PATH:" in
  *":$BIN_PARENT:"*) ;;
  *) echo "Note: add $BIN_PARENT to PATH to run 'claude-env-check' directly." ;;
esac
echo 'Try: Use $claude-env-check to audit my Claude Code proxy, timezone, DNS, and environment-variable risk.'
