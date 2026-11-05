# aca-app

Runs 1–10 container apps in one Container Apps environment, as one stamp, as specified in `06-stamp-templates.md` sections 2 to 8 of `tl-cloud-infrastructure`. A stamp's generated `main.tf` calls it, at a tag `aca-app/v<x.y.z>`.

## Inputs

The inputs of section 2, all passed by the generated `main.tf`, and nothing else: `config` (`stamp.yaml`), `lz`, `tenants`, `cloudflare_ips`, `data_access`, `github_owner_id`, `app_repo_ids`, `origin_cert_versions`, `edge_hostnames`, `origin_certs` (ephemeral), `ghcr_pull_token_version`, `ghcr_pull_token` (ephemeral) and `alert_action_group_ids`.

The local module `catalog/` reads what the template needs from the repository besides them: the stamp's folder and landing zone from its path, and `catalog/owners.yaml` (the product code) and `catalog/ipam.yaml` (the stamp's range), through `path.root`, like the generated `main.tf` reads the other files.

## What it creates

Steps 1 to 6 of section 6.1, in `rg-<stamp>`: the subnet and NSG (`blocks/stamp-network`), `id-<stamp>-workload` and `id-<stamp>-appdeploy` (`blocks/app-deploy-identity`), the secrets in the landing zone's Key Vault (`blocks/kv-secret-access`), `cae-<stamp>`, one `ca-<stamp>-<app>` per app on the placeholder image `platform-placeholder:1.0.0`, pinned by digest, and the hostname bindings (`blocks/hostname-bindings`).

In a prod landing zone, also the alert rules of section 6.8, sent to every action group in `alert_action_group_ids` (`ag-platform`), and a prod stamp fails the plan without one:

| Rule | Apps | Fires when |
|---|---|---|
| `<stamp>-<app>-restarts` | Every app | Its replicas restart more than 3 times in 15 minutes |
| `<stamp>-<app>-server-errors` | Every app with ingress | 5 or more requests are answered with 5xx in 15 minutes. Azure Monitor can't divide one metric by another, so the 5 per cent of section 6.8 waits for the observability platform app, and 15 minutes is the nearest metric alert window to 10 |
| `<stamp>-<app>-no-replica` | Every app with ingress and `caps.min_replicas` above 0 | It has no running replica for 5 minutes. The deploy refuses a `min_replicas` below the caps, so only the caps promise a lower limit above 0 |

## Files

| File | What it is |
|---|---|
| `stamp.schema.json` | The JSON schema of `stamp.yaml` for this release, which `stamp-check.yml` validates against |
| `generate.ps1` | Writes a stamp's `main.tf`: `pwsh generate.ps1 -Stamp stamps/<lz>/<folder> -StateAccount stplatformtfstate<nnnn>`, run from the root of `tl-cloud-infrastructure` |

## Tests

`tests/` runs offline with mock providers: `tofu init -backend=false`, then `tofu test`. The check on every PR runs them. `tests/rejected.tftest.hcl` plans on an empty state, so each rejected file fails only its own check.

## To check in the pilot

- A plan never gets `ghcr_pull_token` or `origin_certs`, so it passes a stand-in to `value_wo`, which isn't written. The apply job must pass both.
- The environment loads the Origin CA certificate, a PEM secret, from the Key Vault with `id-<stamp>-workload`.
- The No replica rule fires when an app is stopped: a static metric alert doesn't fire on missing data, so check that `Replicas` reports 0 rather than nothing (phase 10 exit test).
- The landing zone's deploy identity can link `ag-platform`, which lives in another subscription, to an alert rule.

## Changes

- `v1.1.0`: the alert rules of section 6.8 in a prod landing zone, sent to the new input `alert_action_group_ids`, which the generator passes from `ALERT_ACTION_GROUP_IDS` in `lz-<lz>`; a prod stamp fails the plan without one. The new optional `caps.min_replicas`, 0 by default, is the lower replica limit the deploy must keep, and above 0 adds the No replica rule. A `pr<n>` check no longer matches `prod`, which failed every prod stamp. A sandbox stamp plans as before; a stamp that takes this version regenerates its `main.tf`.

- `v1.0.3`: every app with `ingress: external` admits only the `ipv4` ranges of `cloudflare_ips`, as IP restrictions on its ingress: the NSG doesn't filter traffic to the environment's public address (ADR 0027).
- `v1.0.2`: writes the Key Vault secrets through Azure Resource Manager (`azapi_resource`) instead of `azurerm_key_vault_secret`, whose refresh reads the value, which the plan identity's Key Vault Reader can't (ADR 0024). A `moved` block takes over the existing secrets.
- `v1.0.1`: binds the hostnames in `edge_hostnames`, from `EDGE_HOSTNAMES`, instead of looking up `asuid.<hostname>`: the `dns` provider failed the plan on a name that didn't exist yet (ADR 0027). The generator passes the new input.
- `v1.0.0`: first release. `Consumption` only, no zone redundancy, no `data` (section 8).
