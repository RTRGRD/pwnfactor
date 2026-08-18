#!/usr/bin/env python3
"""Validate the pwnfactor plugin structure. Exits non-zero on any problem.

Run locally or in CI (see .github/workflows/validate.yml):
    python scripts/validate_plugin.py
"""
import json
import re
import os
import glob
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors: list[str] = []


def check_json(path: str) -> None:
    try:
        with open(path, encoding="utf-8") as fh:
            json.load(fh)
    except Exception as e:  # noqa: BLE001 - report any parse failure
        errors.append(f"{path}: invalid JSON ({e})")


marketplace = os.path.join(ROOT, ".claude-plugin", "marketplace.json")
plugin = os.path.join(ROOT, "plugins", "pwnfactor", ".claude-plugin", "plugin.json")
for p in (marketplace, plugin):
    if not os.path.exists(p):
        errors.append(f"missing {p}")
    else:
        check_json(p)


def frontmatter(path: str) -> str | None:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if not text.startswith("---"):
        return None
    end = text.find("---", 3)
    return text[3:end] if end != -1 else None


base = os.path.join(ROOT, "plugins", "pwnfactor")

for skill in glob.glob(os.path.join(base, "skills", "*", "SKILL.md")):
    name = os.path.basename(os.path.dirname(skill))
    head = frontmatter(skill)
    if head is None:
        errors.append(f"skill {name}: SKILL.md missing YAML frontmatter")
        continue
    if "description:" not in head:
        errors.append(f"skill {name}: frontmatter missing 'description'")
    with open(skill, encoding="utf-8") as fh:
        lines = len(fh.read().splitlines())
    if lines > 500:
        errors.append(f"skill {name}: SKILL.md is {lines} lines (limit 500)")

VALID_EFFORT = {"low", "medium", "high", "xhigh", "max"}
VALID_MODEL = {"sonnet", "opus", "haiku", "fable", "inherit"}

for agent in glob.glob(os.path.join(base, "agents", "*.md")):
    name = os.path.basename(agent)
    head = frontmatter(agent)
    if head is not None:
        # Silent inheritance is the documented cost trap: an agent with no model: rides the
        # main-loop model, and one with no effort: rides the session effort. Both must be explicit.
        m = re.search(r'^model:\s*(\S+)', head, re.M)
        e = re.search(r'^effort:\s*(\S+)', head, re.M)
        if m is None:
            errors.append(f"agent {name}: frontmatter missing 'model' (would silently inherit)")
        elif m.group(1) not in VALID_MODEL and not m.group(1).startswith("claude-"):
            errors.append(f"agent {name}: model '{m.group(1)}' is not a documented value")
        if e is None:
            errors.append(f"agent {name}: frontmatter missing 'effort' (would silently inherit)")
        elif e.group(1) not in VALID_EFFORT:
            errors.append(f"agent {name}: effort '{e.group(1)}' not in {sorted(VALID_EFFORT)}")
    head = frontmatter(agent)
    if head is None or "name:" not in head or "description:" not in head:
        errors.append(f"agent {name}: frontmatter must include 'name' and 'description'")


# marketplace two-copies rule (CLAUDE.md): byte-identical or the plugin ships two truths
try:
    _a = open(os.path.join(ROOT, "marketplace.json"), "rb").read()
    _b = open(os.path.join(ROOT, ".claude-plugin", "marketplace.json"), "rb").read()
    if _a != _b:
        errors.append("marketplace.json: root and .claude-plugin copies are NOT byte-identical")
except OSError as _e:
    errors.append(f"marketplace copies unreadable: {_e}")

# cross-references: every backticked .md/.py/.ps1 relative path in a skill file must resolve,
# whether written as ../x or as a bare dir/x (codex F25 - the bare form escaped earlier checks)
_REF = re.compile(r"`((?:\.\./)?[a-z0-9_-]+/[a-z0-9/_.-]+\.(?:md|py|ps1))`")
for _md in glob.glob(os.path.join(base, "skills", "*", "*.md")):
    _d = os.path.dirname(_md)
    _text = open(_md, encoding="utf-8").read()
    for _m in _REF.finditer(_text):
        _ref = _m.group(1)
        if _ref.startswith("tools/"):
            continue  # target-repo convention (cards scaffolds tools/card_check.py THERE, not here)
        _cand = [os.path.normpath(os.path.join(_d, _ref)),
                 os.path.normpath(os.path.join(base, "skills", _ref)),
                 os.path.normpath(os.path.join(base, _ref))]  # plugin root (agents/, hooks/, ci/)
        if not any(os.path.exists(_c) for _c in _cand):
            errors.append(f"{os.path.relpath(_md, ROOT)}: dead reference `{_ref}`")

if errors:
    print("PLUGIN VALIDATION FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

print("Plugin structure OK.")
