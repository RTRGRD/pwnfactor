---
name: cards
description: Sets up and maintains SYSTEM CARDS in a repo - a versioned, per-subsystem decision-and-contract layer (contract, invariants, consumers, decisions with the WHY, known traps) plus an auto-loaded index and a staleness checker that fails loudly when a card goes out of date. Use when a user runs /pwnfactor:cards, asks for system cards or a decision log for agents, or complains that AI sessions keep forgetting the architecture and re-deriving or violating past decisions.
---

# /pwnfactor:cards - save your game 💾

> **Say this first:** "`/pwnfactor:cards` gives this repo a save file - one card per subsystem
> carrying its contract, invariants, and decisions with the WHY, plus a checker that turns red
> the moment a card goes stale. Future sessions stop re-deriving what was already decided."

**The problem this kills:** architecture docs say what exists, but the WHY of decisions dies at
every context boundary - compaction, a new session, a different agent. The result is re-derived
decisions, violated invariants, and tokens burned re-discovering what was already known. Cards fix
it only because they are (a) auto-discoverable, (b) updated as part of landing work, and
(c) CHECKED - a stale card turns red instead of quietly lying.

**Core principle - truth travels with the clone.** Card content lives in the target repo,
versioned, changed in the same commits as the code it describes. This skill carries only the
pattern. Never store card content in the plugin, in agent memory, or anywhere outside the repo.

## What lands in the repo (one-time)

```
cards/                one card per subsystem, 40-60 lines each
tools/card_check.py   copied from this skill's card_check.py
CLAUDE.md             gains a CARDS index section, 20 lines max
```

## Card schema (fixed - the checker enforces the section set)

```
# CARD: <subsystem>
## CONTRACT       what this promises callers, 2-5 lines
## INVARIANTS     must-not-change items, each with a one-line WHY
## CONSUMERS      real readers/callers as `path::symbol` - verified, not guessed
## DECISIONS      one-line ruling + one-line WHY + POINTER to the authoritative
                  source (spec / ADR / PR / commit). Pointers, never summaries.
                  Include REJECTED alternatives - they prevent the most expensive
                  re-derivations. A WHY you cannot source is written as
                  "WHY: unrecorded - flagged", never invented.
## KNOWN TRAPS    footguns already paid for (tooling that silently rewrites files,
                  ordering requirements, looks-missing-but-isnt cases)
```

**Citation convention:** `relative/path.ext::symbol` (double colon, backticks). The checker
resolves the path against the tree and requires the symbol to appear in that file. CONSUMERS
entries cite the CONSUMING file; add `declared: path` to name the declarer, and the two must
differ - consumption, not existence.

Worked example (Webcart, the fictional e-commerce SaaS):

```
# CARD: checkout
## CONTRACT
Turns a cart into a paid order exactly once. Idempotent on retry via order_key.
## INVARIANTS
- `services/checkout.py::charge_once` is the only charge path. WHY: double-charge
  incident, see DECISIONS.
## CONSUMERS
- `api/routes/orders.py::charge_once` declared: services/checkout.py
## DECISIONS
- Charges go through the gateway wrapper, never the SDK directly.
  WHY: retries double-charged when two paths existed. POINTER: ADR-007.
- REJECTED: queue-based charging. WHY: ordering guarantees cost more than the
  latency it saved. POINTER: PR #212 discussion.
## KNOWN TRAPS
- The seed script rewrites fixtures/orders.json on every run - never hand-edit it.
```

## The two rules (verbatim, into the target repo's index section)

1. Before modifying a subsystem that has a card, OPEN THE CARD.
2. A unit that changes a contract, invariant, or decision UPDATES THE CARD IN THE SAME COMMIT.
   A decision not written where the next session will look is a decision that will be re-made.

## The index (into the repo's auto-loaded CLAUDE.md)

20 lines max: a `## CARDS` heading, the two rules, then one line per card
(`- cards/<name>.md - <one-sentence scope>`). The index ALWAYS loads; cards load on demand.
That asymmetry is the token model - an index plus 2-3 relevant cards costs a few thousand
tokens per session, one avoided re-derivation saves 10-50x that. Never inline card content
into the index.

## SCAFFOLD (first run in a repo)

1. **Recon first, ask second.** `git status` and `git diff` before anything - uncommitted work
   is the freshest decision record, so capture its WHY in the relevant cards before the session
   that made it forgets. Then map entry points, the 5-10 real subsystems, existing docs and ADR
   conventions, test conventions. Cards COMPLEMENT an existing ADR log: they summarize and
   point, never duplicate. Never revert, stash, or clobber anything you found in flight.
2. **Write 5-10 cards** seeded from: existing docs, commit messages on the most-touched files,
   TODO / HACK / WARNING comments, and the uncommitted diff. Do not invent rationale - flag it.
3. **Add the index section** to the repo's CLAUDE.md (create the file if absent, append if not -
   never overwrite).
4. **Copy `card_check.py`** (it sits next to this SKILL.md) into the repo's tools directory and
   wire it into whatever already runs routinely - CI, the test suite, pre-commit, a make target.
   The checker must live IN the repo, versioned with the code it checks - never referenced back
   into the plugin.
5. **Prove the checker can fail** (mandatory - a checker only ever seen passing is not known to
   work): add a temporary card citing a nonexistent symbol, run the checker, require a nonzero
   exit naming that card and the dead citation, then delete the specimen and confirm green.
   Record the red run's output in the commit message.
6. **Commit with explicit paths.** Never a blanket add. Never push unless the operator says so.

**Exit condition:** 5-10 cards with every citation resolving - index in the auto-loaded doc -
checker green AND its red control demonstrated - pre-existing uncommitted work intact - report
lists the cards, both checker runs, and every "WHY: unrecorded" flag as an open question.

## MAINTAIN (every landing)

Rule 2 above, enforced at the same moment as the rest of the ship checklist: if the change
touched a carded subsystem's contract, invariant, or decision, the card updates in the same
commit. With `/pwnfactor:run`, that is an Integrate-phase step; with `/pwnfactor:gg`, a diff
that changes carded behavior with no card update is a legitimate review finding.

**When the checker reds on a rename you did not make:** the tree is the authority - fix the
CARD. And read the card while you are in there: the red is also a signal that a contract may
have actually moved, which is exactly the conversation the card exists to force.
