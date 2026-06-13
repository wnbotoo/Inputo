# M5 Handover Prompt

Use this prompt to start a fresh Codex conversation for Milestone 5.

```text
继续开发 Inputo，仓库路径是 /Users/wnbot/Projects/Inputo。

当前上下文：

- 当前工作基线在分支 codex/m1-m4-p0。
- M1-M4 的工程实现已完成：
  - M1 runtime hardening: bundled WebComposer assets, WKWebView restrictions, CI/runtime checks, expected WebKit log docs, QA checklist.
  - M2 composer UX: actionable provider setup, polished generate/cancel/copy/clear states, compact UI, keyboard/IME/accessibility polish, stale stream event guards.
  - M3 shared bridge contracts: packages/bridge-contracts-ts, contracts/bridge-tools.v1.json, Swift/Web drift checks.
  - M4 native executor UX: native-mediated confirmation, permission state surfacing, grant-scoped file read/write UX, cancellation/policy tests.
- M1-M4 formal closure still needs real macOS manual QA using docs/MILESTONE_RUNTIME_QA.md, but implementation and automated verification passed.
- Recent verification that passed:
  - CI=true pnpm --dir packages/web-composer run verify
  - swift test --package-path apps/macos/InputoModules
  - xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
- Generated Web assets are checked in under apps/macos/InputoModules/Sources/InputoComposerFeature/Resources/WebComposer and must stay committed with matching source changes.

Start Milestone 5: Web Agent Planner.

Goal:

Let Web orchestrate visible multi-step workflows while native remains the policy-enforcing executor.

M5 P0 scope:

1. Add an activity timeline model in Web for generation, tool proposals, approvals/rejections, safe tool results, failures, cancellation, and stale events.
2. Add tool proposal and approval state in Web. A privileged native action must remain a proposal until the user acts and native policy allows it.
3. Coordinate existing llm.stream flow with planner/timeline state without breaking manual transform mode.
4. Add renderer slots for safe tool results.
5. Define safe pure-Web tools separately from privileged native tools.
6. Preserve request ordering, cancellation behavior, late-event handling, and display-safe errors.

Important non-goals for the first M5 slice:

- Do not enable autonomous background execution.
- Do not enable network.fetch.
- Do not add MCP or connector execution.
- Do not add screenshots, window-title capture, automatic paste, browser-side provider networking, or prompt/output persistence.
- Do not move credentials, provider requests, clipboard writes, app activation, file grants, OS permission prompts, hotkeys, or settings persistence into Web code.

Files and docs to read first:

- docs/ROADMAP.md
- docs/WEB_UI_ARCHITECTURE.md
- docs/WEB_COMPOSER.md
- docs/NATIVE_EXECUTOR_CONTRACT.md
- PRIVACY.md
- packages/bridge-contracts-ts/src/index.ts
- packages/web-composer/src/features/composer/model/composerReducer.ts
- packages/web-composer/src/features/composer/hooks/useComposerController.ts
- packages/web-composer/src/features/composer/components/ComposerScreen.tsx
- apps/macos/InputoModules/Sources/InputoComposerFeature/Bridge/InputoNativeBridgeDispatcher.swift

Implementation guidance:

- Start with a short M5 implementation plan before coding if the scope is still broad.
- Prefer small, testable slices:
  1. Web planner/timeline data model and reducer tests.
  2. Composer controller integration with existing llm.stream events.
  3. Proposal UI for native tools that does not bypass native confirmation.
  4. Documentation and generated assets.
- Keep React-only UI state in packages/web-composer.
- Keep framework-agnostic bridge DTOs in packages/bridge-contracts-ts only when they are true contracts.
- Use native bridge descriptors and permission snapshots as authority for privileged tools.
- Web can render proposals and user intent, but native remains responsible for policy and per-call confirmation.

Verification before committing:

- CI=true pnpm --dir packages/web-composer run verify
- swift test --package-path apps/macos/InputoModules
- xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
- Browser/static asset check for meaningful Web UI changes, including compact width.

Please inspect git status first. Do not overwrite unrelated user changes.
```
