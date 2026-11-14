---
paths:
  - "**/variables.tf"
  - "**/outputs.tf"
  - "stamps/**/stamp.schema.json"
  - "stamps/**/catalog/**"
  - ".github/workflows/app-*.yml"
---

# Contracts with the consumers

Checked by: `tofu validate`, `tofu test` (the rejected cases) and `actionlint`; the compatibility itself is review only. Every module is pinned by its tag in `tl-cloud-infrastructure` or in the app repositories, so what a consumer passes in, or reads out, is a contract.

| Contract | Consumers |
|---|---|
| `landing-zone` inputs and outputs | `landing-zones/_root` in `tl-cloud-infrastructure` |
| A stamp template's `stamp.yaml` (`stamp.schema.json`), inputs and outputs | The generated `main.tf` of every stamp |
| `app-*.yml` inputs, secrets, permissions and the `platform.yaml` schema in `app-ci.yml` | Every app repository's workflows; the templates' `platform.schema.json` copy |
| The settings an app gets (`PLATFORM_*`, `DATABASE_URL`, …), its port, `/healthz` and `/readyz` | Every app and the app templates |

- **Change only by adding,** within a major version: a new optional input with a default, a new output, a new optional `platform.yaml` or `stamp.yaml` field. A new required input, a renamed or removed one, a narrower validation, or a change that recreates a resource holding data or traffic is a **major version** (AGENTS.md "Semantic versioning").
- **Change the schema and its copies together:** `stamp.schema.json` with the template's `variables.tf`; the `platform.yaml` schema in `app-ci.yml` with the `platform.schema.json` copy in each app template, in the same release.
- **Every release says what a consumer must do** in the module README's Changes entry: nothing, a new optional field, or the steps of a major.
- **What an app may rely on is written in the template's README** (the settings, the port, the probes, where its logs go). An app relying on anything else is relying on an accident.
