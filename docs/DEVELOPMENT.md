# Development

This document describes the everyday development workflow for the current Inputo repository.

## Prerequisites

- macOS with Xcode and SwiftPM available on `PATH`.
- Node.js and npm for `packages/web-composer`.
- No CocoaPods, Carthage, XcodeGen, or project generator is used.

The app must build from checked-in sources without installing Web dependencies. Web dependencies are required only when editing or regenerating the composer assets.

## First Setup

```bash
cd /Users/wnbot/Projects/Inputo
npm install --prefix packages/web-composer
```

Open the app in Xcode:

```bash
open apps/macos/Inputo.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Daily Verification

Run these before committing changes that touch macOS, contracts, or generated Web assets:

```bash
swift test --package-path apps/macos/InputoModules
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Run this before committing Web composer source or bundled Web assets:

```bash
cd packages/web-composer
npm run verify
```

`npm run verify` typechecks, runs Vitest, rebuilds the production bundle, and confirms the checked-in app assets match the Web source.

## Web Composer Workflow

Start the Vite dev server when working on React UI:

```bash
cd packages/web-composer
npm run dev
```

Regenerate the assets used by the macOS app:

```bash
cd packages/web-composer
npm run build
```

The build writes to:

```text
apps/macos/InputoModules/Sources/InputoComposerFeature/Resources/WebComposer
```

Do not edit generated `composer.js`, `composer.css`, or generated `index.html` by hand. Edit files under `packages/web-composer/src` or `packages/web-composer/index.html`, then run `npm run build`.

## Manual QA Checklist

For macOS runtime changes, verify:

- the menu bar item opens the composer
- the configured global shortcut toggles the composer
- the Web composer is visible and focused
- typing and paste work in the draft editor
- Chinese/Japanese/Korean IME composition does not close the panel on Escape
- Command-Return starts generation
- streaming preview appears incrementally
- Cancel stops the active generation
- Copy writes only the generated preview after explicit user action
- Clear resets the composer state
- app anchors refresh and activate apps without showing window titles
- settings save provider config and API key correctly
- dark and light appearances render legibly
- no input/output history is persisted

## Troubleshooting

Blank Web composer:

- Run `cd packages/web-composer && npm run build`.
- Confirm `apps/macos/InputoModules/Sources/InputoComposerFeature/Resources/WebComposer/index.html` contains `<script defer src="./composer.js"></script>`.
- Confirm it does not contain `type="module"` in the production asset. The bundled WKWebView runtime uses a classic script tag for local-file compatibility.
- Rebuild the app with `xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`.
- If Xcode keeps old resources, clean DerivedData for Inputo or change `-derivedDataPath`.

SwiftPM cache errors after moving directories:

```bash
swift package --package-path apps/macos/InputoModules clean
swift test --package-path apps/macos/InputoModules
```

Web assets out of sync:

```bash
cd packages/web-composer
npm run build
npm run check:assets
```

Expected WebContent logs:

When running the macOS app from Xcode, the `WebContent` helper process may print sandbox-related warnings from system frameworks. These messages are expected when the composer renders correctly and the app does not crash:

| Log fragment | Meaning |
| --- | --- |
| `Missing com.apple.linkd.application-service / com.apple.linkd.autoShortcut mach-lookup entitlement` | WebKit or linked system frameworks attempted to register with LinkDaemon/App Intents services that third-party WebContent processes are not entitled to use. Inputo does not need these entitlements. |
| `Error registering app with intents framework` | Follow-on App Intents registration failure from the same system-service lookup. Harmless for the current app. |
| `AudioComponentRegistrar ... Operation not permitted` | The WebContent process probed audio component registration. Inputo's composer does not use audio, so this is noise unless audio features are added later. |
| `Sandbox is preventing this process from reading networkd settings file` | The WebContent sandbox cannot read global networkd preferences. The composer does not perform browser-side networking; provider requests are native. |
| `Unable to hide query parameters from script (missing data)` | WebKit privacy/logging message. The bundled composer uses local relative assets and does not depend on query parameters. |
| `WebProcess::markAllLayersVolatile: Failed to mark layers as volatile` | WebKit layer memory-management warning. It is not actionable unless paired with rendering glitches or crashes. |

Do not add private Apple entitlements or loosen the sandbox to silence these logs. Investigate only if the Web composer is blank, resources fail to load, provider requests fail, or the app crashes.

## Commit Hygiene

Keep generated Web assets in the same commit as the Web source that produced them. Keep platform behavior, contract changes, and documentation updates together when they change the same boundary. Ignored build artifacts such as `.build/`, `apps/macos/InputoModules/.build/`, and `packages/web-composer/node_modules/` should not be committed.
