#!/bin/bash
# Archive the current workflow to .orca/workflows/archived/YYYY-MM-DD-task-name/

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

ARCHIVE_DIR="$PROJECT_ROOT/.orca/workflows/archived"

if ! workflow_exists; then
  echo "No active workflow to archive."
  exit 0
fi

TASK_NAME=$(get_task_name)
DATE_PREFIX=$(date "+%Y-%m-%d")
SAFE_TASK_NAME=$(echo "$TASK_NAME" | tr ' ' '-' | tr -cd '[:alnum:]-_' | head -c 50)
ARCHIVE_NAME="${DATE_PREFIX}-${SAFE_TASK_NAME}"

mkdir -p "$ARCHIVE_DIR"
mv "$WORKFLOW_DIR" "$ARCHIVE_DIR/$ARCHIVE_NAME"

echo "Archived: $ARCHIVE_DIR/$ARCHIVE_NAME"
