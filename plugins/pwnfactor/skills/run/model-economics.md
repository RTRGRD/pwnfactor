# Model economics - spend the frontier model where it changes the outcome

Applies whenever the MAIN LOOP runs a frontier/metered model (e.g. Claude Fable) above the
workhorse tier (Opus). The operator's goal, verbatim: **"the best results for the least amount of
money - we still want good results, obviously."** Both failure directions are real: burning
frontier tokens on mechanical work, and letting a cheap model review a money/auth surface.

## The one mechanical rule

**Never let a subagent silently inherit the main-loop model.** The Agent tool inherits the parent
model when `model:` is omitted - on a frontier main loop that quietly spends the exact budget being
protected. Every Agent call sets `model:` explicitly. No exceptions.

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
harness's 5-step scale (`low | medium | high | xhigh | max`) - via agent-definition frontmatter
or the Workflow `agent(..., {effort})` option. Pair the dials deliberately: `haiku`/`sonnet` x
`low`-`medium` for mechanical bulk; `opus` x `high` for typical HIGH-surface implementation;
`opus` x `xhigh`/`max` only for the hardest adjudication/verify/novel-design units. A cheap
model at max effort is usually a worse buy than the next model up at medium.

## Tie-breaker

Unsure between two tiers on SHIPPED behavior → the higher tier (the risk rubric's
"when in doubt, HIGH," applied to models). Trivial and fully specified → the lower tier, no guilt.
