---
name: compass-workflow
description: "How to work in a Compass-connected project: orient first, see the whole plan, bind work to a tracked task, record decisions and ADRs as you go, and mark done only when every acceptance criterion is met. Use at the start of every session and before claiming, recording or closing work."
---

# Compass — Mandatory Workflow Rules

Compass is the shared brain for your project — one source of truth for the
mission, roadmap, decisions, and design rules that humans and AI agents build
from, instead of rediscovering context every session. These rules keep that
brain in sync: orient from it first, work the slice it gives you, and write
every non-obvious choice back to it as you go.

## RULE 0 — Project context

Your session is scoped to one project at a time, identified by the
`X-Project: <slug>` header in `.mcp.json`. If absent, the server falls back
to your engineer's default project. To switch projects, edit `.mcp.json`
and restart Claude Code. Confirm what you're in with `get_me()` and the
build plan shown in `get_context()`.

## RULE 1 — Always orient first

The FIRST tool call of every session, before any code is read or written, is:

```
get_context()
```

It returns your **orient view** — mission, the ADRs for your work (scoped to
your active claims' domains, adr-040), governance, principles, themes, your own
**Active Claims** (`in_progress` tasks you own, with inline next-call hints),
"Fix first" findings, and the open-discussion count. Notably, it does NOT
include a global recent-decisions tail — that was historically chronological
noise unrelated to whatever you were about to work on. Call
`manage_decisions("list", since=..., module=...)` only when you actually need
decisions for a specific slice.

If you skip `get_context()`, stop and call it before continuing.

### Fix first

If the orient view has a **"Fix first"** section, the Night Watch found
problems in items you own (a task with no feature, a decision linked to
nothing, a feature with no acceptance criteria, …). Each line carries the
exact call that repairs it. Run those fixes **before** RULE 2 — before you
claim or continue any work — then call `manage_findings("recheck")` so the
findings close now instead of at the nightly tick. A finding whose fix call
says a human must act outside the record (data rows, UX behaviour, a failed
proof) is reported to the engineer, not fixed by the session.

## RULE 2 — See the whole plan, then pick a branch

After `get_context()`, **before you decide anything**, look at the plan that
already exists — not just the slice that happens to be yours:

```
get_roadmap()                       # the WHAT/WHY + every feature
manage_features("get", "<slug>")    # the feature you're about to touch — its planned task decomposition
manage_tasks("list")                # UNFILTERED — the whole queue, including unassigned planned work
```

`manage_tasks("list", owner="me")` shows only what is *already yours*. It does
**not** surface unassigned, team-planned tasks — running it alone is how a
session goes blind to a plan that is sitting right there (adr-012). Always do
the unfiltered look first; `owner="me"` is a later refinement, never the first
call.

### Any vague go-ahead ("continue", "keep going", "next") binds to a task

Before touching a single file, resolve the work to one tracked task and say so
out loud:

> Continuing task `<uuid>`: "<title>". Claiming it now.

Then `manage_tasks("claim", id="<uuid>", status="in_progress")`. If nothing in
the plan matches, say that explicitly and propose the task **before** creating
it — do not invent the next step from your own mental model and record a
decision in place of the plan. "Continue" means continue the *recorded* plan,
not improvise on top of it (adr-012).

Then branch:

### A — Continuing one of your Active Claims

If `get_context()` listed an Active Claim and you want to keep working on it:

```
get_trace("task", "<uuid_from_active_claims>")
```

`get_trace` returns the **focused slice** — parent feature, bound ADRs,
decisions and questions scoped to that task/feature. That is the only
context you need to work the task. Everything outside the slice is reachable
via focused tools (`manage_features("get", ...)`, `manage_adrs("get", ...)`,
`manage_decisions("list", ...)`) when you actually need it; don't pre-load it.

### B — Starting something new (no claim yet, or switching)

```
manage_tasks("list")                                       # the WHOLE queue — pick the planned task that fits
manage_tasks("claim", id="<uuid>", status="in_progress")   # claim it
get_trace("task", "<uuid>")                                # load the slice
```

Pick from the **existing** decomposition first. Only `manage_tasks("create", ...)` when
the unfiltered list and `manage_features("get", ...)` genuinely show no task
for this work — and, before creating **anything** (task, feature, ADR,
discussion), search the record by meaning:

```
manage_semantic("search", query="<what you are about to create>")
```

The queue check above catches duplicates by name; this catches them by
meaning, for a few hundred tokens (adr-037). Claim or link the match instead
of creating a twin. This is governance rule "Search by meaning before
creating" (warn). **Never create an umbrella task that overlaps a feature which
already has a decomposition** — claim its granular tasks instead; a broad
"do the chat work" task layered over four specific chat tasks hides which of
them are actually done (adr-012). The task must be claimed before you write
code. If a task is already `in_progress` by someone else, stop and flag it —
do not proceed without confirmation.

### C — Exploring, or starting a discussion

For roadmap orientation: `get_roadmap()`, then `manage_features("get", slug_or_id="<slug>")`
for the full spec (intent, scope, acceptance criteria, bound ADRs, linked tasks
and decisions, attachments).

To work through something with the team: open a **discussion** — it's the
source of truth (adr-010). `manage_questions("ask", title=..., body=...)` opens
one (the body is the opening post — required),
`manage_questions("link", id=..., target_type="engineer", target_id="<name>")`
invites + notifies an engineer, and
`manage_questions("post_message", id=..., kind=..., body=...)` posts a comment /
question / ADR draft / attachment *inside* it. Read the thread with
`manage_questions("get", id=...)` to reply to a specific message
(`kind="answer", ref_type="answer", ref_id=<message id>`); cite many artifacts on
one message with `message_links=[{target_type, target_id}, …]` (adr-011).
`manage_questions("resolve", id=..., create=[...], link=[...])` resolves it into
roadmap outputs. See Block C of `docs/the-idea.md` (superseded by adr-010/adr-011).

## RULE 3 — Record as you go, not at the end

Capture provenance at the moment the choice is made — not in a batch at
the end of the session. The value is the timestamp + the reasoning while
it's still fresh.

- **A link the record is missing** — an Active Claim in `get_context()` may
  carry a "→ by meaning" line naming the nearest *unlinked* items; run the
  `manage_semantic("propose_edges", ...)` call it gives you and offer the
  engineer the ratify call for each proposal that is right. Never draw the
  link yourself (adr-034: proposals only, a human ratifies).

- **Non-obvious choice** (library pick, pattern, API shape, trade-off)
  → `manage_decisions("record", module=..., decision=..., reason=..., task_id=..., feature_id=..., adr_id=...)`.
  Use `task_id` when the decision is about how *this* task was implemented;
  `feature_id` for broader feature-scoped decisions.

- **Uncertainty you can't resolve yet** — a non-obvious choice ahead but you
  don't have the answer → open a **discussion** (`ask`) and post it as a
  `question`-kind message inside (adr-010 — a discussion is the source of truth;
  there are no standalone questions). When a later decision or ADR settles it,
  `resolve` the discussion so the provenance link survives. See Block C of
  `docs/the-idea.md` (superseded by adr-010).

- **Architectural change** (persistence layer, auth model, API structure,
  deployment config, major new dependency) → `manage_adrs("record", title=...,
  context=..., decision=..., reason=..., impact=..., feature="<slug>")` before or
  immediately after the change. Always pass the feature it constrains — an
  unbound ADR reaches neither drift nor the orient scope.

- **Tasks are complete from birth (adr-042, adr-046)** — every task belongs to a
  roadmap feature (`feature_id`), carries at least one label saying what KIND of
  work it is (bug, feature, enhancement, chore, docs, refactor, test) and a
  one-sentence English `business_summary`. Compass refuses a task without them —
  a feature can be changed, never cleared; older tasks without one are flagged —
  and refuses a domain word as a label: WHERE a task lands
  (its domains) is Compass's job, not a label. Put the task's UUID in every
  commit message — that is how Compass knows which PRs and files built it.

- **Every task sits in an environment (adr-043)** — each project has the
  standard path development → staging → production plus any environments the
  team adds. A task you create starts in development unless you pass
  `environment=`; it moves forward by itself when its commits land on a deploy
  branch. Move it by hand only when it really changed place
  (`manage_environments("move", ...)`).

- **ADRs manage themselves (adr-040)** — do not set their domains or accept
  them by hand. Compass classifies every ADR into domains from a fixed
  vocabulary (backend, frontend, data, api, infra, security, ux, process, ai);
  domains are not an input and cannot be edited. A proposed ADR is accepted by
  Compass the first time the record shows it in use — a decision cites it
  (`adr_id=`), a bound feature or task goes active, a governance rule derives
  from it, or merged code cites it. Use `manage_adrs("update_status", ...)` only
  to deprecate or supersede. **Before changing an ADR**, run
  `manage_adrs("citations", adr_id=...)` — every code file and line that cites
  it — and treat that list as the blast radius of the change.

## RULE 4 — Mark done only when the acceptance criteria are met

Before marking anything done, open the task's feature and check **each
acceptance criterion** — done means *every* criterion is satisfied, not "I did
adjacent work that looks similar." A restyle does not satisfy a behavior
criterion ("composer auto-grows", "messages stream"). If a criterion isn't
met, the task stays in progress and you say which ones remain (adr-012).

When they are all met:

```
manage_tasks("claim", id="<uuid>", status="done")
```

before reporting completion to the engineer. This closes the loop so the
next session's `get_context()` orient view doesn't keep listing the task
as active.

### Say what proved it

Checking a criterion is knowledge that dies with the session unless you write
it down. When a test, script or CI job is what proves a criterion, bind it at
the moment you have just confirmed it:

```
manage_verifications("declare", feature="<slug>", clause=<N>, check="<test or script>")
```

`clause` is 1-based, the way the board numbers promises (AC1 = 1). CI then
reports that check's pass/fail and the Reality Board's `code` column fills
itself; until CI reports, the promise reads *pending* — declared is not proven.
The binding is **stated, never inferred**: a criterion that happens to name a
path is a hint, not proof (adr-031), so nothing records it unless you do. A
feature whose criteria are all met by checks nobody declared still reads
"unproven", which is the record lying about work you actually finished.

### Check the criterion, not your memory of it

"Done" is a claim about the code, so read the code. A queue where finished work
still says `in_progress` is worse than no queue — the next session claims
something already built, which is how 26 such tasks accumulated here.

And a merge is not a result. A change can pass every gate and do nothing: the
citation-index widening behind adr-046 merged green and moved no count at all
until a reindex ran, because the incremental path only reads files that
changed. Where a criterion is observable, observe it on the running system
before you report it met.

## RULE 5 — Project governance loads at orient; follow it

The project's working law — branch policy, merge policy, schema-change
discipline, process rules — lives in Compass as **governance rules**
(adr-025), NOT in this file. `get_context()` renders them under
**"Governance — how we work here"** with a severity badge:

- `[guide]` — convention; follow it.
- `[warn]` — a violating PR gets a warning section in its Compass comment.
- `[block]` — a violating PR **fails the `compass/drift` commit status**
  and cannot merge while branch protection is on.

Do not re-record these rules here or in memory files — this file only
points at them so there is exactly one copy. Read them at orient, follow
them while you work, and manage them with `manage_governance(...)`
(list / get / add / update / retire). Retire rather than delete: the
amendment history is the point.

---

## Violation = incomplete work

If any rule above was not followed, the work is considered incomplete
regardless of whether the code compiles or tests pass. Always orient,
branch, record, close.
