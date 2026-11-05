---
name: rollout-module
description: Take a released tl-platform module version to its consumers by opening the bump PRs — a stamp template version stamp by stamp, ring by ring, in tl-cloud-infrastructure; landing-zone in landing-zones/_root; app-workflows in the canary first, then every template and active app repository; an image's digest in the stamp templates that pin it. Use when the user asks to roll out, bump, upgrade or adopt a module release, or which consumers are still on an old version.
---

# rollout-module

Opens the PRs that move a module's consumers to a released version, until Renovate does it (spec 08 section 3, spec 13 section 9: roadmap phase 15). Each consumer repository's own rules and checks apply; read its `AGENTS.md` or `CLAUDE.md` and `README.md` first. The rules of this repository are in [AGENTS.md](../../../AGENTS.md#rules).

## Commands

| Command | Does |
| --- | --- |
| `rollout-module status <module>` | Lists every consumer and the version it pins |
| `rollout-module <module> vX.Y.Z` | Opens the next bump PR(s) for that version, after a yes per repository |

## Before anything

1. Check the tag `<module>/vX.Y.Z` exists on `origin` and is not an rc (an `app-workflows` rc goes only to the canary, below).
2. Read the release notes (the module README's Changes entry, or the release PR body for `app-workflows`). For a **major** version, list the changes each consumer must make; the bump PR makes them in the same commit.
3. Show the consumers, what each PR changes, and the order, and get the user's **yes for each repository**. A PR is outward-facing.

## The consumers

| Module | Consumer | The bump PR |
| --- | --- | --- |
| A stamp template, e.g. `aca-app` | Each stamp with `template: <template>` in `tl-cloud-infrastructure/stamps/<lz>/<stamp>/stamp.yaml` | Sets `version: vX.Y.Z`, then regenerates `main.tf` with the generator **of that release** (`stamps/<template>/generate.ps1` at the tag, run from the root of `tl-cloud-infrastructure`, as its header says). `stamp-check` fails when `main.tf` differs from the generator's output |
| `landing-zone` | `tl-cloud-infrastructure/landing-zones/_root/main.tf` | One PR that bumps `?ref=landing-zone/vX.Y.Z`, the one root that calls the module for every landing zone |
| `app-workflows` | The callers `ci.yml`, `deploy.yml`, `release.yml` in each app repository and template | Bumps `@app-workflows/vX.Y.Z` in each caller |
| An image, e.g. `platform-placeholder` | The stamp templates in this repository that pin it (e.g. `stamps/aca-app/locals.tf`) | Bumps the version and digest here, released with the template's next version; it reaches stamps with that version. An image tag never opens a stamp PR by itself |

## Order

- **Stamp templates, ring by ring** (ADR 0009, spec 02 section 5): Trislab's sandbox landing zones, then Trislab's prod, then customer sandboxes, then customer prod, regulated customers last. One PR per ring, holding that ring's stamps. Open a ring's PR only when the previous ring's PR is merged **and applied**: its `applied` check passed. A failed ring stops the rollout; later rings stay on the old version.
- **A plan that recreates a Container Apps environment** or a resource that holds data is a stop sign: say so in the PR and ask the reviewer to check it.
- **`app-workflows`:** the canary `trislab-website-corporate-site` first. Its PR proves `ci / ci`; once merged, its deploy must succeed. Then one PR in each template (`tl-template-website`, `tl-template-webapp`, `tl-template-saas`) and in each `active` repository of `tl-cloud-infrastructure/catalog/repos.yaml`. To test an rc, only the canary pins it; afterwards a second canary PR moves it to the release tag.
- **`landing-zone`:** one PR. A release that needs a change in `platform/` first (for example a custom role) says so; open the bump only once that change is applied.

## Each PR

1. In the consumer's clone: check it is clean, fetch, branch from an up-to-date `main` (`bump-<module>-v<x.y.z>`, plus `-<ring>` for a stamp ring).
2. Make the bump, and the consumer changes of a major version.
3. Run that repository's checks (in `tl-cloud-infrastructure`: `tofu fmt` and the stamp generator; in an app repository: what its README says).
4. Commit and open the PR titled `Bump <module> to vX.Y.Z` (`, ring <ring>` for a stamp ring). The body links the release notes, lists the stamps or repositories, and says what the reviewer must check in the plan.
5. Report each PR, and the next step: who reviews it, and which ring comes next.

## Rules

- Never merge, approve or apply a PR, and never run `tofu apply` or `/apply`.
- Never pin a branch, a commit or an rc outside the canary.
- Never edit a generated `main.tf` by hand.
