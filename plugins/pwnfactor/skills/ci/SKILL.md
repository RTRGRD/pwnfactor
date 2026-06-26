---
name: ci
description: Sets up CI/CD for this repo end to end - generates GitHub Actions tailored to the repo's real test/lint/typecheck commands (from the orchestration profile), an actor-gated @claude handler, and a weekly security scan; walks the human through the secret + org-permission + tag steps (automating via the gh CLI where possible); and verifies the first run goes green. Use when the user wants to set up CI, wire GitHub Actions, "turn on CI", asks how to get CI running, or runs /pwnfactor:ci.
---

# /pwnfactor:ci - set up CI, end to end

> **Say this first:** "`/pwnfactor:ci` wires GitHub Actions for this repo - tests/lint tailored to your real commands, an `@claude` handler, and a weekly security scan - then walks you through the human steps and confirms the first run is green."

**CI in plain English:** an always-on referee that runs your checks on GitHub's servers every push/PR, so a broken test or type error is caught *on the PR, before merge* - not later in main. This skill stages it, **tailors it to THIS repo's actual commands** (generic auto-detect isn't enough), automates what `gh` can, and doesn't call it "on" until it's seen green.

```
CI setup:
- [ ] 0. Prereqs (GitHub remote, gh auth, the profile's commands)
- [ ] 1. Generate repo-tailored workflows (ci / claude / security)
- [ ] 2. Human steps (secret · org permission · pinned tag) - automate via gh
- [ ] 3. Verify the first run is GREEN
- [ ] 4. Report (what's wired, what's left, the cadence)
```

## 0. Prereqs
- **GitHub remote** (`git remote -v`). No GitHub → CI is GitHub-Actions-specific; skip it and run checks locally.
- **`gh` authenticated** (`gh auth status`) - lets this skill check secrets/permissions/runs *for* you. Without it, you'll do the dashboard steps by hand (give exact menu paths).
- **The profile's commands** - read `.claude/orchestration-profile.md` (its *Test / lint / typecheck* + *CI* sections). No profile? Run `/pwnfactor:boot` first, or detect the commands and ask the user to confirm.

## 1. Generate repo-tailored workflows (don't ship generic)
Write into `.github/workflows/` (show the diffs; write only on approval; **merge, never overwrite** an existing workflow):
- **`ci.yml`** - runs the repo's **actual** commands per component (server `pytest`/`ruff`, web `tsc --noEmit`/`vitest`/`build`, contract-parity tests, sidecar tests...), pulled from the profile. Use the reusable `harness-ci.yml` with `with:` command inputs, or inline a tailored job. **Honor known gotchas from the profile** - a flaky/hanging suite gets routed to its documented **stable subset** (and an issue to fix it), so it never hangs CI.
- **`claude.yml`** - the on-demand `@claude` handler, **gated to trusted actors** (`OWNER`/`MEMBER`/`COLLABORATOR`), least-privilege permissions.
- **`security.yml`** - a **weekly scheduled** `pip-audit` + Syft/Grype dependency scan (the `sweep`'s dependency teeth, automated - informational, the real GO/NO-GO stays `/pwnfactor:sweep` at prod).

## 2. The human steps (automate via gh where possible - the agent never handles the key value)
1. **`ANTHROPIC_API_KEY` secret** - `gh secret list`. Missing? The user sets it: Settings → Secrets and variables → Actions, or `gh secret set ANTHROPIC_API_KEY`. The `@claude` job no-ops without it (the test job needs no secret - it's free).
2. **Allow the reusable workflow** (if `ci.yml` calls the org's) - check repo/org Actions settings (`gh api repos/{owner}/{repo}/actions/permissions`); if workflows from `<your-org>/<your-repo>` aren't allowed, the user enables it (Settings → Actions → General → "Allow ... and reusable workflows").
3. **Pin the ref** - confirm `ci.yml`'s `uses: ...@<tag>` points at a **real tag/SHA you maintain** (the tag exists: `git ls-remote --tags`), not a floating branch.

## 3. Verify it actually fires
Commit the workflows (or open a throwaway test PR). Then confirm with `gh run list` / `gh run view`. Red? Read the failure (`gh run view --log-failed`), fix, re-run. **Do not declare CI "on" until you've seen a green run** - staged-but-unverified is not done.

## 4. Report
What's wired (the workflows + their real commands), what the human still must do, the first run's status, and the cadence (every push/PR + weekly security). Call out any known-flaky tests you routed around and the issue tracking the fix.

## Notes
- **Repo-specifics live in the profile, not here** - this skill stays generic and reads them, so it ports to any repo.
- Re-run anytime to re-tailor after the profile's commands change.
- Full template details + the actor-gate rationale: `../../ci/README.md`.
