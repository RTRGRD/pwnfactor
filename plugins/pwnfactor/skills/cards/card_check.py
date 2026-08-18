#!/usr/bin/env python3
"""card_check.py -- staleness checker for SYSTEM CARDS. Repo-agnostic template.

HONEST LIMIT: checks are TEXTUAL. A deleted file or renamed symbol goes red; a symbol whose
MEANING changed while keeping its name does not. Semantic staleness is caught by the same-
commit write-back rule, not by this script. Do not oversell it.

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
                target = (ROOT / rel).resolve()
                rootr = ROOT.resolve()
                if rootr not in target.parents and target != rootr:
                    fail(errors, card, i, f"cites `{rel}` which escapes the repository root")
                    continue
                if not target.is_file():
                    fail(errors, card, i, f"cites `{rel}::{symbol}` but {rel} does not exist")
                    continue
                body = target.read_text(encoding="utf-8", errors="replace")
                if symbol not in body:
                    fail(errors, card, i, f"cites `{rel}::{symbol}` but '{symbol}' not found in {rel}")
                    continue
                if current.startswith("CONSUMERS"):
                    # consumption: the named file must reference the symbol; if a
                    # `declared: path` annotation is on the line, the declarer must EXIST,
                    # CONTAIN the symbol, and DIFFER from the citing file. A declared path
                    # that is wrong or absent made this check theater (codex F21).
                    decl = re.search(r"declared:\s*(\S+)", line)
                    if decl:
                        dpath = decl.group(1)
                        if Path(dpath).as_posix() == Path(rel).as_posix():
                            fail(errors, card, i,
                                 f"CONSUMERS entry `{rel}::{symbol}` cites the declaring file itself -- existence, not consumption")
                        else:
                            dfull = ROOT / dpath
                            if not dfull.is_file():
                                fail(errors, card, i, f"declared: {dpath} does not exist")
                            elif symbol not in dfull.read_text(encoding="utf-8", errors="replace"):
                                fail(errors, card, i, f"declared: {dpath} does not contain '{symbol}'")
    # per-card floor (codex F22): the old global rule let one cited card carry N uncited ones.
    SECTION_RE = re.compile(r"^##\s+(\S[^\r\n]*)", re.MULTILINE)
    for card in cards:
        txt = card.read_text(encoding="utf-8", errors="replace")
        if not CITE.search(txt):
            fail(errors, card, 0, "card has no `path::symbol` citations -- it cannot go stale "
                                  "and therefore proves nothing")
        # empty required section = a heading with nothing before the next heading: a lie slot
        heads = list(SECTION_RE.finditer(txt))
        for k, h in enumerate(heads):
            body_end = heads[k + 1].start() if k + 1 < len(heads) else len(txt)
            sec_name = h.group(1).strip().upper()
            if any(sec_name.startswith(r) for r in REQUIRED):
                if not txt[h.end():body_end].strip():
                    fail(errors, card, 0, f"section '## {h.group(1).strip()}' is empty")
    if checked_citations == 0:
        errors.append("  (global): zero citations found across all cards")
    if errors:
        print(f"card_check: FAIL -- {len(errors)} problem(s) across {len(cards)} card(s):")
        print("\n".join(errors))
        return 1
    print(f"card_check: OK -- {len(cards)} card(s), {checked_citations} citation(s) all resolve")
    return 0

if __name__ == "__main__":
    sys.exit(main())
