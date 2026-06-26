# pwnfactor

Composable skills for building features with Claude Code agents, plus the subagents the review panel fans out to.

| Skill | Role | When |
|---|---|---|
| `boot` | Onboard a repo: profile + CLAUDE.md contract + CI + toolchain, then prove value | Once per project |
| `run` | Lifecycle spine: Frame → Plan → Build → Verify → Integrate | Any non-trivial change |
| `swarm` | The build loop: deliberate subagent fan-out | Substantial features worth the coordination cost |
| `gg` | The verify gate: risk-routed multi-agent review | After a feature, before merge |
| `ci` | Wire + verify CI/CD (tailored tests, `@claude`, weekly security) | Setting up or fixing CI |
| `sweep` / `yomom` | Pre-prod security battery → GO/NO-GO | Before a release / prod push |

Subagents (in `agents/`):

- `panel-code-review` — correctness / bugs / races / contract drift
- `panel-simplifier` — reuse / dead code / altitude (quality only, no bug hunting)
- `panel-security` — injection / authz / secrets / safety rails
- `security-auditor` — OWASP attacker-mindset reviewer (used by `sweep`)

## Design principles (baked in)

- **Deliberate, not always-on.** Orchestration is invoked by choice, scoped to the feature. This is not "ultracode."
- **Don't trust raw subagent output.** Every CRITICAL/HIGH finding is verified against the code before it counts (per Anthropic's multi-agent guidance).
- **Risk-routed cost.** Routine diffs get a Sonnet panel + regular Codex; high-risk diffs (auth, secrets, migrations, fleet-mutating) get an Opus panel + adversarial Codex.
- **Token-efficient docs.** Skills stay lean; detail lives in reference files loaded on demand. See `skills/run/documentation-standards.md`.
- **Solo-mode friendly.** Codex and any backend are optional; the panel degrades gracefully to the three Claude reviewers.
