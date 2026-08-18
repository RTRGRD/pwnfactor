# Model economics - spend the frontier model where it changes the outcome

Applies whenever the MAIN LOOP runs a frontier/metered model (e.g. Claude Fable) above the
workhorse tier (Opus). The operator's goal, verbatim: **"the best results for the least amount of
money - we still want good results, obviously."** Both failure directions are real: burning
frontier tokens on mechanical work, and letting a cheap model review a money/auth surface.

## The one mechanical rule

**Never let a subagent silently inherit the main-loop model.** The Agent tool inherits the parent
model when `model:` is omitted - on a frontier main loop that quietly spends the exact budget being
protected. Every Agent call sets `model:` explicitly. No exceptions.

## The second mechanical rule

**A live subagent is a warm cache. Continue it; do not respawn.** Before every Agent call, check
whether an agent spawned earlier this session already holds the context this task needs. If one
does, use `SendMessage` with its id instead - it resumes with its context intact, where a fresh
Agent call re-reads every file from zero.

This is native harness behavior now, not a workaround: subagents run in the background by default
and PERSIST after finishing. `SendMessage` to a completed agent auto-resumes it with its full
conversation history, and agents treat those messages as normal mid-task direction - so course
corrections, round-two reviews, and "dig deeper" follow-ups all route to the agent that already
paid for the context.

The waste is invisible because both paths return a good answer. Only the token bill differs, and it
differs by the whole cost of re-reading the repo.

Continue the existing agent when:

- **A review has a round two.** The round-one reviewers already read the design docs, the spec and
  the diff. They also know what they recommended, so they can judge whether the fix actually
  addressed the finding - a fresh agent cannot, and will re-litigate settled points.
- **A finding needs verification or a repro.** Ask the agent that raised it. It has the trace.
- **A follow-up question falls inside what it already read.** "Dig deeper on X" beats a new agent
  with a longer prompt.
- **An answer came back incomplete or hedged.** Push back on the same agent. An incomplete result
  is a reason to iterate, never a reason to start over.

Spawn fresh only when the task is genuinely a different question over a different surface, or when
you deliberately want an independent perspective uncontaminated by the first (a second opinion is a
real reason - "I forgot the first one existed" is not).

**Keep the ids.** When an Agent call returns, its id comes back with it. Record the ids alongside
what each agent covered, so future-you can route a follow-up instead of re-deriving. An agent whose
id you have dropped is work you have already paid for and thrown away.

## Where the frontier model earns its cost (keep IN the main loop)

- **Orchestration** - framing, decomposition, sequencing, what-to-delegate-to-whom. This is the
  frontier model's home turf; delegating orchestration downward is a false economy.
- **Adjudication** - judging panel/codex findings (AGREE/DISAGREE/DEFER) against the actual code,
  and the synthesis of conflicting reviewer outputs. Judgment, not throughput.
- **Operator-requested audits** - when the operator explicitly asks for an audit / deep review /
  "what will bite us later," they are asking for the frontier model's review judgment (future
  misses, should-be-done-differently calls). Do that work in the main loop; delegate only the
  mechanical evidence-gathering beneath it.
- **Irreversible-gate decisions** - commit/push/deploy/money/auth judgment calls.
- **Novel or ambiguous design** - where the spec doesn't exist yet and writing it IS the work.

## What tiers DOWN (delegate with an explicit `model:`)

- **Implementation** - `opus` for HIGH-risk surfaces; `sonnet` for MEDIUM work **with a strong
  cited-anchor spec** (spec quality substitutes for model size on implementation - never on review).
- **Routine review passes** - the gg panel's own tiering stands (ROUTINE = `sonnet`, HIGH = `opus`).
  Not every code review needs the frontier model; the frontier model ADJUDICATES the panel's output.
  Floor: never review a HIGH surface (money/auth, shared contracts, sanitization, hot paths) below
  `opus`.
- **Recon / evidence-gathering** - Explore sweeps, "where is X handled": `sonnet`.
- **Mechanical bulk** - renames, format sweeps, grep-summaries, log triage: `haiku`.

## Free capacity - use it hardest

- **Cross-model CLI reviewers (codex)** cost zero main-loop tokens. Use liberally at every tier.
- **Deterministic gates** (tsc, tests, verify scripts, linters via Bash) prove more per token than
  any model pass. A subagent's "it works" claim is verified by re-running the gate, not by a second
  model reading the code.
- **Context hygiene is spend hygiene** - the main loop reads report summaries and small output
  slices, never whole files a subagent already read.

## The second dial: effort (set it explicitly too)

Model and reasoning effort are separate spends that MULTIPLY (swarm's two-dials law). The same
silent-inheritance rule applies: every spawned agent takes an explicit effort tier on the
harness's 5-step scale (`low | medium | high | xhigh | max`) - via the agent definition's
`effort:` frontmatter field or the Workflow `agent(..., {effort})` option. The frontmatter field
is the documented per-agent control - it overrides the session's effort level while that agent
runs - and the Agent tool has no per-call effort parameter, which is why the frontmatter
carries it. Pair the dials deliberately: `haiku`/`sonnet` x
`low`-`medium` for mechanical bulk; `opus` x `high` for typical HIGH-surface implementation;
`opus` x `xhigh`/`max` only for the hardest adjudication/verify/novel-design units. A cheap
model at max effort is usually a worse buy than the next model up at medium.

## Tie-breaker

Unsure between two tiers on SHIPPED behavior → the higher tier (the risk rubric's
"when in doubt, HIGH," applied to models). Trivial and fully specified → the lower tier, no guilt.
