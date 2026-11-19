# model-router-claude

A skill plus pinned subagents that route each **part** of a task to the right model *and* effort level, and re-route at every checkpoint while the task is running. Eight core agents install by default; fifteen more specialists come in opt-in packs.

Claude Code cannot change its own session model mid-task (`/model` and `/effort` are user-only). This router works around that: your main session does the thinking about *who should do what*; each part is handed to a subagent whose file pins both a `model:` and an `effort:`. Switching tier switches both.

The idea in one line: **makers sit one rung below their checkers, and the top model is kept for what is expensive to get wrong.** A stronger model plans, a cheaper one builds, a stronger one checks, and the main session only reads their short reports.

## Core agents (default install)

Pins shown are the default `balanced` profile.

| Agent | Rung | Model · effort | Does |
|---|---|---|---|
| `scout` | fast | haiku · low | read-only lookup: grep, locate, summarize. Returns `path:line — fact`, never file dumps |
| `runner` | fast | haiku · low | runs the named command or test suite; reports pass/fail and only the failing lines |
| `quickfix` | mid | sonnet · low | one-file fix with a known cause and an existing check; one attempt, then promotes to builder |
| `builder` | mid | sonnet · medium | implements an agreed plan, runs the check that proves it |
| `planner` | strong | opus · medium | read-only: investigates and plans reversible work (blast radius 0–1) |
| `debugger` | strong | opus · high | reproduces, bisects, instruments to find a confirmed cause; hands off the fix |
| `verifier` | strong | opus · medium | adversarial, read-only review of someone else's change; `PASS`/`FAIL` with evidence |
| `architect` | top | fable · low | plans and decisions with blast radius 2 (billing, auth, data, deploy) |

## Packs (opt-in)

Every agent's description is loaded into every Claude Code session, so install only the specialists you will use.

| Pack | Agent | Rung | Does |
|---|---|---|---|
| `writing` | `writer` | mid | prose from an approved outline: README, docs, changelog, UI and marketing copy |
| | `editor` | strong | read-only prose review against a voice guide or standard; never the writer |
| | `researcher` | mid | read-only, web-enabled: library/API docs, versions, platform facts, with sources |
| | `librarian` | mid | digests long specs, transcripts, logs into a cited brief |
| | `digest` | fast | ten-line summary of one file, diff, or thread |
| `ops` | `operator` | strong | system administration: read-only diagnosis first, minimal change, every command reported |
| | `monitor` | fast | read-only log/health/status checks; reports only what changed or looks wrong |
| | `clerk` | fast | mechanical edits: renames, find-and-replace, formatting; stops on any decision |
| `gate` | `auditor` | top | read-only final gate for blast radius 2: `SHIP` / `DO NOT SHIP`, with rollback check |
| | `promptsmith` | top | read-only: writes briefs, specs, system prompts, and agent files other agents will execute |
| | `counsel` | top | read-only legal/regulatory analysis: jurisdiction, primary sources, what a professional must confirm |
| `product` | `designer` | strong | read-only UI/visual review against a written standard; returns a fix list |
| | `analyst` | mid | numbers computed by shown, re-runnable code; flags DECISION-GRADE figures |
| | `tester` | mid | writes and runs the tests from the brief, independently of the builder |
| | `coordinator` | strong | read-only: turns a multi-task request into an ordered queue with dependencies and done-criteria |

If the skill wants a specialist you have not installed, it routes that part to a core stand-in (for example writer → builder, editor → verifier, auditor → architect) and says so.

## How it routes

1. **Classify** the task on four axes, 0–2 each: ambiguity, blast radius, novelty, verification. Sum → scout (0–1), builder (2–4), planner or architect (5–8). Blast radius 2 overrides everything, goes to the architect, and stops for human review.
2. **Split** mixed tasks so each part runs on its own rung: planner plans, builder implements, runner runs the tests, verifier checks (never the author), debugger finds unknown causes, scouts grep in parallel.
3. **Delegate** with a self-contained brief: goal, constraints, files, definition of done, return shape.
4. **Re-route at every checkpoint.** Plan approved → builder. Unknown cause found → debugger. Builder fails verification → raise effort, then go up a rung. Retry passed → the next part drops back to its natural rung. Every switch is logged as one line: `Re-route: builder → planner (plan was off)`.
5. **Skip routing** for trivial one-step tasks. The router must never cost more than the work.

Details, domain rubrics, anti-patterns, and worked examples are in `skills/model-router/references/`.

## Install

```bash
git clone https://github.com/NathalieChouLab/model-router-claude.git
cd model-router-claude && ./install.sh
```

This copies `skills/model-router/` to `~/.claude/skills/` and the eight core agents to `~/.claude/agents/`, backing up anything already there. Open a new Claude Code session and give it a non-trivial task, or type `/model-router`.

```bash
PACKS=writing,ops ./install.sh   # core plus the packs you name
PACKS=all ./install.sh           # all 23 agents
./verify.sh                      # spawn one agent per rung and check which model answered (4 small requests)
./uninstall.sh                   # move the router's files to a backup folder
```

### Profiles: pick one for your plan

A profile maps the four rungs to a model and effort; a few agents carry their own row where they differ from their rung.

```bash
PROFILE=balanced ./install.sh   # default — Fable-level outcomes for the fewest top-model tokens
PROFILE=max ./install.sh        # strongest pins everywhere (Max, Team Premium, Enterprise, API)
PROFILE=pro ./install.sh        # Claude Pro, or no Fable access
PROFILE=cost ./install.sh       # usage-first on any plan
```

| Rung | balanced | max | pro | cost |
|---|---|---|---|---|
| fast | haiku · low | haiku · low | haiku · low | haiku · low |
| mid | sonnet · medium | opus · high | sonnet · high | sonnet · medium |
| strong | opus · medium | opus · high | sonnet · high | sonnet · medium |
| top | fable · low | fable · high | opus · high | opus · high |

Per-agent exceptions:

- **balanced:** quickfix sonnet · low, debugger opus · high, auditor fable · high.
- **max:** scout, researcher and librarian on sonnet; quickfix sonnet · low; writer and editor opus · medium; auditor fable · max.
- **pro:** debugger, planner and coordinator opus · high; auditor opus · xhigh; quickfix sonnet · low; writer, editor, researcher and librarian sonnet · medium.
- **cost:** researcher and librarian haiku · medium; quickfix haiku · low; writer and editor sonnet · low; debugger, planner, coordinator and operator sonnet · high.

**Why `balanced` is the default.** It treats the top model as the scarce allowance. Sonnet makes, Opus plans and checks, and Fable is spent only on blast radius 2. Effort stays at medium except where a wrong answer costs a full loop (debugger, auditor).

**Why the `pro` profile looks like this.** On Claude Pro the session default is Sonnet, Opus draws on the same 5-hour usage window, and Fable can bill to usage credits rather than the plan's included limits (see [Claude Code model configuration](https://code.claude.com/docs/en/model-config)). So `pro` keeps the mechanical tiers on Sonnet at high effort, which is where most tokens go, and spends Opus only where judgment is expensive to get wrong. The routing rules are identical; only the pins change.

The tables live in `profiles/*.tsv` (rung or agent, model, effort per line) and `agents.tsv` (agent, pack, rung) — edit or add your own and install with `PROFILE=<name>`.

### Upgrading from an earlier version

- The default install is now the eight core agents. To keep everything you had, run `PACKS=all ./install.sh`.
- `PROFILE=quality` is now `PROFILE=max` with the same pins, and the default profile is `balanced`. To keep the old default, run `PROFILE=max PACKS=all ./install.sh`. The old names `quality` and `fable-lean` still work.
- `planner` is new: plans for reversible work go to it instead of the architect.

## Claude app (chat) edition

`claude-app/model-router-chat.zip` is an uploadable skill for the chat side of the Claude app, where subagents and model switching do not exist: it routes roles and reasoning depth instead. See `claude-app/README.md`.

## Porting to Codex

`skills/model-router/references/codex-port-prompt.md` is a ready-to-paste prompt that asks OpenAI Codex to discover its own model/effort/sub-agent levers and build the same router with `config.toml` profiles and `AGENTS.md`.

## Cloud sessions (Claude Code web, mobile, `claude --cloud`)

Cloud sessions run in a fresh sandbox and never see your machine's `~/.claude`. You do **not** need to commit the router into every repo: paste `cloud/setup-script.sh` into your cloud environment's **Setup script** field at [claude.ai/code](https://claude.ai/code) (environment settings). It runs once per environment, installs the router into the sandbox's `~/.claude` from this repo, and the snapshot is cached, so every later session on any repo starts with the agents ready. Choose the pins and packs with environment variables: `MODEL_ROUTER_PROFILE=balanced|max|pro|cost` (default `balanced`) and `MODEL_ROUTER_PACKS=core|writing,ops,...|all` (default `core`).

Per-repo install is still available for repos shared with people who don't use the setup script:

```bash
PROJECT_DIR=/path/to/your/repo ./install.sh   # writes .claude/ and a CLAUDE.md note; commit and push
```

## Requirements

Claude Code with subagent frontmatter `effort:` and per-call `model` override (≥ 2.1.25x). Installer and routing smoke test last run on 2.1.328.

## License

MIT
