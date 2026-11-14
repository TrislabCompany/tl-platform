# tl-platform

The versioned building parts of the Trislab platform. `tl-cloud-infrastructure` and the app repositories pin each one by its release tag `<module>/vX.Y.Z`.

| Module | What | Released as |
| --- | --- | --- |
| [`landing-zone`](landing-zone/README.md) | Builds one application landing zone | `landing-zone/vX.Y.Z` |
| [`stamps/aca-app`](stamps/aca-app/README.md) | The stamp template for apps on Azure Container Apps | `aca-app/vX.Y.Z` |
| `blocks/` | Building blocks the stamp templates use by relative path | With the template that uses them |
| `.github/workflows/app-*.yml` | The reusable app workflows: CI, deploy, release, promote | `app-workflows/vX.Y.Z` |
| `images/platform-placeholder` | The image a stamp runs before an app's first deploy | `platform-placeholder/vX.Y.Z` |

How to work here, the checks and the release rules: [AGENTS.md](AGENTS.md).
