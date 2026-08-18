#!/usr/bin/env python3
"""card_check.py -- staleness checker for SYSTEM CARDS. Repo-agnostic template.

Copy into the target repo (conventionally tools/card_check.py). Exit 0 = every
card valid; exit 1 = failures, each printed with card, line, and reason.

Checks, per card in cards/*.md:
  1. SCHEMA   -- all five sections present (CONTRACT, INVARIANTS, CONSUMERS,
                 DECISIONS, KNOWN TRAPS).
  2. CITATION -- every `path::symbol` resolves: path exists in the tree AND the
                 symbol string appears in that file.
  3. CONSUMERS-- each CONSUMERS citation's symbol is additionally required to
                 appear in the CITING file named, which must differ from the
                 file that DECLARES it when a declarer is named -- consumption,
                 not existence.

RED CONTROL (run this whenever the checker itself changes): add a temp card
citing a nonexistent symbol; this script MUST exit 1 naming it. A checker only
ever seen passing is not known to work.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent   # repo root; adjust if moved
CARDS = ROOT / "cards"
REQUIRED = ["CONTRACT", "INVARIANTS", "CONSUMERS", "DECISIONS", "KNOWN TRAPS"]
CITE = re.compile(r"`([^`\s:]+(?:/[^`\s:]+)*\.[A-Za-z0-9_]+)::([A-Za-z0-9_.]+)`")

def fail(msgs, card, line_no, msg):
    msgs.append(f"  {card.name}:{line_no}: {msg}")

def main() -> int:
    if not CARDS.is_dir():
        print(f"card_check: no cards/ directory at {CARDS}")
        return 1
    cards = sorted(CARDS.glob("*.md"))
    if not cards:
        print("card_check: cards/ exists but holds no cards -- vacuous pass refused")
        return 1
    errors: list[str] = []
    checked_citations = 0
    for card in cards:
        text = card.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        # 1. schema
        for section in REQUIRED:
            if not re.search(rf"^##\s+{re.escape(section)}\b", text, re.MULTILINE):
                fail(errors, card, 0, f"missing required section '## {section}'")
        # 2 + 3. citations, with section awareness for CONSUMERS
        current = ""
        for i, line in enumerate(lines, 1):
            m_sec = re.match(r"^##\s+(.+?)\s*$", line)
            if m_sec:
                current = m_sec.group(1).upper()
            for m in CITE.finditer(line):
                checked_citations += 1
                rel, symbol = m.group(1), m.group(2)
                target = ROOT / rel
                if not target.is_file():
                    fail(errors, card, i, f"cites `{rel}::{symbol}` but {rel} does not exist")
                    continue
                body = target.read_text(encoding="utf-8", errors="replace")
                if symbol not in body:
                    fail(errors, card, i, f"cites `{rel}::{symbol}` but '{symbol}' not found in {rel}")
                    continue
                if current.startswith("CONSUMERS"):
                    # consumption: the named file must reference the symbol; if a
                    # `declared: path` annotation is on the line, it must differ.
                    decl = re.search(r"declared:\s*(\S+)", line)
                    if decl and Path(decl.group(1)).as_posix() == Path(rel).as_posix():
                        fail(errors, card, i,
                             f"CONSUMERS entry `{rel}::{symbol}` cites the declaring file itself -- existence, not consumption")
    if checked_citations == 0:
        errors.append("  (global): zero citations found across all cards -- a card with no "
                      "`path::symbol` citations cannot go stale and therefore proves nothing")
    if errors:
        print(f"card_check: FAIL -- {len(errors)} problem(s) across {len(cards)} card(s):")
        print("\n".join(errors))
        return 1
    print(f"card_check: OK -- {len(cards)} card(s), {checked_citations} citation(s) all resolve")
    return 0

if __name__ == "__main__":
    sys.exit(main())
