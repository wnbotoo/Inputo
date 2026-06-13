# Runtime QA Checklist

Use this checklist when closing Milestone 1 runtime hardening work or when a change affects the macOS shell, WebView host, bridge, provider flow, clipboard, anchors, permissions, or file grants.

## Environment Record

Record these before running manual QA:

- Date:
- macOS version:
- Xcode version:
- Inputo branch/commit:
- Display setup:
- Appearance:
- Reduced Motion:
- Provider used:
- Notes:

## Required Automated Checks

```bash
swift test --package-path apps/macos/InputoModules
pnpm --dir packages/web-composer run verify
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Latest local verification for the P1/P2 composer and diagnostics slice:

- Date: 2026-06-13
- Branch: `codex/m1-m4-p0`
- `CI=true pnpm --dir packages/web-composer run verify`: passed
- `swift test --package-path apps/macos/InputoModules`: passed, 40 tests
- `xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`: passed
- Browser static asset check at `http://127.0.0.1:5174`: desktop 1280x720 and narrow 390x720 passed with no horizontal overflow, stable draft height, and Runtime inspector closed/open states within viewport

## Runtime Checks

| Area | Check | Expected Result | Result |
| --- | --- | --- | --- |
| Bundle | Launch built app without Vite dev server. | Web composer renders from bundled assets. | |
| Menu bar | Open composer from menu bar item. | Panel appears and draft is focused. | |
| Shortcut | Toggle composer with configured shortcut. | Panel opens and closes predictably. | |
| Focus | Reopen after hiding. | Draft focus returns without stale selection issues. | |
| Displays | Open on primary and secondary displays. | Panel placement is predictable and non-crashing. | |
| Spaces | Use while another app is full-screen. | Behavior is documented and non-crashing. | |
| Appearance | Test light and dark modes. | Text and controls remain legible. | |
| Motion | Test with Reduce Motion enabled. | Core loop still works. | |
| IME | Compose CJK text and press Escape during composition. | Composition is not cancelled by hiding the panel. | |
| Keyboard | Press Command-Return from editor fields. | Generation starts only when draft and provider setup are valid. | |
| Provider | Test missing key, invalid model, network failure, and success. | Errors are actionable and display-safe. | |
| Streaming | Generate with streaming provider. | Preview updates incrementally and completes cleanly. | |
| Cancel | Cancel active generation. | UI exits generating state and late results are ignored. | |
| Copy | Click Copy after generation. | Only generated preview is copied after explicit action. | |
| Clear | Clear during and after generation. | Draft, instruction, preview, and transient status reset. | |
| Anchors | Refresh and activate anchors. | App switches without exposing window titles or screenshots. | |
| File grants | In assisted mode, read and write text through native grants. | Web receives grant-scoped results without local paths. | |
| Runtime diagnostics | Open the Runtime disclosure in the composer. | Only bridge version, asset status, provider configured/not configured, mode, tool count, and permission labels/details appear. | |
| Accessibility | Navigate core loop by keyboard and inspect labels with VoiceOver. | Controls have meaningful names and status is announced politely. | |
| Logs | Review Xcode/WebKit logs. | Only documented harmless noise appears. | |

## Privacy Checks

- API keys are not visible in Web state, bridge payloads, errors, or logs.
- Provider requests originate from native code.
- Browser-side `fetch`, WebSocket, service worker, localStorage, sessionStorage, and IndexedDB remain unused in the bundle.
- File authority is represented by native grant IDs, not arbitrary Web-provided paths.
- Runtime diagnostics do not show prompts, generated output, API keys, provider URLs, local paths, screenshots, raw provider responses, or stack traces.
- Clipboard writes require explicit Copy action.
- App anchors do not expose window titles, screenshots, or target-control contents.
