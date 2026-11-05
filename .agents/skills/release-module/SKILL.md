---
name: release-module
description: Release one tl-platform module — landing-zone, a stamp template such as aca-app, app-workflows, or an image such as platform-placeholder — by choosing its next version, writing its Changes entry and release notes, and opening the release PR; after the merge, check the commit and hand the exact tag command to an organization owner (an rc first for app-workflows). Use when the user asks to release, version or tag a module, or to prepare a module release.
---

# release-module

Prepares a release of one module of this repository. The release is a PR; the tag is created after the merge by an organization owner, never by this skill. The rules are in [AGENTS.md](../../../AGENTS.md#rules).

## Commands

| Command | Does |
| --- | --- |
| `release-module status [<module>]` | Lists each module, its last tag, and the merged commits since then that touch its folder |
| `release-module prepare <module>` | Proposes the version and opens (or updates) the release PR |
| `release-module tag <module>` | After the merge: checks the commit and prints the tag command for an organization owner |

`<module>` is the folder's last path segment: `landing-zone`, `aca-app`, `app-workflows`, `platform-placeholder`.

## The module's folder

| Module | Its paths |
| --- | --- |
| `landing-zone` | `landing-zone/` |
| `<template>` | `stamps/<template>/` and every `blocks/<block>/` it uses by relative path |
| `app-workflows` | `.github/workflows/app-ci.yml`, `app-deploy.yml`, `app-release.yml` and the scripts they call |
| `<image>` | `images/<image>/` and its build workflow |

## prepare

1. `git fetch --tags origin`. Find the last tag `<module>/v*` (for `landing-zone`, the bare `v*` tags up to `v0.6.0` count too).
2. List the merged commits since that tag that touch the module's paths. When there are none, stop: nothing to release.
3. **Propose the bump** from those commits with the reason, by the versioning rules in AGENTS.md. Under `0.x`, breaking is a minor bump. Ask the user to confirm the version.
4. **Check the version is new:** not in `git tag -l` or `git ls-remote --tags origin`, and higher than every tag of the module. For `app-workflows`, also no `-rc.<n>` of a released version.
5. **Write the notes.**
   - A module with a README: add the entry at the top of its **Changes** section, in the style of the entries below it: what changed and why, what a consumer must do, and the ADR or spec section it follows.
   - `app-workflows`: the notes go in the PR body under `## Release notes: app-workflows vX.Y.Z`, saying first whether an app repository needs anything new (inputs, permissions, `platform.yaml` fields, secrets).
   - A major version lists every change a consumer must make, because Renovate never bumps a major and the bump PR makes them.
6. **Run the checks** of AGENTS.md and fix every failure.
7. Commit, push a branch `<module>-v<x.y.z>`, and open the PR titled `<module> vX.Y.Z` with the notes, the test result ("Tests: N passed"), and what has to merge first in other repositories (for example a role in `tl-cloud-infrastructure`). When the change itself is still in its own open PR, add the version and notes to that PR instead of opening a second one.

## tag

1. Check the release PR is merged, and take its merge commit on `origin/main` (full SHA, never local `HEAD`).
2. Check the `check` run of that PR passed, and the tag still doesn't exist.
3. **`app-workflows`:** the first tag is `app-workflows/vX.Y.Z-rc.1` on that commit. It is tested in the canary `trislab-website-corporate-site`: a normal PR there pins its callers to the rc; once merged, its deploy runs, and a version tag releases with it. Only when both work does the same commit get `app-workflows/vX.Y.Z`. A failed rc is fixed by a new PR and the next rc, never a moved tag.
4. **An image:** the tag starts its build workflow, which refuses a version already pushed. Report the image's digest from that run; templates pin it by digest.
5. Print the exact commands for an organization owner, an annotated tag pushed alone:

   ```bash
   git tag -a <module>/vX.Y.Z <sha> -m "<module> vX.Y.Z"
   git push origin refs/tags/<module>/vX.Y.Z
   ```

   Never push with `--tags` or `--follow-tags`, and never with a workflow's token.
6. Once tagged, suggest `rollout-module <module> vX.Y.Z`.

## Rules

- Never create, move or delete a tag yourself. Never merge or approve a PR.
- One module per release PR, so each tag releases one reviewed change set.
