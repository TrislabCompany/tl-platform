---
paths:
  - "**/*.tf"
---

# OpenTofu coding standards

Checked by: `tofu fmt -check -recursive`, `tofu validate` and `tofu test` in every folder with a `versions.tf` (`check.yml`). Names and the platform design are in spec v2 (03 for names, 05 for landing zones, 06 for stamp templates).

## Layout of a module

| File | Holds |
|---|---|
| `versions.tf` | `required_version >= <.opentofu-version>` and each provider with a `~>` pin (`azurerm ~> 5.8`) |
| `variables.tf` | Every input, with a header comment naming the spec section it implements |
| `locals.tf` | Names and derived values, computed once |
| `main.tf`, or one file per concern (`apps.tf`, `alerts.tf`, `identities.tf`) | Resources, grouped by what they are for |
| `outputs.tf` | Every output, with a description saying who reads it |
| `tests/*.tftest.hcl` | The tests (`testing.md`) |
| `README.md` | Inputs, tests and the **Changes** log, newest first (blocks have none: they are released with their template) |

## Rules

- **Every variable and output has a `description`** that says what it is and cites the spec section ("(06 section 6.3)"). A variable with a limit has a `validation` block whose `error_message` says what is allowed. A rule across inputs is a `precondition` on the resource, with the same kind of message.
- **Types are exact:** `object({...})` with `optional(..., default)`, never `any`. A list that becomes resources is turned into a map keyed by a stable name and used with `for_each` (a removed middle item must not recreate the rest); `count` only as a 0-or-1 switch (`count = local.network ? 1 : 0`).
- **Names come from `locals`,** built once from the tokens of spec 03; a resource never assembles its own name. Every resource that takes tags gets the module's tag map.
- **No provider blocks and no backends in a module;** the caller configures them. No `data` source that reads live state the tests can't mock.
- **Blocks are used by relative path** (`source = "../../blocks/<block>"`) and are never released alone.
- **A resource that holds data or traffic** keeps its address: changing its `for_each` key, its name or anything that recreates it is a major version (AGENTS.md "Semantic versioning"). Use a `moved` block when only the address changes.
- **Comments say why,** not what: a workaround, a provider quirk, the spec section a choice follows.
- No secrets, subscription ids or customer names in code; they come from inputs.
