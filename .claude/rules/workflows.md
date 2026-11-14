---
paths:
  - ".github/**"
---

# GitHub Actions workflows and scripts

Checked by: `actionlint`, `.github/scripts/check-pins.py` and `shellcheck` (`check.yml`).

## Workflows

- **`permissions: {}` at the top,** and each job grants only what it needs (`contents: read`, `id-token: write` only where it signs in). A reusable workflow documents the permissions its caller must grant.
- **Every action is pinned by its full commit SHA,** with the version in a comment: `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. Images by version and digest. Tools by version, installed with `.github/scripts/install-tool.sh`.
- `actions/checkout` with `persist-credentials: false`, unless a later step pushes.
- **Never put `${{ … }}` of untrusted input** (a PR title, a branch name, an input) straight into `run:`. Pass it through `env:` and quote it: `"$TITLE"`.
- A file starts with a comment saying what it does, who calls it and which spec section it implements. Every input and secret has a `description`.
- A `concurrency` group on PR workflows, with `cancel-in-progress: true`.

## Logging in a workflow

The log of a run is what someone reads when it fails. Make it short and specific:

- `::error::<what failed>. <what to do>` for a failure, one per problem, then `exit 1` after reporting them all. `::notice::` for a skipped or noteworthy step. `::group::<name>` / `::endgroup::` around long output.
- A summary for people goes to `$GITHUB_STEP_SUMMARY`.
- **Never print a secret,** a token or an `az` / `gh` output that may contain one; mask a value you derive from a secret with `::add-mask::`.

## Scripts

- `.github/scripts/*.sh`: `#!/usr/bin/env bash` and `set -euo pipefail`, every variable quoted. `.github/scripts/*.py`: Python 3 standard library only, a docstring saying what it checks, exit code 1 on a problem.
- A workflow change goes in its own PR (AGENTS.md), and an `app-*` workflow change is released as `app-workflows/vX.Y.Z`, rc first.
