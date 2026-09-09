---
name: compact
description: Compact the context window on purpose, at a task boundary, after the state is written down - and audit what is eating the window (agents, skills, MCP tool schemas, CLAUDE.md, rules). Use when a session is long, before a long wait on background work, when responses degrade, or when asked "what is using my context" / "should I compact".
license: MIT
metadata:
  origin: adapted from ECC (affaan-m/ECC, MIT, Affaan Mustafa) skills strategic-compact + context-budget; the Node hook is not carried - the decision table and the audit are
---

# Compact - on purpose, at a boundary, after writing it down

> **Say this first:** "`/pwnfactor:compact` decides WHEN to compact (a task boundary, never mid-implementation), makes sure the state is on disk first, and can audit what is consuming the window."

Auto-compaction fires at an arbitrary point, usually mid-task, and the summary loses exactly the detail you needed.
Compacting on purpose costs one decision and keeps the plan.

## 1. Before compacting - the state must be on disk

Nothing in the conversation survives except what is written. Before `/compact`:
1. The plan / ledger file the project uses as its program counter is current (pwnfactor projects: the plan file `run`
   names, or the project's `CURRENT.md`/handoff). Write the next three motions, the ids of live background agents, and
   what each one is expected to return.
2. Decisions made this session are in the decision log, not only in chat.
3. Anything learned that should outlive the session is in memory (or the project's anti-pattern log).
4. Do not rely on a todo/task list surviving - it may not exist on this model or version. A file persists everywhere.

Then compact WITH a focus line: `/compact <what to keep: the unit in flight, the next motion, the open decision>`.

## 2. When to compact - the decision table

| transition | compact? | why |
|---|---|---|
| research / exploration -> planning | yes | the plan is the distilled output; the exploration is bulk |
| planning -> implementation | yes, once the plan is a FILE | free the window for code |
| implementation -> testing | maybe | keep if the tests reference code you just read; compact if switching focus |
| debugging -> next unit | yes | traces pollute the next unit |
| mid-implementation | no | file paths, names and partial state are expensive to lose |
| after a failed approach | yes | clear the dead-end reasoning before the new approach |
| before a LONG WAIT on background agents | yes | the wait is where sessions die on limits; wake with a small window and the ledger |
| a unit landed and its ledger entry is committed | yes | the natural boundary in an orchestration loop |

Signals that it is overdue: responses slow or lose coherence; the same fact is re-derived; a tool result had to be
re-read. Signals that it is too early: you are inside a fix round with findings in flight and unwritten.

## 3. What survives, what does not

Survives: CLAUDE.md and rules, files on disk, memory files, git state, the ledger you wrote. Lost: intermediate
reasoning, file contents you read, tool outputs, verbal preferences the user stated and you did not write down.

## 4. Audit what is eating the window (on request, or when it fills too fast)

Inventory and estimate, then rank by savings. Estimates: prose `words x 1.3`, code `chars / 4`.
- **Agents** (`.claude/agents/*.md`, plugin agents): every agent's DESCRIPTION is in the system prompt of every turn whether
  or not it runs; flag descriptions over ~30 words and bodies over ~200 lines.
- **Skills**: every skill's description is listed every turn; bodies load on demand. Flag overlapping skills.
- **MCP servers**: each tool schema costs roughly 500 tokens on every turn - usually the biggest lever. Flag servers with
  more than ~20 tools and servers that wrap a CLI you already have (`gh`, `git`, `npm`).
- **CLAUDE.md chain + rules**: always loaded; flag a combined total over ~300 lines and sections that repeat each other.
- **Hooks** cost nothing in the window (they run outside the model) - prefer a hook to a rule where enforcement is mechanical.

Report:
```
CONTEXT BUDGET
component       count   ~tokens
agents          N       ...
skills          N       ...
MCP tools       N       ...
CLAUDE.md+rules N       ...
top 3 savings: 1. <remove/lazy-load X> -> ~T tokens  2. ...  3. ...
```
Then the user decides; this skill removes nothing on its own.

## 5. Related

`/pwnfactor:run` (the plan file this skill expects to exist), `/pwnfactor:swarm` (why the lead waits on background
work), the project's memory directory (what to write before compacting).
