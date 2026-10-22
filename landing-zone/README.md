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
| `pim` | `false` until Entra ID P2 is bought |

## Providers

The root passes two `azurerm` providers, both with `resource_provider_registrations = "none"`:

- the default one, signed in to `sub-platform`, for the subscription, the hub half of the peering, the DNS links and everything addressed by its full ID;
- `azurerm.lz`, with `subscription_id = module.<name>.subscription_id`, for what goes into the landing zone's resource groups.

The default one also sets `subscription { prevent_cancellation_on_destroy = true }`. `github` writes the Environment `lz-<lz>` in `tl-cloud-infrastructure`.

## Tests

`tests/` runs offline with mock providers: `tofu init -backend=false`, then `tofu test`. The check on every PR runs them.

## Not built yet

- `budget.notify_customer`: built with the first customer landing zone that sets it, together with the right to read `contacts-<code>`.
- The CMK key of a regulated landing zone: built with the first regulated landing zone. Until then `archetype: regulated` is rejected.

## Changes

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
