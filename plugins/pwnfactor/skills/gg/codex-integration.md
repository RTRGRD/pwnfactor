# Codex cross-model review — integration & best practices

The panel's fourth reviewer is **Codex (OpenAI GPT-5.x)** via the official **`openai/codex-plugin-cc`** plugin. A different model family doesn't share Claude's blind spots, so it catches a different class of bug — e.g. a subtle rollback-model or idempotency error a same-model panel can wave through.

## Install & setup

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

Prereqs: Node ≥ 18.18, the Codex CLI (`npm install -g @openai/codex`), auth via `!codex login` (ChatGPT subscription or OpenAI API key). Usage counts against your Codex limits.

## ⚠️ Leave the Stop-hook review-gate OFF

The plugin can install a Stop hook that auto-runs a Codex review whenever Claude tries to stop and blocks the stop until issues are addressed. OpenAI's docs warn it "can create a long-running Claude/Codex loop and drain usage limits quickly." It conflicts with this harness's *deliberate, once-per-feature* model. **Keep it disabled** (manage via `/codex:setup`); the panel invokes Codex explicitly instead.

## How the panel uses Codex

- **Once per feature**, on the assembled whole diff, AFTER mechanical checks (tests/lint/typecheck) and the three Claude reviewers. Don't hammer it — rate limits are real.
- **Risk-routed mode:**
  - routine → `/codex:review` (auto-detects the diff; `--base <merge-base>` for a branch).
  - high-risk → `/codex:adversarial-review`, framed as *"assume it's broken; hunt auth, data-loss, rollback, races, dependencies, version-skew, observability."*
- **Scale by size** (industry heuristic): ~1 reviewer for <50 LOC, 2 for 50–200, 3 for 200+. Codex is the cross-model reviewer layered on top of the Claude panel.
- **Read only the final result** (`/codex:result`); don't tail the run.
- **Verify load-bearing claims against source.** Codex findings are leads, not gospel — but when it cites `file:line`, check it. It earned trust here; the rule still stands.

## Fallback chain

official plugin (`/codex:*`) → the global `codex` CLI skill (headless, "no window") → skip silently (solo-mode friendly). Never block the panel on Codex's availability.

## Why cross-model

A model that writes code reviews it through the same lens that produced it — grading its own homework, with sycophancy bias compounding. A different provider breaks that overlap and is harder to fool with a single adversarial trigger.

## Sources
- OpenAI Codex plugin — https://github.com/openai/codex-plugin-cc
- OpenAI Codex best practices — https://developers.openai.com/codex/learn/best-practices
- Cross-provider review — https://www.mindstudio.ai/blog/openai-codex-plugin-claude-code-cross-provider-review
