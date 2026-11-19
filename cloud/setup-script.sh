#!/usr/bin/env bash
# Claude Code cloud-environment setup script.
# Installs model-router into the sandbox's ~/.claude so every cloud session (web, mobile,
# desktop, `claude --cloud`) routes work across the pinned agents, with no per-repo commits.
# Paste into claude.ai/code -> environment settings -> Setup script. Runs once per environment,
# then the filesystem snapshot is cached for about seven days.
# Profile: set MODEL_ROUTER_PROFILE=balanced|max|pro|cost in the environment variables (default balanced).
# Packs:   set MODEL_ROUTER_PACKS=core (default, 8 agents) | comma list of core,writing,ops,gate,product | all.
RAW="${MODEL_ROUTER_RAW:-https://raw.githubusercontent.com/NathalieChouLab/model-router-claude/main}"
PROFILE="${MODEL_ROUTER_PROFILE:-balanced}"
case "$PROFILE" in quality) PROFILE=max ;; fable-lean) PROFILE=balanced ;; esac
PACKS="${MODEL_ROUTER_PACKS:-core}"
[ "$PACKS" = all ] && PACKS="core,writing,ops,gate,product"
case ",$PACKS," in *,core,*) ;; *) PACKS="core,$PACKS" ;; esac

install_into() {
  local DEST="$1" a pack rung pin m e
  mkdir -p "$DEST/agents" "$DEST/skills/model-router/references" 2>/dev/null || return 0
  curl -fsSL "$RAW/cloud/manifest.txt" -o /tmp/mr-manifest.txt || { echo "model-router: manifest fetch failed"; return 0; }
  while read -r f; do
    [ -n "$f" ] && curl -fsSL "$RAW/$f" -o "$DEST/$f" || true
  done < /tmp/mr-manifest.txt
  curl -fsSL "$RAW/agents.tsv" -o /tmp/mr-agents.tsv || { echo "model-router: agent list fetch failed"; return 0; }
  curl -fsSL "$RAW/profiles/$PROFILE.tsv" -o /tmp/mr-profile.tsv || true
  while IFS=$'\t' read -r a pack rung; do
    [ -n "$a" ] || continue
    case ",$PACKS," in *",$pack,"*) ;; *) continue ;; esac
    curl -fsSL "$RAW/agents/$a.md" -o "$DEST/agents/$a.md" || continue
    [ -s /tmp/mr-profile.tsv ] || continue
    # A row named after the agent overrides the row for its rung.
    pin="$(awk -F'\t' -v a="$a" -v r="$rung" '$1==a{am=$2;ae=$3} $1==r{rm=$2;re=$3} END{if(am!="")print am" "ae; else print rm" "re}' /tmp/mr-profile.tsv)"
    m="${pin%% *}"; e="${pin##* }"
    [ -n "$m" ] && [ -n "$e" ] && sed -i.bak -e "s/^model: .*/model: $m/" -e "s/^effort: .*/effort: $e/" "$DEST/agents/$a.md" && rm -f "$DEST/agents/$a.md.bak"
  done < /tmp/mr-agents.tsv
  local CM="$DEST/CLAUDE.md"
  if ! grep -qs 'model-router' "$CM"; then
    printf '\n# model-router (auto-start)\n- Apply `~/.claude/skills/model-router/SKILL.md` to every non-trivial task: classify, state one `Routing:` line, delegate parts to the agents in `~/.claude/agents/`, verify with a different agent, re-route at each checkpoint. Trivial one-step tasks skip it.\n' >> "$CM"
  fi
  echo "model-router ($PROFILE, packs $PACKS) installed to $DEST: $(ls "$DEST/agents" | wc -l | tr -d ' ') agent files"
}

install_into "${HOME:-/root}/.claude"
[ "${HOME:-/root}" != "/root" ] && [ -w /root ] && install_into /root/.claude
true
