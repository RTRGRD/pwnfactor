#!/usr/bin/env python3
"""pwnfactor stop-hook gate verifier - FAIL-OPEN, loop-safe.

Fires on Stop (only where the pwnfactor plugin is enabled). If the working tree has
uncommitted CODE changes that haven't passed /pwnfactor:gg (no fresh .pwnfactor/gate.json
for the current HEAD), it nudges ONCE to run the review gate. It can never wedge a session:

  any error / non-git dir / missing input  -> allow (exit 0)
  stop_hook_active (already re-blocking)    -> allow  (one nudge per turn, never a loop)
  PWNFACTOR_GATE_BYPASS set in the env      -> allow
  Disable entirely:  claude plugin disable pwnfactor
"""
import sys
import os
import json
import subprocess

CODE_EXTS = (".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".rs", ".go", ".java", ".rb",
             ".php", ".c", ".h", ".cpp", ".cc", ".hpp", ".cs", ".sql", ".sh", ".ps1", ".psm1",
             ".kt", ".kts", ".swift", ".m", ".mm", ".scala", ".dart", ".ex", ".exs", ".erl",
             ".fs", ".fsx", ".vb", ".vue", ".svelte", ".astro", ".sol", ".zig", ".hs", ".clj",
             ".groovy", ".pl", ".pm", ".bash", ".zsh", ".ipynb", ".proto", ".prisma", ".tf",
             ".tfvars", ".cmake", ".gd", ".lua", ".r", ".jl")
# Executable files the extension test misses: build/container entrypoints by NAME, and CI
# workflow YAML by PATH (config .yml elsewhere stays ungated - too noisy to gate globally).
CODE_BASENAMES = ("dockerfile", "makefile", "cmakelists.txt", "justfile", "rakefile", "gemfile")


def allow():
    sys.exit(0)


def main():
    raw = "" if sys.stdin.isatty() else sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}

    if data.get("stop_hook_active"):
        allow()
    if os.environ.get("PWNFACTOR_GATE_BYPASS"):
        allow()

    cwd = data.get("cwd") or os.getcwd()

    def git(*args):
        return subprocess.run(["git", "-C", cwd, *args],
                              capture_output=True, text=True, timeout=10)

    top = git("rev-parse", "--show-toplevel")
    if top.returncode != 0:
        allow()  # not a git repo
    repo = top.stdout.strip()

    # -uall: porcelain collapses an UNTRACKED DIRECTORY to one "?? dir/" row, hiding every
    # file inside it - brand-new code in a brand-new directory would never gate without it.
    status = git("status", "--porcelain", "-uall")
    if status.returncode != 0:
        allow()

    code_changes = []
    for line in status.stdout.splitlines():
        if not line.strip():
            continue
        path = line[3:].strip()
        if " -> " in path:                       # rename: keep the destination
            path = path.split(" -> ")[-1]
        path = path.strip().strip('"')
        low = path.lower().replace("\\", "/")
        base = low.rsplit("/", 1)[-1]
        if (low.endswith(CODE_EXTS) or base in CODE_BASENAMES
                or (".github/workflows/" in low and low.endswith((".yml", ".yaml")))):
            code_changes.append(path)

    if not code_changes:
        allow()  # nothing code-ish uncommitted -> nothing to gate

    head = git("rev-parse", "HEAD")
    head_sha = head.stdout.strip() if head.returncode == 0 else ""
    gate_path = os.path.join(repo, ".pwnfactor", "gate.json")
    if head_sha and os.path.exists(gate_path):
        try:
            with open(gate_path, encoding="utf-8") as fh:
                gate = json.load(fh)
            if gate.get("verdict") in ("ship", "fix-then-ship") and gate.get("head") == head_sha:
                # Content binding: head alone lets uncommitted edits ride a passing gate
                # (HEAD does not move when the working tree changes). When the gate carries
                # dirty_sha256, the CURRENT git diff HEAD must hash to the same value.
                # A gate without the field is legacy: fail-open, as everywhere in this hook.
                want = gate.get("dirty_sha256")
                if not want:
                    allow()  # legacy gate for this HEAD
                import hashlib
                diff = git("diff", "HEAD")
                if diff.returncode != 0:
                    allow()  # cannot compute -> fail open
                have = hashlib.sha256(diff.stdout.encode("utf-8", "replace")).hexdigest()
                if have == want:
                    allow()  # fresh passing gate for this exact content
        except Exception:
            pass

    sys.stderr.write(
        "pwnfactor gate: uncommitted code changes haven't passed the review gate.\n"
        "Run /pwnfactor:gg to review this diff (it writes .pwnfactor/gate.json), "
        "or set PWNFACTOR_GATE_BYPASS=1 to skip. Disable: claude plugin disable pwnfactor.\n"
    )
    sys.exit(2)  # block once; Claude re-enters and stop_hook_active prevents a loop


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        sys.exit(0)  # fail-open: a broken hook must never wedge a session
