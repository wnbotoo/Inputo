# Inputo Web Composer

This document records the current Web composer body implementation and the boundary it must keep.

## Current Status

The composer body is rendered by a bundled `WKWebView` surface. Phase 4 now uses React, TypeScript, and Vite as the source workspace for the Web composer body while preserving the Phase 3 native host and runtime security boundary.

Native still owns:

- app lifecycle
- menu bar and global hotkey
- floating panel sizing, placement, focus, and Escape handling
- native header
- Settings entry and settings window
- Jump anchors and app activation
- Keychain, clipboard, provider network, file grants, and platform permissions

Web owns only the composer body presentation:

- preview
- recipe picker
- instruction field
- draft editor
- Generate, Cancel, Clear, and Copy controls
- status and error text
- streaming output rendering

The Web body is the only composer body. The previous native SwiftUI composer body was removed after the Web host landed. If bundled Web assets are missing, native shows a small missing-assets error state instead of falling back to a parallel native composer UI.

## Files

Swift host:

- `InputoModules/Sources/InputoComposerFeature/UI/InputoWebComposerView.swift`
- `InputoModules/Sources/InputoComposerFeature/Bridge/InputoWebComposerAssets.swift`
- `InputoModules/Sources/InputoComposerFeature/UI/ComposerView.swift`

Static assets:

- `InputoModules/Sources/InputoComposerFeature/Resources/WebComposer/index.html`
- `InputoModules/Sources/InputoComposerFeature/Resources/WebComposer/composer.css`
- `InputoModules/Sources/InputoComposerFeature/Resources/WebComposer/composer.js`

SwiftPM bundles the assets through `InputoModules/Package.swift`.

Web source workspace:

- `WebComposer/package.json`
- `WebComposer/vite.config.ts`
- `WebComposer/src/App.tsx`
- `WebComposer/src/bridge`
- `WebComposer/src/state`
- `WebComposer/src/styles/composer.css`
- `WebComposer/src/__tests__`

## Packaging

Phase 4 introduces React + TypeScript + Vite as source tooling for the Web composer. The app runtime still uses checked-in static HTML, CSS, and JavaScript assets loaded from the SwiftPM resource bundle.

Xcode and SwiftPM builds must remain independent of Node, `npm install`, network access, and frontend dev servers. Frontend builds are explicit developer or CI commands:

```bash
cd WebComposer
npm install
npm run typecheck
npm test
npm run build
```

`npm run build` regenerates the production assets in `InputoModules/Sources/InputoComposerFeature/Resources/WebComposer`.

## Bridge Boundary

Web-to-native messages must go through:

- `InputoNativeBridgeHost`
- `InputoNativeBridgeMessageHandling`

Native-to-Web events must go through:

- `InputoBridgeEventEmitter`

The Web surface must not call arbitrary native APIs. All privileged behavior is expressed as allowlisted bridge tools.

Current composer-relevant tools include:

- `app.hideComposer`
- `app.snapshot`
- `composer.setDraft`
- `composer.setInstruction`
- `composer.selectRecipe`
- `composer.clear`
- `llm.stream`
- `llm.cancel`
- `clipboard.copyGeneratedOutput`

Side-effecting user actions, such as Generate, Escape-to-hide, Clear, and Copy, include explicit user-action context in the bridge request.

## Network Policy

Web-side networking is disabled.

The static page uses a restrictive Content Security Policy, including:

- `connect-src 'none'`
- `script-src 'self'`
- `object-src 'none'`
- `frame-src 'none'`
- `worker-src 'none'`

The WK host also installs a `WKContentRuleList` that blocks `http://` and `https://` resource loads.

Provider calls, future manifest-governed network tools, file access, clipboard writes, and app activation must stay native-hosted.

## Storage Policy

The WK host uses `WKWebsiteDataStore.nonPersistent()`.

The Web assets should not use:

- `localStorage`
- `sessionStorage`
- IndexedDB
- Cache API
- cookies
- persistent input or generation history

The v1 posture remains: no input history, no generated-output history, no screenshots, no window-title capture, no automatic paste.

## Theme

Native forwards the current SwiftUI `colorScheme` into Web at document start and whenever it changes.

Web reads the theme from:

- `window.InputoInitialTheme`
- `window.InputoNativeThemeSet(theme)`
- `document.documentElement.dataset.theme`

CSS should prefer explicit `[data-theme="light"]` and `[data-theme="dark"]` tokens, with `prefers-color-scheme` only as a fallback for static inspection outside the app.

## Native Material Fit

The native panel uses translucent macOS material, so the Web body must not paint a solid page background or large opaque white panels.

- `html`, `body`, the `WKWebView`, and the WebKit scroll view stay transparent; the host disables WK background drawing when the platform exposes that setting.
- Composer fields are transparent by default so the native material remains visible behind them.
- The preview and preset rows may use a subtle translucent rounded surface to restore hierarchy without becoming an opaque Web background.
- Form controls opt out of default WebKit white backgrounds where needed.
- Rounded corners should reveal the native material, not a WebView page background.

## Phase 3 Completion

Implemented:

- bundled local static assets
- minimal WKWebView host
- non-persistent WebKit data store
- bundled-file navigation restriction
- host-level remote content blocking
- Web-to-native bridge wiring
- native-to-Web event forwarding
- Web body as the only composer body
- native Settings and Jump anchors
- system light/dark theme propagation
- transparent Web body that preserves native panel material
- IME-aware Escape handling through Web-to-native `app.hideComposer`
- Swift package tests and Xcode build coverage

Manual runtime QA covered before moving to Phase 4:

- initial focus into the Web draft editor
- draft retention while reopening the panel
- Chinese IME composition and Return-as-newline behavior
- IME-aware Escape handling and non-IME Escape-to-hide behavior
- Command-Return generation
- Command-A/C/V/Z editing shortcuts in the draft editor
- dark/light switching while the panel is open
- provider-backed generation and preview output
- no local input/output history persistence beyond transient in-memory composer state
- native material fit, transparent WebView background, rounded surface polish, and accepted visual treatment

Keep broader panel sizing across displays and Spaces in the normal regression checklist.

## Phase 4 Initial Landing

Phase 4 adds a React + TypeScript + Vite source workspace for the Web composer while keeping the same production runtime shape:

- bundled local static assets loaded by the existing `WKWebView` host
- no React/Vite requirement in the Xcode app target
- no network access from the WebView
- no browser storage for input or generated output history
- Web-to-native calls only through `InputoNativeBridgeHost` / `InputoNativeBridgeMessageHandling`
- native-to-Web events only through `InputoBridgeEventEmitter`
- native Settings, Jump anchors, panel behavior, provider networking, clipboard, Keychain, file grants, and permissions remain native
- typed TypeScript bridge client and reducer tests cover request/response plumbing and streaming state transitions

The richer Web agent planner remains a later phase.

## Verification

Run before handoff:

```bash
swift test --package-path InputoModules
xcodebuild -project Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```
