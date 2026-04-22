#!/usr/bin/env bash
# YoLoIT Agent Hook — universal, works on macOS/Linux.
set -euo pipefail

EVENT="${1:-unknown}"

# Read JSON from stdin (don't fail if empty).
INPUT=""
if [ -t 0 ]; then
  INPUT="{}"
else
  INPUT=$(cat 2>/dev/null || echo "{}")
fi

CWD="$(pwd)"

# Create stable short hash of the CWD to use as filename key.
if command -v shasum >/dev/null 2>&1; then
  CWD_HASH=$(printf '%s' "$CWD" | shasum -a 256 | cut -c1-16)
elif command -v sha256sum >/dev/null 2>&1; then
  CWD_HASH=$(printf '%s' "$CWD" | sha256sum | cut -c1-16)
else
  CWD_HASH=$(printf '%s' "$CWD" | tr '/' '_' | tr -dc 'a-zA-Z0-9_-' | tail -c 16)
fi

HOOKS_DIR="${HOME}/.yoloit/hooks"
mkdir -p "$HOOKS_DIR"

# Debug log — always write so we can see what fired and when.
LOG_FILE="${HOOKS_DIR}/debug.log"
printf '[%s] EVENT=%s CWD=%s INPUT=%s\n' "$(date '+%H:%M:%S')" "$EVENT" "$CWD" "$INPUT" >> "$LOG_FILE" 2>/dev/null || true

STATUS_FILE="${HOOKS_DIR}/${CWD_HASH}.json"

# Extract useful fields from the input JSON (portable, no jq required).
extract_field() {
  local field="$1"
  printf '%s' "$INPUT" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
    sed 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | head -1 2>/dev/null || true
}

TOOL_NAME=$(extract_field "toolName")
TIMESTAMP=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || printf '%s000' "$(date +%s)")

# Build the status JSON.
STATUS_JSON="{\"event\":\"${EVENT}\",\"cwd\":\"${CWD}\",\"ts\":${TIMESTAMP}"

if [ -n "$TOOL_NAME" ]; then
  STATUS_JSON="${STATUS_JSON},\"tool\":\"${TOOL_NAME}\""
fi

STATUS_JSON="${STATUS_JSON}}"

# Write atomically (write to tmp then move).
TMP_FILE="${STATUS_FILE}.tmp.$$"
printf '%s\n' "$STATUS_JSON" > "$TMP_FILE"
mv -f "$TMP_FILE" "$STATUS_FILE"

# --- Sound on session end / error (macOS-first, Linux fallback) ---
play_sound() {
  local sound_file="$1"
  if [ "$(uname)" = "Darwin" ]; then
    afplay "$sound_file" 2>/dev/null &
  elif command -v paplay >/dev/null 2>&1; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
  elif command -v aplay >/dev/null 2>&1; then
    aplay /usr/share/sounds/ubuntu/notifications/Amsterdam.ogg 2>/dev/null &
  fi
}

case "$EVENT" in
  sessionEnd)
    play_sound "/System/Library/Sounds/Glass.aiff"
    ;;
  errorOccurred)
    play_sound "/System/Library/Sounds/Basso.aiff"
    ;;
esac

exit 0
