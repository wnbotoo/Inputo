# Contributing to Inputo

Thanks for helping make Inputo better. This project is a privacy-conscious macOS app for system-wide AI text composition, so contributions should keep OS privileges native, user intent explicit, and data retention minimal.

## Ways to Contribute

- Fix bugs in the macOS app, Swift package modules, Web preview, bridge contracts, or documentation.
- Improve accessibility, keyboard support, IME behavior, and provider error states.
- Add tests or fixtures that make native/Web contract drift harder.
- Propose product changes through an issue before implementing large behavior changes.

## Ground Rules

- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- Report vulnerabilities through [SECURITY.md](SECURITY.md), not public issues.
- Keep API keys, prompts, generated text, logs with secrets, screenshots of private content, and local file paths out of issues and pull requests.
- Preserve Inputo's current privacy defaults: no input/output history, no automatic paste, no screenshot capture, no window-title capture, and no browser-side provider networking.
- Contributions intentionally submitted to this repository are licensed under the [Apache License 2.0](LICENSE), unless you clearly mark them as "Not a Contribution."

## Development Setup

Prerequisites:

- macOS with Xcode and SwiftPM on `PATH`.
- Node.js and pnpm 11 when editing `packages/web-composer`.

Install Web preview dependencies only if you need to edit or regenerate the Web assets:

```bash
pnpm --dir packages/web-composer install
```

Open the app in Xcode:

```bash
open apps/macos/Inputo.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Verification

Run these before opening a pull request that touches macOS code, contracts, generated Web assets, or documentation around those areas:

```bash
swift test --package-path apps/macos/InputoModules
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Run this before opening a pull request that touches the Web preview:

```bash
pnpm --dir packages/web-composer run verify
```

`pnpm run verify` typechecks TypeScript, runs Vitest, rebuilds the production bundle, and checks that bundled assets are in sync.

## Pull Request Checklist

- Keep changes focused. Split unrelated product, docs, and refactor work into separate pull requests.
- Update tests or explain why a change is docs-only or not practically testable.
- Update `docs/` and `README.md` when commands, paths, privacy boundaries, architecture, or user workflows change.
- Commit generated Web assets with the Web source that produced them.
- Include manual QA notes for UI, permission, clipboard, provider, anchor, or bridge behavior.
- Do not add CocoaPods, Carthage, XcodeGen, or another project generator unless the project policy changes first.

## Architecture Notes

Inputo uses a thin Xcode app target and a local Swift package:

- `InputoCore`: pure contracts, recipes, provider config, and provider client logic.
- `InputoMacPlatform`: macOS services such as Keychain, clipboard, anchors, hotkeys, and settings.
- `InputoComposerFeature`: composer UI, settings UI, app state, bridge dispatcher, and WKWebView host.
- `packages/web-composer`: React + TypeScript source for the bundled Web preview.

Start with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md), and [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing module boundaries.
