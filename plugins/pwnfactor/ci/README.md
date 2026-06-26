# CI for the engineering harness

Two layers, matching the harness's **always-on tests + on-demand AI** model:

1. **Always-on checks** (free, no secrets) - every push/PR runs tests/lint/typecheck via a **central reusable workflow** hosted in the harness repo (`.github/workflows/harness-ci.yml`). Each project calls it in one line, so the CI logic is maintained once for the whole org and never drifts per-repo.
2. **On-demand AI review** (`@claude`) - comment `@claude ...` on a PR/issue and `anthropics/claude-code-action` responds. Deliberate (not auto-on-every-PR), so cost stays controlled. Needs an `ANTHROPIC_API_KEY` secret.

## Onboard a repo

**Easiest:** run **`/pwnfactor:ci`** - it tailors `ci.yml` to your repo's real commands (from `.claude/orchestration-profile.md`), drops in `claude.yml` + `security.yml`, walks you through the steps below via `gh`, and verifies the first run is green.

**Manual:** copy three files into the target repo's `.github/workflows/`:

- `ci.yml` - calls the reusable workflow; fill its `with:` commands from your profile (or leave blank to auto-detect).
- `claude.yml` - the actor-gated `@claude` handler.
- `security.yml` - the weekly dependency scan.

Then:

1. Add repo/org secret **`ANTHROPIC_API_KEY`** (Settings → Secrets and variables → Actions).
2. Allow the reusable workflow at the org level (Settings → Actions → General → "Allow ... and reusable workflows", or allow-list `<your-org>/<your-repo>`).
3. Pin `ci.yml`'s `uses: ...@v0.1.1` to a tag or commit SHA - don't float on a branch (supply-chain best practice).

That's it: org-standard CI with no copied logic to drift.

## How it ties to the harness

- The reusable workflow is the **mechanical gate** (tests/lint/typecheck) - the cheap first layer the review panel assumes is already green.
- The harness repo CIs **itself**: `validate.yml` runs `scripts/validate_plugin.py` on every push (JSON valid, skills have frontmatter, `SKILL.md` ≤ 500 lines).
- `harness-ci.yml` runs your **real commands** when `ci.yml` passes them via `with:` (`setup-cmd`/`lint-cmd`/`typecheck-cmd`/`test-cmd`) - `/pwnfactor:ci` fills these from the profile, injection-safe via `env:`. With no inputs it falls back to auto-detecting Node/pnpm, Python, and Rust. `security.yml` adds a weekly `pip-audit` + Syft/Grype scan.

## Advanced: run the review panel inside CI

Add `/plugin marketplace add <your-org>/<your-repo>` + `/plugin install codex@openai-codex` steps before the action and prompt `@claude` to run `/pwnfactor:gg`. Heavier and uses more tokens; most teams run the panel **locally** before pushing and keep CI to tests + on-demand `@claude`.

## Sources
- Reusable workflows - https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations
- Claude Code GitHub Actions - https://code.claude.com/docs/en/github-actions

## Security: gate the @claude handler

`claude.yml` runs on `@claude` comments and is **gated to trusted actors** (`OWNER` / `MEMBER` / `COLLABORATOR`) via `github.event.comment.author_association`. Without that gate, any commenter on a public/forkable repo could trigger a write-scoped, key-bearing run via prompt injection. **Keep the gate**, and trim the `permissions:` block to the minimum your usage needs (start `contents: read` unless the action pushes fixes).
