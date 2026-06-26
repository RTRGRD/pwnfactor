---
name: yomom
description: Trash-talk alias for the pwnfactor security sweep. Runs the same project-wide pre-prod security audit as /pwnfactor:sweep — secret scan, dependency CVEs, adversarial surface review (injection/authz/SSRF/traversal/crypto), safety-rail check, and a GO/NO-GO. Use when the user types /pwnfactor:yomom, says "pwn yo mom", or wants a security audit before a production push or big build.
---

# /pwnfactor:yomom 💀

> *"yo mom's prod is so wide open, I pwned it from the lobby."*

**First, tell the user in one line what this is:** the trash-talk alias for the pre-prod security sweep (secrets, dep CVEs, injection/authz/SSRF, safety rails → GO/NO-GO), run before a production push or big build.

Then **run the full workflow in `/pwnfactor:sweep`** — read and execute that skill's steps. Same audit, funnier name. gg.
