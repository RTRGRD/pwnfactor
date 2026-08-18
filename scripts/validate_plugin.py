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

if errors:
    print("PLUGIN VALIDATION FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

print("Plugin structure OK.")
