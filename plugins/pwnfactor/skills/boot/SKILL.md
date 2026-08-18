---
name: boot
description: Onboards a project onto the pwnfactor engineering harness - inspects the repo, interviews the user for what it can't infer, sets up the orchestration profile + CLAUDE.md gate contract + CI + Codex, lists the full command loadout, teaches CI/CD, and proves value on a real diff. Use when a user runs /pwnfactor:boot, asks to set up or onboard pwnfactor or the harness, or is getting started for the first time.
---

# /pwnfactor:boot - jack in 🕶️

> **Say this first:** "`/pwnfactor:boot` sets up pwnfactor in this repo - I'll scope your stack, build your safety profile + CI, show you the full command loadout, and run a live review so you see it work. You run this once per project."

> ` > ACCESS GRANTED_` Welcome to the construct, operator. This repo doesn't know it yet, but it's about to get **pwnfactored**.

Four phases. Keep it fun, keep it moving - and **translate every bit of slang into plain English right after**. We're here to teach, not just to flex. If the user looks lost, or it's a serious moment (a real security finding), drop the bit and be clear.

```
Boot sequence:
- [ ] 1. RECON       - scope the repo; ask only what you can't see
- [ ] 2. LOADOUT     - profile + rails + CI + Codex (your gear)
- [ ] 3. GIT GUD     - the full command loadout + how to use it
- [ ] 4. FIRST BLOOD - run the panel on a real diff
```

## 1. RECON (scope the target)
> *Recon = look before you leap. A good operator never walks into a room blind.*

**Inspect first** (don't ask what you can detect): stack (`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`), component layout, `.github/workflows/`, `git remote -v`, existing `CLAUDE.md` / `.claude/`.

**Then ask only the gaps,** one short round:
- **"Where are the landmines?"** - which surfaces need rails (auth, secrets, money, data/host-mutating, migrations). *(Plain English: this sets your risk tiers.)*
- **"Solo runner, or full squad? On GitHub?"** *(Decides whether we wire CI + the `@claude` co-op handler.)*
- **"What is the cheapest REAL thing that proves a change works?"** - a native runtime accept/reject, a staging URL, a query against the real store, a consumer call. *(This becomes `ground_truth_oracle:` in the profile - `/pwnfactor:validate` is dead weight without it, and it is NOT inferable from the repo.)*
- **Confirm** the stack + the test/lint/typecheck commands you detected.

## 2. LOADOUT (gear up - confirm each before writing)
> *Your loadout is the gear that keeps you alive. Don't deploy without it.*

- **Orchestration profile** → fill `orchestration-profile.template.md` (see `example-webcart.profile.md` for a worked one) from recon + answers; write to `.claude/orchestration-profile.md`. *(This is what makes the squad fight correctly in YOUR repo, not someone else's.)*
- **CLAUDE.md gate contract** → append (never overwrite): *"Any code-touching change runs `/pwnfactor:gg` before integrate and follows `/pwnfactor:swarm` isolation + rails. Data-/fleet-mutating work ships with dry-run + checkpoint + rollback. Before a production push or big build, OFFER `/pwnfactor:sweep` - the operator decides. `/pwnfactor:gg` writes `.pwnfactor/gate.json`, which pwnfactor's stop-hook verifies - it nudges if you stop with unreviewed code changes."*
- **Security armory** *(so `/pwnfactor:sweep` actually fires)* → detect the toolchain and walk the user through installing what's missing. **Two hard requirements: `python` 3 on PATH** (the stop-hook and the cards checker are Python - without it both fail open SILENTLY; macOS/Linux: brew or the distro package) **and `pwsh` (PowerShell 7+) for the sweep engine** → `winget install --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements` *(run elevated)*. Then the CVE backbone (**Syft + Grype**) and the per-stack scanner (Python `pip install pip-audit bandit` · Rust `cargo install cargo-audit cargo-geiger` · Electron `npx @doyensec/electronegativity` · Go `gosec`/`govulncheck`). **Offer to install the no-admin pieces yourself** - Syft/Grype binaries → `~/.security-audit-tools/` (the engine auto-discovers them), plus the pip tools. Full prereqs + per-stack matrix: `../sweep/reference.md`. *(No armory, no sweep - stock it before the first prod push.)*
- **CI/CD** *(if GitHub)* → run **`/pwnfactor:ci`** - it tailors the workflows to your repo's real commands (from the profile), wires the actor-gated `@claude` handler + a weekly security scan, walks you through the secret/permission/tag steps via `gh`, and **verifies the first run is green**. *(Always-on tests = auto-turrets on every PR; `@claude` = on-demand air support. See `../ci/SKILL.md`.)*
- **Codex co-op** → `/plugin install codex@openai-codex` + `/codex:setup`; **decline the Stop-hook gate** (it loops and drains your ammo). *(A second AI from a rival faction reviews your code - different model, sees what we can't. See `../gg/codex-integration.md`.)*
- **System cards** *(the save file)* -> offer **`/pwnfactor:cards`** - one card per subsystem carrying contracts, invariants, and decisions with the WHY, plus a staleness checker that reds when a card goes out of date. *(This is what stops future sessions from re-deriving or violating decisions the repo already made. See `../cards/SKILL.md`.)*

## 3. GIT GUD (the loadout - list it ALL)
> *Here's your full command list. Memorize it or perish... kidding. Mostly.*

| command | what it does | when |
|---|---|---|
| `/pwnfactor:run` | the lifecycle for any real change (Frame → Build → Verify → Ship) | every non-trivial change |
| `/pwnfactor:swarm` | fan out a squad of subagents for a big feature | big features (deliberate, not always-on) |
| `/pwnfactor:gg` | the review panel - 3 reviewers + Codex tear through your diff | before you merge |
| `/pwnfactor:validate` | prove it ACTUALLY works - check the change against a ground-truth oracle | after `gg`, before ship |
| `/pwnfactor:sweep` | pre-prod security sweep (secrets, CVEs, injection, rails) | before prod pushes / big builds |
| `/pwnfactor:ci` | wire + verify CI/CD (tailored tests, `@claude`, weekly security) | setting up / fixing CI |
| `/pwnfactor:cards` | system cards - a versioned decision layer so sessions stop forgetting the architecture | once to scaffold, then per landing |
| `/pwnfactor:boot` | this - set up a new repo | once per project |
| `/pwnfactor:help` | the loadout screen - every command, when, and how they fit | whenever you forget |

**Risk tiers:** routine vs **HIGH** (auth / secrets / migrations / mutating). HIGH = more thinking, Opus reviewers, and the panel goes adversarial.

## 4. FIRST BLOOD (prove it on real code)
> *Talk is cheap. Let's get a frag.*

Offer to run `/pwnfactor:gg` on a recent diff (`git diff HEAD~1`) so they see a real verdict on real code. **This is where pwnfactor earns the install** - don't skip it if there's a diff to review. Then offer to walk them through their first full `/pwnfactor:run`.

## GG (wrap)
Recap what you set up (profile path, `CLAUDE.md` additions, CI files, Codex status). One command to remember: **`/pwnfactor:run`** to start any change. Suggest committing `.claude/orchestration-profile.md` + the CI files. Sign off: *"You're jacked in, operator. Go pwn something."*

## Notes
- **Idempotent:** profile / contract / CI already there? Show the diff and ask before touching anything.
- **Solo mode:** no GitHub or no Codex? Skip those steps - the three Claude reviewers still have your six.
- **Educational > flashy:** every slang line gets a plain-English translation. The jokes are seasoning, not the meal.
