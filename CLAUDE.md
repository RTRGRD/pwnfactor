# CLAUDE.md - pwnfactor

**pwnfactor** is an agnostic agentic-engineering harness shipped as a Claude Code plugin: a feature
lifecycle (`run`), deliberate subagent orchestration (`swarm`), a risk-routed review panel (`gg`), a
ground-truth validation gate (`validate`), a read-only security sweep (`sweep`), and onboarding (`boot`).
This file is for agents *developing the plugin itself*, not for end users of it.

## Rule #1: stay agnostic (this is the whole point)

pwnfactor is project-neutral by design - it was extracted from a private app and scrubbed clean. Never
reintroduce anything tied to that origin or any other real project.

- No real project / product / company names in skills, docs, or examples. The ONLY allowed real
  identifiers are the public ones: `RTRGRD/pwnfactor` (install path), the `RTRGRD` org, `RTRGRD LLC`
  (copyright), `Scott Leppelman` (maintainer), and `rtrgrd.sh` (homepage).
- No real hostnames, IPs, device/lab names, internal file paths, or proprietary architecture.
- Worked examples use the fictional **Webcart** e-commerce SaaS (`skills/boot/example-webcart.profile.md`).
  New examples stay fictional or extend Webcart - never model one on a real codebase.
- `skills/sweep/config/security-audit.example.env` stays empty placeholders only.

Before adding any identifier, grep the repo and confirm it is not a real-world name.

## Rule #2: write like a person, not an AI

The docs were deliberately stripped of AI-tell punctuation - they should not read as machine-generated.

- No em-dashes, en-dashes, or ellipsis characters. Use ` - ` (spaced hyphen) and `...`.
- No smart quotes, no non-breaking spaces.
- Plain, direct, concrete prose. Skip the marketing cadence.

A search for U+2014 / U+2013 / U+2026 across the repo should return zero hits.

## Repo facts

- **Home:** github.com/RTRGRD/pwnfactor - owned by the RTRGRD org (the LLC), maintained by Scott Leppelman.
- **License:** MIT (`LICENSE`, (c) RTRGRD LLC). The harness is open source - keep it that way.
- **Line endings:** LF, pinned by `.gitattributes` (`* text=auto eol=lf`). A Windows working tree may show
  CRLF; git normalizes to LF on add. That is expected, not a ghost to chase.

## Plugin structure (violating these breaks the plugin)

- Only `plugin.json` goes in `.claude-plugin/`. Skills, agents, and hooks sit at the plugin root
  (`plugins/pwnfactor/skills`, `/agents`, `/hooks`).
- The repo is a marketplace via `marketplace.json`, kept as two byte-identical copies (root +
  `.claude-plugin/`). Change both together.
- Each `SKILL.md`: under 500 lines, a third-person triggered `description` in its frontmatter, references
  one level deep.
- Agents declare `name` + `description` (+ optional `tools` / `model`); they do NOT support
  `hooks` / `mcpServers` / `permissionMode`.
- Bump `plugin.json` `version` to ship a change to installed users - no bump means no propagation. It is
  pinned on purpose.

## Before every commit

- Run `python scripts/validate_plugin.py` and keep it green (manifest, structure, SKILL.md descriptions,
  cross-references). `claude plugin validate` is the official equivalent once the CLI is handy.
- One logical change per commit; conventional messages (`feat(scope):`, `fix:`, `docs:`, `chore:`).
- Stage explicit paths. The repo is LF-clean, so there are no CRLF ghosts to filter.
- No `Co-Authored-By` or "Generated with" trailers.

## Dogfood where it helps

It is an engineering harness, so use it on itself where it earns its keep: `/pwnfactor:gg` (the review
panel) on a non-trivial diff, `/pwnfactor:run` for a real change. Not needed for a one-line doc fix.

## Reference

- `README.md` - what the plugin is + install/update flow.
- `BUILD-YOUR-OWN-HARNESS.md` - how to port the method into a different repo as a bespoke harness.
- `plugins/pwnfactor/skills/*/SKILL.md` - the skills themselves.
