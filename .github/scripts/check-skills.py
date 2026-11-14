#!/usr/bin/env python3
"""Check the skill pointers: every .agents/skills/<name>/SKILL.md has a pointer
.claude/skills/<name>/SKILL.md with the same front matter, and the reverse, so
that Claude Code lists every skill (it reads only .claude/skills/).

Run from the repository root: python3 <this file>. Exits 1 on a mismatch."""
import os
import pathlib
import sys

ROOT = next(d for d in pathlib.Path(__file__).resolve().parents if (d / ".agents").is_dir())
SKILLS = ROOT / ".agents" / "skills"
POINTERS = ROOT / ".claude" / "skills"


def names(root):
    if not root.is_dir():
        return set()
    return {d.name for d in root.iterdir() if (d / "SKILL.md").is_file()}


def front_matter(path):
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    return None if end < 0 else text[4:end]


errors = []
skills, pointers = names(SKILLS), names(POINTERS)
for n in sorted(skills - pointers):
    errors.append(f"{n}: no pointer .claude/skills/{n}/SKILL.md")
for n in sorted(pointers - skills):
    errors.append(f"{n}: pointer without a skill in .agents/skills/{n}/")
for n in sorted(skills & pointers):
    s, p = front_matter(SKILLS / n / "SKILL.md"), front_matter(POINTERS / n / "SKILL.md")
    if s is None:
        errors.append(f"{n}: .agents/skills/{n}/SKILL.md has no front matter")
    elif s != p:
        errors.append(f"{n}: the pointer's front matter differs from the skill's")
for e in errors:
    print(f"::error::{e}" if "GITHUB_ACTIONS" in os.environ else e)
print(f"{len(skills)} skills, {len(errors)} problems")
sys.exit(1 if errors else 0)
