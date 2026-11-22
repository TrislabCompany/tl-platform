# tl-platform

The versioned building parts of the Trislab platform: the `landing-zone` module, the stamp templates (such as `aca-app`) and their building blocks, the reusable app workflows `app-ci`, `app-deploy`, `app-release` and `app-promote`, and the platform's own images. Each one is released as its own tag, `<module>/vX.Y.Z`. `tl-cloud-infrastructure` and the app repositories pin it by that tag. Nothing is applied from here. Start with [AGENTS.md](AGENTS.md): its Role section says what belongs here and where everything else goes.
