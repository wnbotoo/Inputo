# Open Source Readiness

This checklist tracks the repository work needed before making Inputo public under Apache License 2.0. It complements the code, documentation, and CI already checked into the repository.

## Repository Files

- [x] `LICENSE` with Apache License 2.0 text.
- [x] `NOTICE` with project attribution.
- [x] `README.md` as the public project homepage.
- [x] `CONTRIBUTING.md` with setup, verification, pull request, and privacy guidance.
- [x] `CODE_OF_CONDUCT.md`.
- [x] `SECURITY.md`.
- [x] `PRIVACY.md`.
- [x] `SUPPORT.md`.
- [x] `THIRD_PARTY_NOTICES.md`.
- [x] GitHub issue templates.
- [x] GitHub pull request template.
- [x] GitHub Actions CI.
- [x] Dependabot configuration for JavaScript packages and GitHub Actions.

## Before Switching the Repository Public

- [ ] Confirm the copyright owner in `LICENSE` and `NOTICE`.
- [ ] Enable GitHub private vulnerability reporting.
- [ ] Replace the README preview image with a real screenshot or short GIF from the current app build, if preferred.
- [ ] Review git history for secrets, API keys, private prompts, generated confidential text, screenshots, and local path leaks.
- [ ] Confirm app identifiers, signing team, entitlements, and supported macOS versions.
- [ ] Decide whether public Discussions are enabled or issues remain the only support channel.
- [ ] Create initial labels for `bug`, `enhancement`, `documentation`, `dependencies`, `privacy`, `security`, `macos`, `web-composer`, and `good first issue`.
- [ ] Configure branch protection for `main`.
- [ ] Decide release artifact policy: source-only, unsigned local builds, signed notarized DMG, or another package format.
- [ ] Add a repository description, topics, website URL, and social preview image.

## Legal and Dependency Checks

- [ ] Review direct and transitive JavaScript dependencies for license compatibility.
- [ ] Review SwiftPM dependencies before adding any external packages.
- [ ] Keep third-party notices current if new dependencies require attribution.
- [ ] Confirm the app name, icon, and README media do not include third-party trademarks or private content.

## Privacy and Security Checks

- [ ] Re-run the privacy claims in `README.md` and `PRIVACY.md` against implementation behavior.
- [ ] Confirm API keys remain in Keychain and are never returned to Web snapshots.
- [ ] Confirm provider requests originate in native code, not the Web composer.
- [ ] Confirm clipboard writes require explicit user action.
- [ ] Confirm app anchors do not expose window titles or target-control contents.
- [ ] Confirm generated logs and troubleshooting docs do not ask users to paste secrets or private prompts publicly.

## CI and Release Checks

- [ ] Confirm GitHub Actions passes on a clean public clone.
- [ ] Confirm `swift test --package-path apps/macos/InputoModules` passes locally.
- [ ] Confirm the Xcode Debug build command passes locally.
- [ ] Confirm `pnpm --dir packages/web-composer run verify` passes locally when Web assets change.
- [ ] Document any required Xcode or macOS version pin before the first tagged release.

## Documentation Checks

- [ ] Walk a new contributor through `README.md`, `CONTRIBUTING.md`, and `docs/DEVELOPMENT.md`.
- [ ] Confirm every README link points to an existing file.
- [ ] Keep `docs/ARCHITECTURE.md` and `docs/NATIVE_EXECUTOR_CONTRACT.md` aligned with the bridge implementation.
- [ ] Keep `docs/ROADMAP.md` aligned with what the project is willing to accept from contributors.
