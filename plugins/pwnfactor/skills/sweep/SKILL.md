---
name: sweep
description: Pre-release/pre-prod security battery — a stack-aware static scan + supply-chain SBOM/CVE + secret scan + adversarial review, and (for a shipping binary) a local-AV-gated malware-sandbox reputation check, ending in a consolidated GO/NO-GO report. Read-only; never commits or deploys. Deliberate — the agent offers it before production pushes or big builds and the user decides. Use when the user asks for a security audit or sweep, before a release, or before deploying to production.
---

# /pwnfactor:sweep — pre-prod security battery

> **Say this first:** "`/pwnfactor:sweep` is the pre-prod security battery — stack-aware static scan, SBOM + CVE, secret scan, adversarial review, and (for a shipping binary) a malware-reputation check, ending in GO / NO-GO. Read-only. I offer it before production pushes or big builds; you decide."

A real, read-only security pass for the moments that matter — **before a release, a production push, or a big build.** It runs the bundled engine (`bin/run-security-audit.ps1`, PowerShell 7+, cross-platform) and writes everything under `.security-audit/<timestamp>/`. **Never commits, deploys, or edits source.**

**When to offer it — the agent ASKS, the user decides.** Two runs:
- **RUN #1 (baseline)** — early, source-level only (no build). Validates tooling, captures a findings baseline to diff against.
- **RUN #2 (launch gate)** — on the release-candidate build, after auth/payment/permission work. Adds the packaged-app CVE scan, the local-AV pre-scan, and the malware-sandbox reputation check. **This is the run that gates a production release.**

## How to run

```powershell
# RUN #1 — baseline source sweep (+ -Codex for the adversarial pass)
pwsh -File "${CLAUDE_SKILL_DIR}/bin/run-security-audit.ps1" -RepoRoot . -Codex

# RUN #2 — launch gate on a release candidate
pwsh -File "${CLAUDE_SKILL_DIR}/bin/run-security-audit.ps1" -RepoRoot . -RunNumber 2 `
  -BinaryPath "release/App Setup 1.0.0.exe" -ReleaseDir "release/win-unpacked" -Codex

# RUN #2 closed-source — local AV only, nothing uploaded to a public sandbox
pwsh -File "${CLAUDE_SKILL_DIR}/bin/run-security-audit.ps1" -RepoRoot . -RunNumber 2 -BinaryPath "dist/App.AppImage" -LocalAVOnly
```

Exit code is non-zero if a **blocker** fires (CVE drift above baseline, a local-AV detection, a missing RUN #2 input) — so it can gate a release script. `pwsh` is the one hard prerequisite; Syft / Grype / semgrep / codex enrich it and degrade gracefully if absent. **The full parameter table, prerequisites, the false-positive ledger, and the dependency-update policy are in `reference.md` — read it before the first run.**

## The one part that needs you (stack-aware static analysis)
The engine auto-runs a scanner only for **Electron** (electronegativity). For every other stack (Tauri / Rust / Go / Python / Node-web) it **detects the stack, prints the recommended tool, and emits a `[WARN]` to you.** When you see that WARN: **surface the detected stack + recommended tool and ASK the user** whether to (a) install + run it, (b) run `semgrep` (`-StaticTool semgrep`), or (c) skip. Don't silently skip; don't run electronegativity on a non-Electron app.

## Exploit reasoning (the part tools can't do)
Pair the engine's evidence (SBOM / CVE / secret / static) with the **`security-auditor`** agent — an OWASP-Top-10:2025, attacker-mindset reviewer. It supplies the exploit reasoning + triage the scanners can't: **a finding is only real when it's exploitable under the threat model** (untrusted input / compromised client / network MITM / malicious dependency). State the threat model per finding; separate exploitable bugs from defense-in-depth nits.

## Safety-rail check
For every destructive / irreversible / data- or fleet-mutating capability, confirm the project's rails exist **and fire** (per `.claude/orchestration-profile.md`): dry-run + checkpoint + rollback, plus a HITL gate before irreversible actions. A missing or unproven rail is a **NO-GO** for prod.

## Verdict
The engine writes `.security-audit/<timestamp>/REPORT.md` with `[BLOCKER]` / `[WARN]` / `[OK]` lines. Summarize it as a clear **GO / NO-GO**:
- **NO-GO** — any blocker (committed secret, CVE drift above baseline, local-AV detection, missing rail on a destructive op, an exploitable injection/authz finding).
- **GO with follow-ups** — warnings tracked, no blockers.
- **GO** — clean.

Report the verdict in chat and offer to fix the blockers (remediation is a separate, per-item-approved step).

## Hard rules
- **Read-only.** Never `git add`/`commit`/`push`, never deploy, never edit source. All writes go under `.security-audit/`.
- **Local pre-scan gates the public upload** — a locally-flagged binary is never sent to a public sandbox. Free sandbox tiers PUBLISH the binary; use `-LocalAVOnly` for closed-source apps.
- **Secrets stay local** — sandbox API keys (`config/security-audit.example.env` → `.security-audit.env`, gitignored) go only to their vendor APIs.
- **Onboarding** (`/pwnfactor:boot`) adds `.security-audit/` + `.security-audit.env` to the target repo's `.gitignore`.

`/pwnfactor:yomom` 💀 runs this exact battery — same engine, funnier name.
