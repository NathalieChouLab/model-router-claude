---
name: model-router
description: Project-agnostic routing of work to the right model tier and effort level, re-decided at every checkpoint of a task. Use at the start of any non-trivial task (coding, debugging, architecture, content, research) and again whenever a part finishes, a verdict comes in, or the task changes shape mid-way — shift down when work becomes mechanical, shift up on evidence. Classifies the task, picks the strongest tier the part warrants (quality-first), delegates to a model-pinned subagent, verifies, and escalates on failure. Install once at ~/.claude/ and it applies to every repo.
---

# Model router

Goal: **quality first, on the cheapest rung that delivers it.** Agents sit on
four rungs — fast, mid, strong, top — and the installed profile decides which
model and effort each rung gets. Makers sit one rung below their checkers, and
the top rung is kept for what is expensive to get wrong. The cheaper rungs
exist to keep the main context clean and the top model focused, not to save
money at the risk of a wrong cut. Never trade correctness for cost.

## Step 1 — classify the task (30 seconds, no tools)

Score the task on four axes, 0–2 each:

| Axis | 0 | 1 | 2 |
|---|---|---|---|
| **Ambiguity** | fully specified | some judgment | goal known, approach unknown |
| **Blast radius** | scratch / reversible | one module | billing, auth, data, deploy, public API, irreversible |
| **Novelty** | pattern exists in repo | adapt a pattern | unfamiliar code or new architecture |
| **Verification** | tests/lint prove it | partially testable | only human review can confirm |

Sum → tier:

- **0–1 → SCOUT tier (fast rung).** Exploration, grep, summarizing
  logs, renames, formatting, boilerplate, reading docs.
- **2–4 → BUILDER tier (mid rung).** Implementing an agreed plan, tests, docs,
  refactors covered by tests, UI copy, well-specified features.
- **5–8 → PLANNER or ARCHITECT tier (strong / top rung).** Investigating unfamiliar code to produce
  a plan, architecture and trade-off decisions, root-causing a bug with unknown
  cause, anything touching billing/auth/security/deletion, writing specs or
  prompts other sessions will execute.

**Planner before architect.** At blast radius 0–1 the plan, the investigation
and the trade-off go to PLANNER (strong rung). ARCHITECT (top rung) is for blast
radius 2, irreversible or architecture-level decisions, specs other sessions
will execute, and parts where the planner already failed. Wherever this file
says ARCHITECT for a part at blast radius 0–1, read PLANNER first.

**Hard overrides (ignore the score):** blast radius = 2 → ARCHITECT always.
User says "just do it quickly" on a reversible task → drop one tier.
Legal/financial/medical substance → ARCHITECT.

## Step 2 — split before routing

Most real tasks are mixed. Split them so each part runs at its own tier:

```
investigate + plan      → ARCHITECT   (stop, present plan, wait if blast radius ≥ 1)
plan reversible work    → PLANNER     (blast radius 0–1; promotes to architect if it finds billing/auth/data)
external facts / docs   → RESEARCHER  (library APIs, versions, platform behaviour; sourced)
find/grep/summarize     → SCOUT       (run in parallel, results only, keeps main context clean)
write the tests         → TESTER      (from the brief, not the implementation; before or beside the builder)
implement the plan      → BUILDER
prose: docs, copy, README → WRITER    (from an approved outline; never decides positioning)
verify                  → VERIFIER    (never the same agent that wrote the code)
final gate on a         → AUDITOR     (only if blast radius = 2; SHIP / DO NOT SHIP)
blast-radius-2 change
cause of a failure      → DEBUGGER    (reproduce, bisect, instrument; hands cause + repro to architect/builder)
UI / visual review      → DESIGNER    (renders the page, checks against a written standard)
numbers people act on   → ANALYST     (code-computed, re-runnable; DECISION-GRADE figures go to auditor)
long material to digest → LIBRARIAN   (reads it all once, returns a cited brief; keeps it out of main context)
many tasks handed over  → COORDINATOR (ordered queue with tiers, dependencies, done-criteria; main session executes top-down)
briefs / specs / prompts for other agents → PROMPTSMITH (always top tier: errors multiply per run)
prose review            → EDITOR      (against a voice guide; never the writer)
legal / regulatory substance → COUNSEL (jurisdiction, primary sources, what a professional must confirm)
system / ops / deploy work → OPERATOR  (read-only diagnosis first; blast radius 2 stops for the human)
logs, health, status checks → MONITOR  (reports only what changed or looks wrong)
mechanical edits, renames, formatting, apply a diff → CLERK  (cheapest model; stops on any decision)
run a command / test suite and report → RUNNER  (cheapest model; output stays out of main context)
quick summary of one file, diff, or thread → DIGEST (cheapest model; promotes to librarian if it matters)
one-file fix with known cause and existing check → QUICKFIX (small model; one attempt, then builder)
```

## Step 3 — delegate to the pinned subagents

Use the Agent tool with the matching subagent (they live in `~/.claude/agents/`
and each pins its model):

Core pack (always installed):

- `scout` — fast, read-only lookup
- `runner` — fast, runs the named command and reports pass/fail compactly
- `quickfix` — mid at low effort, one small fix proven by an existing check
- `builder` — mid, edits + runs checks
- `planner` — strong, read-only, plans reversible work (blast radius 0–1)
- `debugger` — strong, may add temporary instrumentation to find a cause
- `verifier` — strong, read-only, adversarial
- `architect` — top, plans and decisions at blast radius 2

Opt-in packs (`PACKS=...` at install):

- **writing** — `writer` (mid), `editor` (strong, never the writer), `researcher` (mid, web, sourced facts), `librarian` (mid, long material → cited brief), `digest` (fast, ten-line summary)
- **ops** — `operator` (strong, diagnose read-only first), `monitor` (fast, log/health checks), `clerk` (fast, mechanical edits, no decisions)
- **gate** — `auditor` (top, read-only final gate for blast radius 2), `promptsmith` (top, briefs/specs/prompts others execute), `counsel` (top, legal/regulatory with primary sources)
- **product** — `designer` (strong, UI review against a standard), `analyst` (mid, numbers by shown code), `tester` (mid, tests independent of the builder), `coordinator` (strong, multi-task request → ordered queue)

**If an agent named in this file is not installed**, check `~/.claude/agents/`
and route the part to its core stand-in, saying so in the routing line:
writer, tester, analyst, clerk → `builder` · editor, designer → `verifier` ·
researcher, librarian, digest, monitor → `scout` (promote to `planner` if it
needs judgment) · operator → `builder` after a `planner` plan · coordinator →
`planner` · auditor, promptsmith, counsel → `architect`.

Each agent file pins **both** a model and an effort level, so switching tier
switches effort automatically:

| Agent | Rung | When reasoning is the bottleneck for this part |
|---|---|---|
| `scout` | fast | nothing — never bump a scout |
| `researcher` | mid | name the conflicting sources in the brief |
| `builder` | mid | list the edge cases in the brief (concurrency, migrations); "ultrathink" only on a retry after a failed verification |
| `tester` | mid | list the concurrency or security cases to cover |
| `writer` | mid | attach the positioning or voice guide |
| `verifier` | strong | point at the subtle part of the change |
| `planner` | strong | "ultrathink" when the code is unfamiliar |
| `architect` | top | "ultrathink" for irreversible / unknown-cause work |
| `auditor` | top | nothing — its effort is already the highest in the profile; split the change instead |
| `designer` | strong | write the standard down first |
| `debugger` | strong | "ultrathink" for intermittent or concurrency bugs |
| `analyst` | mid | ask for every derivation step to be shown |
| `librarian` | mid | nothing — reading is the work |
| `coordinator` | strong | name the shared files or conflicting tiers |
| `promptsmith` | top | "ultrathink" for prompts that many sessions will run |
| `editor` | strong | nothing — the standard does the work |
| `counsel` | top | "ultrathink" for multi-jurisdiction or high-stakes questions |
| `operator` | strong | require the command list before any state-changing command |
| `monitor` | fast | nothing — never bump a monitor |
| `clerk` | fast | nothing — if it needs thought it is not clerk work |
| `runner` | fast | nothing |
| `digest` | fast | nothing — promote to librarian instead |
| `quickfix` | mid | nothing — promote to builder instead |

The model and effort behind each rung come from the installed profile
(`balanced` by default: fast = Haiku low, mid = Sonnet medium, strong = Opus
medium, top = Fable low; `max`, `pro` and `cost` shift them). The pins are in
each agent's frontmatter; the routing rules below do not change with the profile.

One-off override without editing the files: the Agent tool's `model` parameter
beats the frontmatter (e.g. run `builder` with `model: fable` for a part that is
specified but unusually delicate).

Give each a **self-contained brief**: goal, constraints, files, definition of
done. Do not forward the whole conversation. Ask for a compact result
(findings, diff summary, verdict) — not file dumps.

State the routing in one line before starting, e.g.
`Routing: architect(ultrathink) → plan (stop for review) · builder → implement · verifier → check`.

## Step 3b — effort follows the tier

Model picks the ceiling; effort decides how much of it is used. Effort is
baked into each agent file, so you normally say nothing. When reasoning is the
bottleneck for *that part*, there are two levers, in this order:

1. **A sharper brief.** Name the risk: the edge cases, the conflicting sources,
   the subtle part of the change (table above). "Think hard" and "think harder"
   are plain words to current Claude Code, not effort switches.
2. **The literal word `ultrathink` in the brief.** It is the one thinking
   keyword Claude Code still recognises and it jumps that request to maximum,
   so keep it for blast radius 2, unknown-cause debugging, and retries after a
   failed verification.

- SCOUT and the other fast-rung agents → never. High effort on lookup work is pure waste.
- If neither lever is enough, go up a rung (Step 4) instead of stacking keywords.

## Step 4 — re-route at every checkpoint (mid-task switching)

Tiers belong to **parts**, not to the task. A checkpoint is any point where a
part ends or its shape changes: a plan gets approved, a subagent returns, a
verifier gives a verdict, a new fact appears, the user changes the ask. At
each checkpoint re-score the *next* part and switch tier if the score moved.
Switching down is normal and expected; switching up is triggered by evidence.

**Low-effort tiers first.** Before sending a part to the builder, ask whether it is
mechanical: a rename, a bulk replace, formatting, applying a diff already written,
running tests, summarizing one file, a one-line fix with a known cause and an
existing check. If yes, it goes to CLERK, RUNNER, DIGEST, or QUICKFIX at low
effort. These tiers stop and report the moment a decision is needed; that
report is the checkpoint that promotes the part.

**Shift UP when:**
- A part reveals unknown cause, unfamiliar architecture, or a trade-off → next part is ARCHITECT.
- Anyone finds the change touches billing/auth/data/deploy → stop, blast radius 2, ARCHITECT, wait for the human.
- Scout says "can't tell without reading deeply" → promote that part to BUILDER.
- Clerk stops on an ambiguity, digest says "promote to librarian", quickfix fails its one attempt → promote that part one tier (BUILDER, LIBRARIAN, BUILDER respectively). Never retry a low-effort tier.
- Builder fails verification **once** → if the failure is a contained slip, retry BUILDER with the failure spelled out in the brief (add "ultrathink" if the slip was a reasoning one); if it hints the plan or the cause is off, go straight to PLANNER, or ARCHITECT at blast radius 2. Quality-first means one failure is enough evidence.
- Builder fails verification **twice** → ARCHITECT, no exceptions.
- Verifier flags a BLOCKER it can't explain → ARCHITECT root-causes before anyone patches.
- Researcher returns UNKNOWN on a fact the plan depends on → ARCHITECT decides how to proceed without it; never let a builder assume.
- Auditor says DO NOT SHIP → back to ARCHITECT with the findings; the builder does not patch an audit failure directly.
- Builder or verifier hits a failure with no obvious cause → DEBUGGER first; ARCHITECT plans the fix from the debugger's confirmed cause.
- Analyst marks a figure DECISION-GRADE → AUDITOR before anyone acts on it.
- Monitor reports an anomaly → OPERATOR for system state, DEBUGGER for a failing behaviour, AUDITOR for anything security- or billing-shaped. The monitor itself never diagnoses.
- Operator hits production, credentials, DNS, or a remote host → blast radius 2: stop, write the command list, human executes.

**Shift DOWN when:**
- The plan is approved → implementation goes to BUILDER, not the architect.
- A part becomes a lookup or grep → SCOUT; a rename, bulk edit, or formatting pass → CLERK; a test run → RUNNER; a one-file summary → DIGEST; all in parallel where independent.
- A retry passed → the *next* part resumes its own natural tier; the escalation does not stick to the whole task.
- Verification is now mechanical (tests exist) → VERIFIER at default effort.
- The remaining work is prose (docs, changelog, copy) → WRITER, with the verifier checking claims against code.
- A UI part is built and testable → DESIGNER review in parallel with the verifier.
- The input is long material (spec, transcript, big log) → LIBRARIAN reads it once; everyone else works from the brief.
- The user hands over several tasks at once → COORDINATOR builds the queue first; then each item routes on its own score.
- Prose is written → EDITOR reviews it, never the writer.

**Never shift down:**
- Inside a part that is still running — finish it at the tier it started on.
- Below the tier of the code being debugged (a billing bug stays ARCHITECT even for a one-line fix).
- On anything the user will ship, publish, or send to another person — quality-first means verify with the verifier even when tests pass.
- On a part that has already failed once at that tier.

Announce every switch in one line so the trail is auditable:
`Re-route: builder → architect (cause unknown after 2 failed patches)` or
`Re-route: architect → builder (plan approved)`. If nothing changed, say nothing.

**What this session cannot do:** Claude cannot change the *main* session's
model or effort — `/model` and `/effort` are user-only. The main session stays
on the top model and does the routing; the switching happens by handing each
part to the pinned agents above. Do not suggest moving the main session to a
cheaper model; the user has chosen quality-first.

## Step 5 — build or answer

Only after routing is stated. If the task is trivial (score 0–1 and takes one
step), skip delegation and just do it — the router should never cost more than
the work it routes.

## When in doubt
Ambiguous classification → read `references/examples.md` (six worked routings).
Domain-specific rubrics, the brief template, effort mechanics, and anti-patterns →
`references/playbook.md`. Read them on demand; do not load them for trivial tasks.

## What this saves — and what it doesn't

Model choice doesn't shrink token counts; it changes the **weight** of each
token against usage limits and the **odds of a retry**. The savings come from:
(1) top-tier tokens only where judgment is required; (2) scouts keeping
exploration out of the main context; (3) fewer rewrites because plans are
reviewed before code is written. The single biggest waste is a cheap model
confidently taking a wrong architectural cut — which is why blast radius
overrides everything.
