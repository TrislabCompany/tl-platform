# aca-app

Runs 1–10 container apps in one Container Apps environment, as one stamp, as specified in `06-stamp-templates.md` sections 2 to 8 of `tl-cloud-infrastructure`. A stamp's generated `main.tf` calls it, at a tag `aca-app/v<x.y.z>`.

## Inputs

The inputs of section 2, all passed by the generated `main.tf`, and nothing else: `config` (`stamp.yaml`), `lz`, `tenants`, `cloudflare_ips`, `data_access`, `github_owner_id`, `app_repo_ids`, `origin_cert_versions`, `origin_certs` (ephemeral), `ghcr_pull_token_version` and `ghcr_pull_token` (ephemeral).

The local module `catalog/` reads what the template needs from the repository besides them: the stamp's folder and landing zone from its path, and `catalog/owners.yaml` (the product code) and `catalog/ipam.yaml` (the stamp's range), through `path.root`, like the generated `main.tf` reads the other files.

## What it creates

Steps 1 to 6 of section 6.1, in `rg-<stamp>`: the subnet and NSG (`blocks/stamp-network`), `id-<stamp>-workload` and `id-<stamp>-appdeploy` (`blocks/app-deploy-identity`), the secrets in the landing zone's Key Vault (`blocks/kv-secret-access`), `cae-<stamp>`, one `ca-<stamp>-<app>` per app on the placeholder image `platform-placeholder:1.0.0`, pinned by digest, and the hostname bindings (`blocks/hostname-bindings`).

## Files

| File | What it is |
|---|---|
| `stamp.schema.json` | The JSON schema of `stamp.yaml` for this release, which `stamp-check.yml` validates against |
| `generate.ps1` | Writes a stamp's `main.tf`: `pwsh generate.ps1 -Stamp stamps/<lz>/<folder> -StateAccount stplatformtfstate<nnnn>`, run from the root of `tl-cloud-infrastructure` |

## Tests

`tests/` runs offline with mock providers: `tofu init -backend=false`, then `tofu test`. The check on every PR runs them. `tests/rejected.tftest.hcl` plans on an empty state, so each rejected file fails only its own check.

## To check in the pilot

- A plan never gets `ghcr_pull_token` or `origin_certs`, so it passes a stand-in to `value_wo`, which isn't written. The apply job must pass both.
- A refresh of `azurerm_key_vault_secret` with Key Vault Reader only (ADR 0024).
- The `asuid` lookup of a name that doesn't exist yet returns an empty result instead of failing the plan (ADR 0027).
- The environment loads the Origin CA certificate, a PEM secret, from the Key Vault with `id-<stamp>-workload`.

## Changes

- `v1.0.0`: first release. `Consumption` only, no zone redundancy, no `data` (section 8).
