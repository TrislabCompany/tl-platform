# tl-platform

> The versioned building parts of the Trislab platform: the `landing-zone` module, the stamp templates, their building blocks, the reusable app workflows and the platform's own images. `tl-cloud-infrastructure` and the app repositories pin each one by its release tag.

This file is the guide for every AI coding tool (Claude Code, Cursor, Codex, …). `CLAUDE.md` only imports it. The platform spec (spec v2) lives in `tl-cloud-infrastructure` under `docs/spec/v2/` and is not published; where it is named below, ask a member of `devops` for it when you don't have the local clone.

## Repository map

| Path | What | Released as |
| --- | --- | --- |
| `landing-zone/` | Builds one application landing zone from its `landing-zones/<lz>.yaml` (spec 05). Called once per landing zone by `landing-zones/_root` in `tl-cloud-infrastructure` | `landing-zone/vX.Y.Z` |
| `stamps/<template>/` | A stamp template, such as `aca-app`, with its generator `generate.ps1`, `stamp.schema.json` and catalog (spec 06) | `<template>/vX.Y.Z`, e.g. `aca-app/v1.0.3` |
| `blocks/<block>/` | Building blocks the stamp templates use by relative path | Not on their own: with the template that uses them |
| `.github/workflows/app-*.yml` | The reusable app workflows `app-ci.yml`, `app-deploy.yml`, `app-release.yml` (spec 13 section 9) | `app-workflows/vX.Y.Z`, tested first as `app-workflows/vX.Y.Z-rc.<n>` |
| `images/<image>/` | The platform's own container images, such as `platform-placeholder`; built by their workflow on a tag | `<image>/vX.Y.Z` |
| `.github/workflows/check.yml` | The required check `check` on every PR | Not released |

Each module's `README.md` ends with a **Changes** section: one entry per release, newest first.

## Rules

- **Every change is a PR** to `main`: squash merge, one CODEOWNERS approval (`devops`), and the check `check` green.
- **Tags.** A release tag is `<module>/v<major>.<minor>.<patch>`, where `<module>` is the folder's last path segment. Only an organization owner creates one, on the merge commit of a merged PR. A tag is never moved, deleted or reused, a deleted rc included; a fix is a new version. Never tag `v*`.
- **Semantic versioning** by what a consumer must do:
  - stamp template (spec 06 section 8): major when a stamp needs a `stamp.yaml` change or the plan recreates a resource that holds data or traffic; minor for new optional fields or resources; patch for a fix with no interface change;
  - `app-workflows` (spec 13 section 9): major for a new required input, a permission the callers must grant, or a `platform.yaml` field; minor for a feature; patch for a fix. Renovate never bumps a major, so the bump PR makes the caller changes;
  - `landing-zone`: major when a landing zone's `lz.yaml` or the root's call must change; minor for a new optional input; patch for a fix. Under `0.x`, a breaking change is a minor bump.
- **Nothing signs in from this repository.** No cloud credentials, no `tofu apply`, no state. The modules are tested offline with mock providers.
- **The repository is public.** No customer names, secrets, subscription IDs or internal URLs in code, docs, PRs or commits.
- **Pins.** Actions are pinned by full commit SHA with the version in a comment. Images are pinned by version and digest.

## Checks

Run before every push, as `check.yml` does:

```bash
tofu fmt -check -diff -recursive
# in each folder with a versions.tf:
tofu -chdir=<dir> init -backend=false && tofu -chdir=<dir> validate
tofu -chdir=<dir> test          # where a tests/ folder exists
actionlint
```

## Skills

Skills live only in `.agents/skills/<name>/SKILL.md`. When a task matches a skill, read that file and follow it.

| Skill | Use when |
| --- | --- |
| [`release-module`](.agents/skills/release-module/SKILL.md) | Releasing a module: choosing its version, writing its Changes entry and opening the release PR; after the merge, preparing the tag for an organization owner |
| [`rollout-module`](.agents/skills/rollout-module/SKILL.md) | Taking a released module version to its consumers: the bump PRs in `tl-cloud-infrastructure` ring by ring, or in the app repositories and templates |
