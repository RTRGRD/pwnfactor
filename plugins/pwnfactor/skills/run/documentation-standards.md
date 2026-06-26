# Documentation standards (token-efficient)

Docs and comments share the context window with everything else. Every line must earn its tokens. Applies to `CLAUDE.md`, skill files, code comments, and feature docs.

## Rules

1. **Assume the reader (human or model) is already competent.** Don't explain what a PDF, a JWT, or a foreign key is. Cut any sentence a smart engineer already knows. The 50-token version beats the 150-token version.
2. **Progressive disclosure over monoliths.** Keep the entry doc (CLAUDE.md, SKILL.md) lean; point to detail loaded on demand. SKILL.md bodies under ~500 lines; references one level deep.
3. **Table of contents on anything over ~100 lines** so a partial read still sees the full scope.
4. **No time-sensitive phrasing.** Not "after August 2025, use v2." Put superseded guidance in a collapsed "old patterns" section.
5. **One term per concept, used consistently.** Pick "checkpoint" and never drift to "snapshot" / "savepoint."
6. **Lightweight identifiers, not inlined corpuses.** Store a path, URL, or query and let the reader fetch the body — don't paste a whole file.
7. **Static facts embed; volatile detail loads just-in-time.** Stable conventions go in CLAUDE.md; fast-changing specifics live in retrievable docs.
8. **Show, don't lecture.** One canonical example beats three paragraphs. Use input→output pairs for formats.
9. **Comments explain *why*, not *what*.** The code already says what. Comment the non-obvious decision, the gotcha, the past incident.
10. **Match the surrounding density.** Don't add a header comment to a file that has none; mirror the codebase's existing style.

## Why
Context is a finite public good (Anthropic, *Effective context engineering for AI agents*). The target is "the smallest set of high-signal tokens that maximize the likelihood of the desired outcome." Verbose docs don't just cost tokens — they bury the signal that matters.
