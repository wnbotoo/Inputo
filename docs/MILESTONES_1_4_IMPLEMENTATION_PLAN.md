# Milestones 1-4 Implementation Plan

This plan turns Milestones 1 through 4 from the roadmap into an ordered implementation sequence. It is intentionally written as a working plan, not as completion status. Code work should start only after this plan is reviewed and accepted.

## Goals

- Close Milestone 1 with repeatable runtime QA, documented diagnostics, and reliable macOS/WebView behavior.
- Close Milestone 2 with a polished daily composer loop: actionable errors, better states, keyboard flow, accessibility, and compact-panel quality.
- Close Milestone 3 with shared bridge contracts that are hard to drift between Swift, TypeScript, fixtures, and docs.
- Close Milestone 4 with native-executor UX for side-effecting tools, including confirmation, permission state, grant-scoped file access, cancellation, and policy tests.

## Non-Goals

- Do not build the Web Agent Planner from Milestone 5 yet.
- Do not add automatic paste, screenshots, window-title capture, browser-side provider networking, hosted Web assets, analytics, or telemetry.
- Do not enable `network.fetch` until a manifest-governed network policy and review UI exist.
- Do not move credentials, provider requests, clipboard writes, app activation, file grants, or OS permission prompts into Web code.
- Do not start release signing, notarization, or update infrastructure except where runtime hardening discovers a blocking release concern.

## Current Baseline

As of this plan, the project already has:

- macOS menu-bar app with floating composer.
- SwiftUI/AppKit shell and native settings.
- React + TypeScript Web composer loaded through `WKWebView`.
- Checked-in generated Web assets.
- Native bridge with versioned `tool.call`, `tool.result`, and event envelopes.
- OpenAI-compatible provider requests executed from native code.
- Keychain-backed API key storage.
- Manual Copy flow and app-level Jump anchors.
- File-grant DTOs and native file-tool services on the Swift side.
- Swift package tests, frontend tests, asset consistency check, and CI.

Recently verified commands:

```bash
swift test --package-path apps/macos/InputoModules
pnpm --dir packages/web-composer run verify
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Prioritization Model

Use these priorities across all four milestones:

| Priority | Meaning | Examples |
| --- | --- | --- |
| P0 | Must finish before declaring M1-M4 complete. These items protect the runtime, privacy boundary, contracts, or core user loop. | QA closure, contract drift checks, actionable provider setup errors, confirmation policy tests. |
| P1 | Should finish before broader daily use or external testing. These items improve polish, accessibility, maintainability, or operator confidence. | compact-panel polish, keyboard navigation, permission-state rendering, diagnostics UX. |
| P2 | Nice follow-up work that can remain after M1-M4 if explicitly deferred. | deeper localization rollout, advanced diagnostic export, broader UI visual refinements. |

Recommended implementation order:

1. P0 Runtime Closure for M1.
2. P0 Contract Foundation for M3.
3. P0 Composer Failure and Setup UX for M2.
4. P0 Native Side-Effect Confirmation for M4.
5. P1 Composer Keyboard, Accessibility, and Density.
6. P1 File-Grant UX and Permission-State Surfacing.
7. P1 Diagnostics and Documentation Closure.
8. P2 Polish and Deferred Enhancements.

This order keeps the app shippable at every step and avoids building M4/M5-style workflows on contracts that can drift.

## Phase 0: Planning and Baseline Lock

Priority: P0

Purpose: establish the exact baseline before implementation starts.

Tasks:

- Create a short tracking issue or local checklist for M1-M4 closure.
- Record current verification results for Swift, Web, Xcode build, and generated asset consistency.
- Confirm supported local test environment: macOS version, Xcode version, Node/pnpm versions, display setups available for QA.
- Decide whether milestone closure evidence lives in this document, `docs/DEVELOPMENT.md`, or a separate QA log.
- Confirm that no code changes for M1-M4 start until the implementation sequence is accepted.

Exit criteria:

- Baseline commands pass.
- Scope is accepted.
- QA evidence location is chosen.

## Phase 1: Milestone 1 Runtime Closure

Priority: P0

Goal: make the existing macOS runtime boringly reliable, with repeatable QA and documented known noise.

### 1.1 Bundle and WebView Runtime Verification

Tasks:

- Verify the composer renders from the SwiftPM resource bundle on a clean Xcode build.
- Confirm the app does not require a Vite dev server, `pnpm install`, or network access to render the production composer.
- Keep `index.html`, `composer.js`, and `composer.css` generated and checked in.
- Confirm production `index.html` uses a classic `defer` script tag and no `type="module"`.
- Confirm content security and WebView restrictions still block remote assets and browser-side networking.
- Add or refine tests if an existing runtime assumption is only covered manually.

Acceptance checks:

```bash
pnpm --dir packages/web-composer run verify
swift test --package-path apps/macos/InputoModules
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Manual QA:

- Launch the built app.
- Open the composer from the menu bar item.
- Confirm Web composer is visible without running `pnpm run dev`.
- Confirm draft editor receives focus.
- Confirm generated assets are loaded from the bundle path, not localhost.

### 1.2 Panel Placement, Focus, and Spaces

Tasks:

- Test composer opening on primary and secondary displays.
- Test after moving focus between displays.
- Test while another app is in full-screen Space.
- Test showing, hiding, and re-showing the panel repeatedly.
- Verify panel sizing remains stable at compact widths.
- Tighten native focus handoff if draft focus is inconsistent.
- Confirm Escape hides the panel only outside active IME composition.

Manual QA matrix:

| Scenario | Expected Result |
| --- | --- |
| Open from menu bar | Panel appears and draft is focused. |
| Open from configured shortcut | Panel appears and draft is focused. |
| Reopen after hide | Previous transient state is correct and focus returns. |
| Secondary display | Panel appears in a predictable location. |
| Full-screen Space | App behavior is documented and non-crashing. |
| Escape during normal editing | Composer hides. |
| Escape during CJK IME composition | Composer does not hide. |

Tests to consider:

- Swift tests for panel lifecycle are hard without UI infrastructure, so most coverage remains manual.
- Add unit coverage for state transitions discovered during QA, especially cancellation and reset behavior.

### 1.3 Appearance and Accessibility Baseline

Tasks:

- Verify light and dark appearance.
- Verify reduced-motion setting does not break the core loop.
- Add missing Web labels, roles, focus states, and status announcements.
- Confirm native buttons and menu items have accessibility names.
- Confirm status/error text is announced without creating noisy repeated announcements.

Manual QA:

- Navigate the core loop with keyboard only.
- Use VoiceOver lightly on the composer controls.
- Confirm button names are meaningful: Generate, Cancel, Clear, Copy, Settings, Jump anchors.
- Confirm field labels are meaningful: Draft, Instruction, Preset, Preview.

Acceptance criteria:

- Keyboard-only user can draft, select preset, generate, cancel, copy, clear, and open settings.
- Screen-reader labels exist for all controls in the core loop.
- Status changes are visible and display-safe.

### 1.4 Runtime Diagnostics and Log Policy

Tasks:

- Keep expected WebKit/Xcode log noise documented in `docs/DEVELOPMENT.md`.
- Decide whether the app needs an in-app diagnostics surface for v0.1.
- If diagnostics are added, keep them redacted and native-owned.
- Define what can appear in logs: safe error codes, provider configuration validity, and bridge tool names.
- Define what must never appear: API keys, prompt text, generated confidential text, local paths, stack traces with secrets, provider URLs with credentials.

Acceptance criteria:

- Harmless WebKit logs are documented.
- New diagnostics do not weaken privacy claims.
- Manual QA notes include observed runtime warnings when relevant.

M1 completion bar:

- All M1 acceptance checks pass.
- Manual QA evidence exists.
- Known runtime noise is documented.
- No regressions in privacy boundary.

## Phase 2: Milestone 3 Shared Bridge Contracts

Priority: P0

Goal: make bridge contracts reusable and hard to drift before expanding UX around native executor tools.

This phase is intentionally before most M4 work. M4 depends on reliable tool descriptors, policy metadata, payload types, and fixtures.

### 2.1 Create Shared TypeScript Bridge Package

Tasks:

- Create `packages/bridge-contracts-ts`.
- Move framework-agnostic bridge DTOs out of `packages/web-composer/src/shared/bridge/types.ts`.
- Export bridge version, envelope types, tool IDs, event names, context types, tool descriptors, snapshot types, and known payload/result DTOs.
- Keep React-only view state inside `packages/web-composer`.
- Update `packages/web-composer` imports to consume the shared package.
- Update workspace configuration so local package linking works with pnpm.

Package boundaries:

| Package | Owns |
| --- | --- |
| `packages/bridge-contracts-ts` | Versioned bridge DTOs, tool IDs, event names, payload/result interfaces, fixture helpers if needed. |
| `packages/web-composer` | Bridge client runtime wrapper, React state, UI components, Web-only tests. |
| `apps/macos/InputoModules/Sources/InputoCore` | Swift DTOs and native tool descriptors. |
| `contracts` | Language-neutral schemas and examples. |

Acceptance criteria:

- Web composer imports DTOs from the shared package.
- Shared package can typecheck independently.
- React-specific state is not moved into the shared package.

### 2.2 Contract Fixture and Drift Checks

Tasks:

- Decide the source of truth for each contract surface:
  - Bridge envelope shape: language-neutral fixtures and schema.
  - Tool IDs and policy metadata: Swift descriptors plus generated or checked fixtures.
  - Web DTO types: TypeScript package.
- Add fixtures for representative read-only and side-effect calls.
- Add tests that decode fixtures in Swift.
- Add tests that typecheck or validate fixtures in TypeScript.
- Add a script that compares known tool IDs/event names between Swift-generated output and TypeScript expectations, or uses shared JSON fixtures as the comparison point.
- Add the drift check to `pnpm run verify` or a top-level verification command.

Recommended first drift check:

- Generate or maintain a JSON fixture listing:
  - bridge version
  - tool IDs
  - event names
  - effect classes
  - minimum agent mode
  - explicit user action requirement
  - per-call confirmation requirement
  - cancellation support
  - streaming support
- Swift tests decode it and compare against `InputoNativeToolDescriptor.v1DefaultTools`.
- TypeScript tests import it and compare against exported literal unions.

Acceptance criteria:

- A changed tool ID, event name, or policy flag fails verification unless fixtures/types are updated intentionally.
- Swift and TypeScript both agree on bridge version and envelope shape.
- Contract changes require explicit fixture updates.

### 2.3 Contract Documentation

Tasks:

- Update `docs/NATIVE_EXECUTOR_CONTRACT.md` with the shared package location.
- Update `docs/PROJECT_STRUCTURE.md` from reserved package to active package.
- Update `docs/WEB_COMPOSER.md` to describe where DTOs live.
- Document versioning and deprecation rules:
  - additive fields are allowed when optional
  - removing or renaming fields requires a bridge version bump
  - changing side-effect policy requires fixture and privacy review
  - Web must tolerate unknown optional fields

Acceptance criteria:

- Documentation matches actual package layout.
- Contributors can tell where to add or update bridge types.

M3 completion bar:

- Shared TypeScript package exists.
- Web composer consumes it.
- Swift and TypeScript contract drift checks run in verification.
- Docs describe versioning and ownership.

## Phase 3: Milestone 2 Composer UX P0

Priority: P0

Goal: make the core transform loop understandable and useful without opening logs.

### 3.1 Provider Setup and Error Recovery

Tasks:

- Surface provider setup state from `app.snapshot` or `settings.summary`.
- Detect missing base URL, invalid base URL, missing model, and missing API key.
- Show a compact, actionable provider setup state inside the composer or native header.
- Add a visible way to open Settings when provider setup blocks generation.
- Ensure provider errors are display-safe and do not expose secrets, raw URLs with credentials, stack traces, or local paths.
- Make retry behavior clear after transient provider failures.

Error UX guidelines:

| Condition | User-Facing Behavior |
| --- | --- |
| Missing API key | Explain that provider credentials are needed and offer Settings. |
| Invalid provider URL | Explain provider URL is invalid and offer Settings. |
| Cannot find host | Explain the provider cannot be reached and suggest checking URL/network. |
| Provider returns failure | Show redacted provider failure message. |
| Empty draft | Disable Generate and keep status quiet or concise. |
| Empty provider output | Explain no output was returned. |

Acceptance criteria:

- A user can recover from provider setup problems from the composer.
- Common provider failures are understandable without Xcode logs.
- No secret-bearing data crosses into Web display.

### 3.2 Composer State Polish

Tasks:

- Improve empty preview state.
- Improve loading and streaming states.
- Improve failed, cancelled, copied, and cleared states.
- Avoid stale success messages after editing draft or instruction.
- Ensure Copy is enabled only when generated output exists.
- Ensure Clear behavior is predictable during and after generation.
- Ensure Cancel state cannot leave the UI stuck generating.

States to cover:

| State | Required Behavior |
| --- | --- |
| Empty | Draft focused, Generate disabled until draft has content. |
| Ready | Generate enabled, no alarming status text. |
| Streaming | Preview updates incrementally, Cancel available, Generate disabled. |
| Cancelled | Generation stops, status says cancelled, draft remains. |
| Failed | Error is visible, draft remains, Generate can retry when valid. |
| Completed | Preview remains, Copy enabled, status says ready/copyable. |
| Copied | Status confirms copy without auto-paste. |
| Cleared | Draft, instruction, preview, and transient status reset. |

Tests:

- Reducer tests for every state transition.
- Bridge-client or hook-level tests where feasible for failed tool calls.
- Swift tests for native composer snapshots if state semantics change.

Acceptance criteria:

- No common state requires guessing what happened.
- Editing after errors clears stale error state.
- Copy remains explicitly user-initiated.

### 3.3 Presets and Custom Preset Display

Tasks:

- Verify built-in recipe IDs are stable.
- Ensure selected recipe falls back safely if a saved custom preset is removed.
- Improve display of recipe names in compact width.
- Decide how custom presets are shown, ordered, and distinguished from built-ins.
- Keep recipe selection native-authoritative.

Acceptance criteria:

- Recipe selector handles built-in and custom presets without layout breakage.
- Removed or unavailable recipe does not break generation.

M2 P0 completion bar:

- Provider setup errors are actionable.
- Core state machine is polished and tested.
- Preset selection is resilient.

## Phase 4: Milestone 4 Native Executor UX P0

Priority: P0

Goal: make privileged native tools usable through visible user intent without weakening policy.

### 4.1 Confirmation Model

Tasks:

- Define confirmation UX for side-effecting tools.
- Keep confirmation native-mediated or native-approved; Web must not be able to self-certify elevated privileges invisibly.
- Decide how Web asks for confirmation:
  - Native confirmation sheet/dialog.
  - Web proposal UI followed by native confirmation.
  - Hybrid model where Web renders proposal but native validates policy and context.
- Define display text for each side-effect class:
  - clipboard write
  - app activation
  - permission prompt
  - file picker
  - file read
  - file write
  - future network
- Ensure `requiresPerCallConfirmation` means a fresh, visible confirmation for each call.

Policy requirement:

- `context.userAction` can mean a user clicked a visible control.
- `context.confirmed` must mean the user confirmed the specific side effect, not merely clicked a generic button.
- Web cannot bypass native policy by setting `confirmed: true` unless the confirmation flow has actually occurred.

Acceptance criteria:

- Side-effecting tools that require confirmation fail without confirmed context.
- Confirmed calls are tied to visible user intent.
- Tests cover missing user action, missing confirmation, wrong agent mode, and allowed confirmed execution.

### 4.2 Permission-State Surface

Tasks:

- Surface `permissions.status` in Web UI where useful.
- Keep details concise and display-safe.
- Show provider network, clipboard, app anchors, accessibility, screen recording, file read/write, network tools, and MCP tools states.
- Provide `permissions.request` UI only for permissions that can actually be requested in the current version.
- Keep unavailable/deferred permissions clearly marked without implying broken setup.

Acceptance criteria:

- User can understand why a native tool is unavailable.
- Deferred capabilities are not presented as broken.
- Permission UI does not encourage enabling screen recording or accessibility for the default flow.

### 4.3 File Grant UX

Tasks:

- Design read grant flow:
  - user chooses a file through native picker
  - native returns grant ID and safe display metadata
  - Web can request text read through grant ID
  - native enforces grant scope
- Design write grant flow:
  - user chooses save target through native save panel
  - native returns grant ID and safe display metadata
  - Web can write text through grant ID after confirmation
  - native enforces grant scope
- Avoid exposing arbitrary paths to Web.
- Define grant lifetime: session-only by default unless future persistence is explicitly designed.
- Add clear errors for missing grant, expired grant, unsupported file type, read failure, and write failure.

Acceptance criteria:

- Web never sends raw local paths as authority.
- Native picker/save panel mediates file authority.
- File read/write are test-covered and policy-checked.

### 4.4 Cancellation and Timeout Behavior

Tasks:

- Confirm `llm.cancel` cancels tracked generation reliably.
- Decide whether file tools need timeout or cancellation in M4.
- Add timeout behavior for long-running native tools where practical.
- Make cancellation results visible and display-safe.
- Avoid orphaned active request state after cancellation or timeout.

Acceptance criteria:

- Cancel cannot leave UI generating forever.
- Timed-out tools return safe errors.
- Active request tracking is cleaned up.

M4 P0 completion bar:

- Confirmation model exists and is enforced.
- Permission state is visible where it affects user decisions.
- File grants are user-mediated and grant-scoped.
- Cancellation/timeout behavior is defined for long-running tools.

## Phase 5: Milestone 2 UX P1

Priority: P1

Goal: make the composer feel like a polished daily tool.

Tasks:

- Improve keyboard navigation order and focus recovery.
- Verify Command-Return and Escape behavior across fields and IME composition.
- Add missing hover/focus/disabled states.
- Improve compact panel density without making controls jump.
- Ensure text fits at small panel sizes.
- Add screen-reader announcements for streaming completion and errors without excessive repetition.
- Decide localization strategy before adding many more strings:
  - string catalog in Swift for native
  - central string map in Web
  - no translation rollout required yet unless chosen
- Add reducer tests for edge cases:
  - late stream event after cancellation
  - duplicate completion events
  - error followed by edit
  - copy failure
  - clear during generation

Acceptance criteria:

- Keyboard-only core loop is comfortable.
- Compact panel does not clip important controls.
- UI strings have a clear future localization home.

## Phase 6: Milestone 1 and 4 Diagnostics P1

Priority: P1

Goal: provide enough local diagnostic clarity for QA and support without leaking data.

Tasks:

- Decide whether diagnostics are only documentation for now or an in-app view.
- If in-app:
  - show app version/build, bridge version, Web asset status, provider configured/not configured, permission states
  - do not show prompts, outputs, API keys, raw provider responses, or local paths
  - include copy diagnostics only if redacted
- Add tests for redaction helper if introduced.
- Update support documentation if diagnostics become user-facing.

Acceptance criteria:

- QA/support can identify setup/runtime categories without secrets.
- Privacy docs still match behavior.

## Phase 7: Documentation Closure

Priority: P0 for changed behavior, P1 for supporting polish

Tasks:

- Update `docs/ROADMAP.md` only when a milestone is actually complete.
- Update `docs/DEVELOPMENT.md` with the final manual QA checklist.
- Update `docs/WEB_COMPOSER.md` after shared package and UX behavior change.
- Update `docs/WEB_UI_ARCHITECTURE.md` after confirmation/permission surfaces are settled.
- Update `docs/NATIVE_EXECUTOR_CONTRACT.md` for bridge package, confirmation semantics, file grants, and versioning.
- Update `PRIVACY.md` if diagnostics, permissions, or file grant behavior changes user-facing privacy claims.
- Update README Current Scope only after user-visible capabilities are actually available.

Acceptance criteria:

- Docs describe current behavior, not intended behavior.
- Milestone completion status is not overstated.
- Privacy-sensitive changes are traceable.

## Verification Matrix

Run these for all meaningful M1-M4 slices:

```bash
swift test --package-path apps/macos/InputoModules
xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```

Run these for Web or bridge TypeScript changes:

```bash
pnpm --dir packages/web-composer run verify
```

After `packages/bridge-contracts-ts` exists, add its verification to the relevant package script and CI.

Manual QA required when affected:

| Area | Manual QA |
| --- | --- |
| Runtime/WebView | Launch app, open composer, verify bundled Web assets render. |
| Keyboard/IME | Draft typing, CJK IME, Escape, Command-Return. |
| Provider | Missing setup, invalid setup, streaming success, provider failure. |
| Clipboard | Copy only after generated output and explicit click. |
| Anchors | Refresh and activate app anchors without window titles. |
| Permissions | Permission states render accurately. |
| File grants | Picker/save panel mediated grants, read/write failures. |
| Appearance | Light/dark, compact panel, reduced motion. |
| Accessibility | Labels, roles, focus order, status announcements. |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Contract package becomes a dumping ground for React state | Keep only framework-agnostic DTOs in `bridge-contracts-ts`. |
| Web can fake confirmation by setting `confirmed: true` | Tie confirmation to a native-mediated or native-validated flow and test policy failures. |
| UX polish weakens privacy boundary | Review every new state/error/log against `PRIVACY.md` and `docs/ARCHITECTURE.md`. |
| File grant UX accidentally becomes path-based authority | Use grant IDs as authority and expose only safe display metadata. |
| QA remains informal and milestones are hard to close | Store QA evidence in a repeatable checklist with environment details. |
| M4 expands into M5 planner work | Limit M4 to tool UX, confirmation, permission state, grants, cancellation, and policy. |

## Suggested Milestone Closure Order

1. Close M1 after runtime QA and diagnostics policy are repeatable.
2. Build and close M3 so contracts are reliable before broader executor UX.
3. Close M2 P0/P1 core composer polish.
4. Close M4 side-effect confirmation, permission state, file grants, and cancellation/timeout semantics.
5. Update roadmap to mark M1-M4 complete only after evidence exists.

## Definition of Done for M1-M4

M1-M4 can be considered complete when all of the following are true:

- M1 manual QA checklist passes on the agreed environment.
- M2 core composer states are polished, tested, and recoverable.
- M3 shared TypeScript bridge package exists and contract drift checks run in verification.
- M4 side-effecting native tools have visible confirmation semantics, policy tests, and grant-scoped file access.
- Swift package tests pass.
- Xcode Debug build passes.
- Web verification passes.
- Generated Web assets match source when Web changes are included.
- Docs match actual behavior.
- Privacy review checklist passes.

## P1/P2 Implementation Notes

The P1/P2 slice keeps M1-M4 focused on runtime reliability, composer polish, shared contracts, and native-executor UX. The implemented P1/P2 work includes:

- request-scoped streaming guards so late events after cancellation, clear, or a different active request do not restore stale output
- focused reducer coverage for late stream events, duplicate completions, clear during generation, and removed preset fallback
- focused controller-helper coverage for provider setup, file-tool availability, and safe diagnostics summaries
- compact Web permission and runtime diagnostics surfaces driven by native snapshots
- centralized Web composer strings as the future localization home
- hover, focus-visible, disabled, compact-width, and inspector-detail styling refinements
- docs and privacy updates for current file-grant and diagnostics behavior

Explicitly deferred P2 work:

- translation rollout beyond the centralized string map
- advanced diagnostics export or copy flows, because those would add new clipboard/export behavior that needs separate native policy and privacy review
- manifest-governed network tools, MCP tools, autonomous planning, screenshots, window-title capture, and automatic paste
