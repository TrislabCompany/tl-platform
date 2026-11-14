---
paths:
  - "**/tests/**"
  - "**/*.tftest.hcl"
---

# Testing the modules

Checked by: `tofu test` in every folder with a `tests/` folder (`check.yml`). Nothing signs in: every test runs offline with mock providers.

- **One file per scenario,** named for it: `aca-app.tftest.hcl` (the default), `prod.tftest.hcl`, `customer.tftest.hcl`, `managed.tftest.hcl`, and `rejected.tftest.hcl` for every input the module must refuse.
- **Every `validation` and `precondition` has a rejected case** in `rejected.tftest.hcl`, with `expect_failures` naming the variable or resource. A new limit without its rejected case isn't done.
- **Every behaviour change gets an `assert`** that fails without it: a name, a tag, a setting, a count. The `error_message` says what was expected, so a failure reads as the fix.
- **Mocks are minimal:** `mock_provider` with the `defaults` the provider checks (ids in the right shape), `override_module` for files read by path. Use fake but well-formed ids (`22222222-…`), never real ones.
- `command = plan` by default; `command = apply` (still mocked) when the assertion needs a value only known after apply.
- The reusable app workflows have no offline test: a change is tried with an `app-workflows/vX.Y.Z-rc.<n>` tag in the canary repository first (`release-module` skill).
