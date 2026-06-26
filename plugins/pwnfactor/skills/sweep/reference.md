# Portable `/security-audit` skill for Claude Code

A self-contained, read-only **pre-release security battery** you can drop into any Claude Code project.
It runs a stack-aware static scan + supply-chain CVE/SBOM + secret scan + adversarial review, and (for a
shipping binary) a local-AV-gated malware-sandbox reputation check - then writes one consolidated report.

This is a **sanitized, app-agnostic** version of an internal tool. Nothing about the originating app
remains: no project names, paths, baselines, credentials, or app-specific findings. It's safe to hand off.

---

## What's in the box

The `sweep` skill bundles everything. You do not copy or install any files:

```
skills/sweep/
├── SKILL.md                        the /pwnfactor:sweep skill (when to offer it, how to run)
├── reference.md                    this file (prereqs, parameters, the FP ledger)
├── bin/
│   └── run-security-audit.ps1      the engine (PowerShell 7+, cross-platform-guarded)
└── config/
    └── security-audit.example.env  optional API-key template for the sandbox step
```

The companion review agent ships at the plugin root as `agents/security-auditor.md`.

---

## Setup (the plugin already bundles the engine)

Nothing to copy. Once the pwnfactor plugin is installed, `/pwnfactor:sweep` runs the bundled engine for
you. Two things make a run complete:

1. Install the prerequisites below (at minimum `pwsh`; add Syft + Grype for the CVE/SBOM backbone).
2. Add the audit output + local keys to your repo's `.gitignore` (`/pwnfactor:boot` does this for you):

```
.security-audit/         # audit output (timestamped reports)
.security-audit.env      # local sandbox API keys (secrets)
```

The skill invokes `${CLAUDE_SKILL_DIR}/bin/run-security-audit.ps1 -RepoRoot .` so it audits your repo,
not the plugin. You can also run that script directly (see Usage below).

---

## Prerequisites (install what you have; every step degrades gracefully if a tool is missing)

| Tool | Needed for | Install |
|---|---|---|
| **PowerShell 7+** (`pwsh`) | the harness itself (the one hard requirement) | `winget install Microsoft.PowerShell` · `brew install powershell` · distro pkg |
| **Node + npm** | npm-audit + `npx` electronegativity (Node/Electron apps) | nodejs.org / nvm |
| **Syft + Grype** | the cross-stack SBOM + CVE backbone | `winget install Anchore.Syft Anchore.Grype` · `brew install syft grype` · or drop binaries in `~/.security-audit-tools/` |
| **semgrep** | universal SAST for non-Electron stacks | `pip install semgrep` · `brew install semgrep` |
| **codex** CLI | `-Codex` adversarial review (optional) | per your Codex setup; if absent, a ready-to-run prompt is written instead |
| **ClamAV / CAPA** | extra local AV engines, RUN #2 (optional) | `winget install Cisco.ClamAV` (+`freshclam`) · CAPA: unzip `capa.exe` into `~/.security-audit-tools/` |
| Windows Defender | local AV floor, RUN #2 (Windows) | built-in; auto-found |

Per-stack static-analysis tools (cargo-audit, govulncheck, bandit, ...) are listed in the skill's
**"Recommended static-analysis tool by stack"** table - install the one matching the target app.

---

## Usage

The skill runs the engine for you; these examples show the engine's own interface (the parameters are
the same whether the skill invokes it or you run the bundled script directly).

```powershell
# RUN #1 - baseline source-level sweep (no build needed)
pwsh -File bin/run-security-audit.ps1

# RUN #1 + adversarial review
pwsh -File bin/run-security-audit.ps1 -Codex

# RUN #2 - launch gate on a release candidate (binary reputation + packaged-dir CVE scan)
pwsh -File bin/run-security-audit.ps1 -RunNumber 2 `
  -BinaryPath "release/App Setup 1.0.0.exe" -ReleaseDir "release/win-unpacked"

# RUN #2 for a CLOSED-SOURCE app - local AV only, nothing uploaded to a public sandbox
pwsh -File bin/run-security-audit.ps1 -RunNumber 2 -BinaryPath "dist/App.AppImage" -LocalAVOnly

# Force a specific static tool / accept a known CVE baseline
pwsh -File bin/run-security-audit.ps1 -StaticTool semgrep -BaselineHigh 2
```

Output → `.security-audit/<timestamp>/REPORT.md` (+ raw tool logs alongside). Exit code is non-zero if
any **blocker** fires, so RUN #2 can gate a release script.

### Key parameters

| Param | Default | Purpose |
|---|---|---|
| `-RunNumber 1\|2` | 1 | 1 = source sweep · 2 = launch gate (adds release scan + local AV + sandbox) |
| `-StaticTool auto\|electronegativity\|semgrep\|none` | auto | auto = detect stack; Electron auto-runs, others are recommended + asked |
| `-BinaryPath <file>` | - | shipping artifact for the local AV pre-scan + sandbox reputation (RUN #2) |
| `-ReleaseDir <dir>` | - | packaged app dir for the extra Grype scan (RUN #2) |
| `-BaselineCritical / -BaselineHigh` | 0 / 0 | accepted npm-audit crit/high before it's a blocker |
| `-LocalAVOnly` | off | RUN #2: local AV only, never upload to a public sandbox |
| `-SkipSandbox` | off | skip the public submit (local pre-scan still runs) |
| `-EnvFile <path>` | `.security-audit.env` | dotenv with `VT_API_KEY`/`HA_API_KEY`/`JOE_API_KEY` |
| `-ExcludeSecretPattern <regex>` | - | exclude public-by-design tokens (e.g. a public web/client API key) from the secret scan |
| `-ProjectName` / `-OutputDir` / `-ToolsDir` / `-ScanPaths` | auto | report label / output dir / tool-discovery dir / secret-scan roots |

---

## How it's stack-aware (the one bit that needs the agent)

Step 1 detects whether the app is **Electron / Tauri / Rust / Go / Python / Node-web** and prints the
recommended static-analysis tool. It **auto-runs a scanner only for Electron** (electronegativity). For
any other stack it deliberately does *not* run a scanner - it emits a recommendation and a `[WARN]`
addressed to the agent. The agent should then **surface the recommendation and ask the user** whether to
install + run that tool, run `semgrep`, or skip. Full matrix + guidance is in the skill file.

Everything else - SBOM, CVE scan, secret scan, adversarial review, binary reputation - is stack-agnostic
and runs the same way everywhere.

---

## Guarantees

- **Read-only.** Never commits, never deploys, never edits app source. All writes go under
  `.security-audit/`.
- **No external upload unless you ask for it** (RUN #2 + keys present + local AV passed). A locally
  flagged binary is never uploaded. Public sandbox free tiers publish the binary - use `-LocalAVOnly`
  for closed-source apps.
- **Secrets stay local.** Sandbox API keys are read from your env / local dotenv and sent only to their
  own vendor APIs.
