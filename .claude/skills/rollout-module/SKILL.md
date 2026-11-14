---
name: rollout-module
description: Take a released tl-platform module version to its consumers by opening the bump PRs — a stamp template version stamp by stamp, ring by ring, in tl-cloud-infrastructure; landing-zone in landing-zones/_root; app-workflows in the canary first, then every template and active app repository; an image's digest in the stamp templates that pin it. Use when the user asks to roll out, bump, upgrade or adopt a module release, or which consumers are still on an old version.
---

# rollout-module

A pointer, so that Claude Code lists this skill: it finds skills only in `.claude/skills/`. Read [.agents/skills/rollout-module/SKILL.md](../../../.agents/skills/rollout-module/SKILL.md) and follow it exactly. That file is the skill; edit it, not this one, and keep the front matter of both the same (`check` runs `.github/scripts/check-skills.py`).
