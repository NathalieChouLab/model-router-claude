#!/usr/bin/env bash
# Installs the model-router skill and its pinned agents into ~/.claude (all projects).
# PACKS=core (default, 8 agents) | comma list of core,writing,ops,gate,product | all (23 agents)
# PROFILE=balanced (default) | max | pro | cost   — tables in profiles/*.tsv
# PROJECT_DIR=/path/to/repo installs into that repo's .claude/ (travels with the repo into Claude Code web/mobile cloud sandboxes).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${PROJECT_DIR:-}" ]; then DEST="$PROJECT_DIR/.claude"; else DEST="${CLAUDE_HOME:-$HOME/.claude}"; fi

PROFILE="${PROFILE:-balanced}"
case "$PROFILE" in
  quality)    echo "Note: PROFILE=quality is now called max."; PROFILE=max ;;
  fable-lean) echo "Note: PROFILE=fable-lean is now called balanced."; PROFILE=balanced ;;
esac
TABLE="$HERE/profiles/$PROFILE.tsv"
[ -f "$TABLE" ] || { echo "unknown PROFILE=$PROFILE (balanced|max|pro|cost)"; exit 1; }

PACKS="${PACKS:-core}"
if [ "$PACKS" = all ]; then PACKS="$(cut -f2 "$HERE/agents.tsv" | awk '!s[$0]++' | paste -sd, -)"; fi
case ",$PACKS," in *,core,*) ;; *) PACKS="core,$PACKS" ;; esac
for p in $(echo "$PACKS" | tr ',' ' '); do
  cut -f2 "$HERE/agents.tsv" | grep -qx "$p" || { echo "unknown pack '$p' (core|writing|ops|gate|product|all)"; exit 1; }
done

mkdir -p "$DEST/skills" "$DEST/agents"
BAK="$DEST/model-router-backup/$(date +%Y%m%d%H%M%S)"; mkdir -p "$BAK"
if [ -e "$DEST/skills/model-router" ]; then cp -R "$DEST/skills/model-router" "$BAK/skill"; fi
rm -rf "$DEST/skills/model-router"
cp -R "$HERE/skills/model-router" "$DEST/skills/model-router"

echo "Profile: $PROFILE · Packs: $PACKS"
N=0
while IFS=$'\t' read -r a pack rung; do
  [ -n "$a" ] || continue
  case ",$PACKS," in *",$pack,"*) ;; *) continue ;; esac
  if [ -e "$DEST/agents/$a.md" ]; then cp "$DEST/agents/$a.md" "$BAK/$a.md"; fi
  cp "$HERE/agents/$a.md" "$DEST/agents/$a.md"
  # A row named after the agent overrides the row for its rung.
  pin="$(awk -F'\t' -v a="$a" -v r="$rung" '$1==a{am=$2;ae=$3} $1==r{rm=$2;re=$3} END{if(am!="")print am" "ae; else print rm" "re}' "$TABLE")"
  m="${pin%% *}"; e="${pin##* }"
  [ -n "$m" ] && [ -n "$e" ] || { echo "profile $PROFILE has no pin for $a ($rung)"; exit 1; }
  sed -i.tmp -e "s/^model: .*/model: $m/" -e "s/^effort: .*/effort: $e/" "$DEST/agents/$a.md"; rm -f "$DEST/agents/$a.md.tmp"
  printf '  %-12s %-8s %-7s %s\n' "$a" "$pack" "$m" "$e"
  N=$((N+1))
done < "$HERE/agents.tsv"
echo "Installed $N agents to $DEST. Start a new Claude Code session and type /model-router (or just give it a task)."
if [ "$PACKS" = core ]; then echo "More specialists: PACKS=writing,ops,gate,product (or PACKS=all) ./install.sh"; fi
if [ -n "${PROJECT_DIR:-}" ]; then
  CM="$PROJECT_DIR/CLAUDE.md"
  if ! { [ -f "$CM" ] && grep -q 'model-router' "$CM"; }; then
    printf '\n# model-router (auto-start)\n- Apply `.claude/skills/model-router/SKILL.md` to every non-trivial task: classify, state one `Routing:` line, delegate parts to the agents in `.claude/agents/`, verify with a different agent, re-route at each checkpoint. Trivial one-step tasks skip it.\n' >> "$CM"
  fi
  echo "Project mode: commit $PROJECT_DIR/.claude and CLAUDE.md so cloud sessions (Claude Code web/mobile) pick it up."
fi
if [ "$PROFILE" = balanced ]; then echo "On Claude Pro, or no Fable access? Re-run with: PROFILE=pro ./install.sh"; fi
