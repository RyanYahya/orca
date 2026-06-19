#!/bin/bash
# notify.sh — terminal bell + macOS notification for unattended runs.
# Usage: bash .orca/scripts/notify.sh "Your message here"

MESSAGE="${1:-orca needs attention}"
TITLE="Orca"

# Terminal bell + message
printf "\a"
echo ">>> NOTIFICATION: $MESSAGE"

# macOS notification via osascript (best-effort; ignored elsewhere)
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true
fi
