#!/usr/bin/env bash
# Removes the model-router skill and its agents from ~/.claude (or PROJECT_DIR/.claude).
# Nothing is deleted: files are moved to <dest>/model-router-backup/<timestamp>-uninstalled/.
# Only agent files named in agents.tsv are touched. If you keep your own agent under one
# of those names, move it back from the backup folder afterwards.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${PROJECT_DIR:-}" ]; then DEST="$PROJECT_DIR/.claude"; else DEST="${CLAUDE_HOME:-$HOME/.claude}"; fi
BAK="$DEST/model-router-backup/$(date +%Y%m%d%H%M%S)-uninstalled"; mkdir -p "$BAK"
N=0
while IFS=$'\t' read -r a _pack _rung; do
  [ -n "$a" ] || continue
  if [ -e "$DEST/agents/$a.md" ]; then mv "$DEST/agents/$a.md" "$BAK/$a.md"; N=$((N+1)); fi
done < "$HERE/agents.tsv"
if [ -e "$DEST/skills/model-router" ]; then mv "$DEST/skills/model-router" "$BAK/skill"; fi
echo "Moved $N agents and the skill to $BAK"
