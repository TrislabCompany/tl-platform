# landing-zone

Builds one application landing zone from its `landing-zones/<lz>.yaml`, as specified in `05-landing-zones.md` of `tl-cloud-infrastructure`. Called once per landing zone by `landing-zones/_root`. This release holds only the Azure half.

## Inputs

| Input | What it is |
|---|---|
| `lz` | The decoded `lz.yaml` |
| `catalog` | `owners` and `regions` from `catalog/owners.yaml` and `catalog/regions.yaml`, `landing_zones` from `catalog/ipam.yaml` |
| `platform_suffix` | `PLATFORM_SUFFIX` |
| `github_owner_id`, `github_repository_id` | For the immutable OIDC subject |
| `az_billing_account`, `az_billing_profile` | `AZ_BILLING_ACCOUNT`, `AZ_BILLING_PROFILE` |
| `az_platform_invoice_section` | The ID of `is-platform`, for experiments |
| `edge_reader_ids` | The object IDs of `spn-global-plan` and `spn-global-apply` |
| `landingzones_apply_id` | The object ID of `spn-landingzones-apply`, the owner of the landing zone's identities |
| `devops_team_id` | The numeric ID of the GitHub team `devops`, the reviewers of `lz-<lz>` |
| `pim` | `false` until Entra ID P2 is bought |

## Providers

The root passes one `azurerm` provider, signed in to `sub-platform`, with `resource_provider_registrations = "none"` and `subscription { prevent_cancellation_on_destroy = true }`. It creates the hub half of the peering, the DNS links, and everything addressed by a scope: locks, role assignments and the budget. The subscription is created by a PUT of its alias with `azapi`, because `spn-landingzones-plan` can't read an alias. What goes into the landing zone's resource groups is created with `azapi`, by its parent's full ID, because a provider for the new subscription would need its ID at plan. `github` writes the Environment `lz-<lz>` in `tl-cloud-infrastructure`.

## Tests

`tests/` runs offline with mock providers: `tofu init -backend=false`, then `tofu test`. The check on every PR runs them.

## Not built yet

- `budget.notify_customer`: built with the first customer landing zone that sets it, together with the right to read `contacts-<code>`.
- The CMK key of a regulated landing zone: built with the first regulated landing zone. Until then `archetype: regulated` is rejected.

## Changes

Releases up to `v0.6.0` are tagged without a prefix. Later releases are tagged `landing-zone/v<x.y.z>`, e.g. `?ref=landing-zone/v0.7.0`.

- `v0.6.0`:
  - **Subscription by alias PUT.** The subscription is created by `azapi_resource_action` instead of `azurerm_subscription`. Reading an alias needs `Microsoft.Subscription/aliases/write`, so the plan of an existing landing zone failed. A `removed` block drops `azurerm_subscription` from the state without cancelling anything; the next apply's PUT adopts the alias. At plan, the subscription's ID comes from the list of subscriptions, so nothing keyed on it is planned as replaced.
- `v0.5.0`:
  - **Identity owners.** `spn-landingzones-apply` is the owner of `spn-lz-<lz>-plan` and `-deploy`, app registration and service principal. With `Application.ReadWrite.OwnedBy` it couldn't add their service principals or federated credentials without it. New input `landingzones_apply_id`.
- `v0.4.0`:
  - **Cancel deletes first.** Once `cancelled`, the resource groups are deleted with everything in them: each lock first, then the Network Watcher, spoke, Key Vault and workspace. The budget stays. A cancelled subscription is read-only, so the cancel comes with the next apply, once the list of the subscription's resource groups, read at plan, holds no `rg-<lz>-*` group. An experiment has none, so it is cancelled by one apply.
  - **Locks.** Each lock depends on the Key Vault and the workspace, so it is deleted before them.
- `v0.3.0`:
  - **One plan, one apply.** The resource groups, Network Watcher, spoke, spoke half of the peering, Key Vault and workspace are created with `azapi`. The root no longer passes `azurerm.lz`, whose subscription ID was unknown at the first plan.
  - **Spoke.** The spoke is never updated in place, so a change can't remove the stamps' subnets.
  - **Key Vault.** The public endpoint and its network rule (allow, Azure services bypass) are set explicitly.
  - **Reviewers.** `devops_team_id` replaces the lookup of the team, which the GitHub Apps can't read.
- `v0.2.0`:
  - **New checks.** `lz.yaml` is now rejected when:
    - `production_data` is set (true or false) outside prod;
    - `ttl` is set outside an experiment;
    - the name's scope doesn't match `owner`;
    - `archetype` is `regulated`;
    - `budget.monthly_eur` isn't a whole number above 0;
    - the name ends in `-01`.
  - **Owner removal.** Only the creator's Owner assignment is removed, and provider registration waits for that removal.
  - **Grant condition.** The deploy identity's grant condition gives service principals only the stamp identity roles of ADR 0024. It may delete assignments of both role lists.
  - **Prod access.** In prod, only Contributor and Key Vault Secrets Officer of `grp-devops` move to `grp-platform-admins`.
  - **Key Vault name.** `sb` shortens only `sandbox` in the Key Vault name. A name that is still too long fails.
- `v0.1.0`: first release, Azure half.
