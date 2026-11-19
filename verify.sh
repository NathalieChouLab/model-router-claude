#!/usr/bin/env bash
# Smoke test: spawns one installed agent per rung and checks which model answered.
# Makes four small real requests, so it uses a little of your allowance.
# Run from a directory outside any project so only ~/.claude agents are in play.
set -uo pipefail
DEST="${CLAUDE_HOME:-$HOME/.claude}"
command -v claude >/dev/null || { echo "claude CLI not found"; exit 1; }
FAIL=0
for a in scout builder verifier architect; do
  f="$DEST/agents/$a.md"
  [ -f "$f" ] || { echo "SKIP $a (not installed)"; continue; }
  want="$(sed -n 's/^model: //p' "$f" | head -1)"
  case "$want" in claude-*) id="$want" ;; *) id="claude-$want" ;; esac
  # The main session runs on a different family, so a match can only come from the agent.
  case "$want" in *haiku*) main=sonnet ;; *) main=haiku ;; esac
  out="$(claude -p "Use the $a agent with this exact brief: 'Reply with the single word ok. Use no tools.' Then repeat its reply." --model "$main" --output-format json 2>/dev/null)"
  if printf '%s' "$out" | grep -q "\"$id"; then echo "PASS $a answered on $want"
  else echo "FAIL $a: expected $want, models seen: $(printf '%s' "$out" | grep -o '"claude-[a-z0-9-]*"' | sort -u | tr '\n' ' ')"; FAIL=1; fi
done
exit $FAIL
