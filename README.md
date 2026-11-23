# tl-platform

The versioned building parts of the Trislab platform: the `landing-zone` module, the stamp templates (such as `aca-app`) and their building blocks, the reusable app workflows `app-ci`, `app-deploy`, `app-release` and `app-promote`, and the platform's own images. Each one is released as its own tag, `<module>/vX.Y.Z`. `tl-cloud-infrastructure` and the app repositories pin it by that tag. Nothing is applied from here. Start with [AGENTS.md](AGENTS.md): its Role section says what belongs here and where everything else goes.

## Licence

Proprietary: [LICENSE](LICENSE). The code is public to read, but it belongs to Trislab d.o.o., and only Trislab, and the clients of the applications Trislab delivers under a written agreement, may use it. Cloning or forking it for use, copying, redistribution and training AI models on it are not allowed. Material of others, such as the dependencies and a client's texts, logos and photos, keeps its owner's rights and its own licence.
