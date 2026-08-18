---
name: help
description: Shows the full pwnfactor command loadout - every skill, what it does, when to reach for it, and how the pieces fit into one lifecycle. Use when a user runs /pwnfactor:help, types pwnfactor help, asks what pwnfactor can do, which command to use, or how the skills fit together.
---

# /pwnfactor:help - the loadout screen

Print this reference, then answer any follow-up from the linked skill files - do not improvise
answers this table already gives.

## The commands

| command | what it does | when |
|---|---|---|
| `/pwnfactor:boot` | one-time repo setup: profile, rails, CI, Codex, cards offer, live demo review | once per project, first |
| `/pwnfactor:run` | the lifecycle spine: Frame -> Plan -> Build -> Verify -> Integrate | every non-trivial change |
| `/pwnfactor:swarm` | deliberate subagent orchestration for a big feature (topology, effort, isolation) | big features, by choice |
| `/pwnfactor:gg` | risk-routed review panel: code-review + simplifier + security + optional Codex | before you merge |
| `/pwnfactor:validate` | prove it against a ground-truth oracle, not just a green suite | after gg, before ship |
| `/pwnfactor:sweep` | read-only pre-prod security battery, GO / NO-GO | before prod pushes / big builds |
| `/pwnfactor:ci` | wire + verify CI/CD (tailored tests, actor-gated @claude, weekly scan) | setting up or fixing CI |
| `/pwnfactor:cards` | system cards: per-subsystem contracts + decisions with the WHY, checker-enforced | scaffold once, then per landing |
| `/pwnfactor:help` | this screen | whenever |

## How they fit (the shape of one change)

```
boot (once)  ->  cards scaffold (once)
                       |
     run: Frame -> Plan -> Build -> Verify -> Integrate
                    |        |         |          |
                    |     swarm?      gg       card write-back
                    |   (big only)     |       + doc wrap-up
                    |               validate      |
                    |                  |        sweep? (prod)
                    +------------------+----------+
```

- **run** is the default path; it calls the others at the right moments.
- **swarm** only when the feature genuinely splits; one agent in one loop is the default.
- **gg** routes depth by risk: SKIP / SOLO / PANEL / ADVERSARIAL. Small diffs stay cheap.
- **validate** answers "did the REAL thing accept it" - a green suite is a claim, not proof.
- **cards** answers "will the NEXT session know why" - update the touched card in the same
  commit at Integrate; `tools/card_check.py` reds if a card goes stale.
- **sweep** is offered, never auto-run; the operator decides.

## Two-line answers to the usual questions

- **Docs wrap-up vs cards?** Wrap-up (in `run` Integrate) is per-change: update whatever
  documents assert the changed facts. Cards are per-subsystem: a fixed, checker-enforced home
  for contracts and decisions, so wrap-up has a deterministic target instead of a scavenger hunt.
- **Does every change update a card?** No. Only changes that alter a carded subsystem's
  contract, invariant, decision, or known trap. Cards are contracts, not a changelog.
- **Where do the first cards come from?** `/pwnfactor:cards` scaffolds them FROM the repo:
  recon of structure, docs, commit history, TODO/HACK comments, and any uncommitted diff.
  It never invents rationale - an unsourced WHY is flagged, not fabricated.
- **What if the checker reds on a rename I did not make?** The tree is the authority: fix the
  card, and read it while you are there - the red may mean a contract actually moved.

Full detail: each row's skill file (`skills/<name>/SKILL.md`), one level down.
