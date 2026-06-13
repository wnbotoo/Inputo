# Native Executor Contract

The native executor contract is the boundary between the Web composer and privileged native capabilities. Web can request allowlisted tools. Native validates policy, executes platform work, and returns display-safe results.

## Envelope Format

Web sends a `tool.call` envelope:

```json
{
  "version": 1,
  "id": "request-id",
  "type": "tool.call",
  "tool": "llm.stream",
  "payload": {},
  "context": {
    "userAction": true,
    "confirmed": false
  }
}
```

Native returns a `tool.result` envelope:

```json
{
  "version": 1,
  "id": "request-id",
  "type": "tool.result",
  "ok": true,
  "payload": {}
}
```

Failures are display-safe:

```json
{
  "version": 1,
  "id": "request-id",
  "type": "tool.result",
  "ok": false,
  "error": {
    "code": "permission_denied",
    "message": "This action requires explicit user confirmation.",
    "field": null,
    "retryable": false
  }
}
```

Native-to-Web streaming uses `event` envelopes delivered through the same receiver channel.

## Tool Policy

Each native tool has policy metadata:

- side-effect class
- minimum agent mode
- explicit user action requirement
- per-call confirmation requirement
- cancellation support
- streaming support

Web cannot choose its own privileges. The dispatcher enforces policy before calling `AppState` or platform services.

For tools marked with per-call confirmation, Web may indicate that a call came from a visible user action, but it cannot self-certify confirmation. The native dispatcher invokes a native confirmation service before execution. In the live macOS app this is a native alert; tests inject allow/deny confirmation services.

## Composer Tools

| Tool | Purpose | Side effect |
| --- | --- | --- |
| `tools.list` | Return available native tool descriptors. | Read-only |
| `app.snapshot` | Return native state needed to render the composer. | Read-only |
| `app.hideComposer` | Hide the floating composer. | UI side effect |
| `composer.getState` | Return current composer state. | Read-only |
| `composer.setDraft` | Update native draft text. | Composer state |
| `composer.setInstruction` | Update native instruction text. | Composer state |
| `composer.selectRecipe` | Select a transform recipe. | Composer state |
| `composer.clear` | Clear draft, instruction, preview, and transient status. | Composer state |
| `llm.chat` | Run a non-streaming provider transform. | Provider request |
| `llm.stream` | Run a streaming provider transform. | Provider request |
| `llm.cancel` | Cancel a tracked generation request. | Cancellation |
| `clipboard.copyGeneratedOutput` | Copy generated output to the clipboard. | Clipboard write |
| `appAnchors.list` | Return app-level anchors. | Read-only |
| `appAnchors.activate` | Activate an app anchor. | App activation |
| `settings.summary` | Return non-secret settings summary. | Read-only |
| `settings.open` | Open the native settings window. | UI side effect |
| `permissions.status` | Return current permission/capability state. | Read-only |
| `permissions.request` | Ask native to request a supported permission. | Permission prompt |
| `files.pickReadable` | Open a native picker and create a read grant. | User-mediated file grant |
| `files.readText` | Read text through an existing grant. | Grant-scoped file read |
| `files.pickWritable` | Open a native save panel and create a write grant. | User-mediated file grant |
| `files.writeText` | Write text through an existing grant. | Grant-scoped file write |
| `network.fetch` | Reserved and currently denied. | Disabled |

## Events

| Event | Meaning |
| --- | --- |
| `llm.started` | Native accepted a generation request. |
| `llm.delta` | Streaming text delta. |
| `llm.completed` | Generation completed successfully. |
| `llm.failed` | Generation failed with a display-safe message. |
| `llm.cancelled` | Generation was cancelled. |

Events may include a `requestID`. Web ignores events for a different active request and for requests that are no longer active after cancellation, clear, or completion.

## Snapshot Privacy

`app.snapshot` exposes enough state to render the composer but does not expose:

- API keys
- window titles
- screenshots
- target-control contents
- input or output history
- arbitrary file paths outside explicit grants

## File Grants

File tools are grant-based. Web does not send arbitrary local paths to native. A grant is created by a native picker or save panel, then used by a later grant-scoped read or write call.

This keeps file access user-mediated and lets each platform implement its own permission model.

The current Web composer can request a readable text grant and load the resulting text into the draft, or request a writable text grant and save the generated preview. The bridge result includes safe display metadata such as display name, content type, byte count, and grant ID; local paths remain native-owned.

## Drift Checks

Tool descriptors and event names are mirrored in `contracts/bridge-tools.v1.json`. Swift tests decode that fixture and compare it with `InputoNativeToolDescriptor.v1DefaultTools`; Web tests compare the same fixture with `packages/bridge-contracts-ts`. Contract changes should update Swift DTOs, TypeScript DTOs, fixtures, and docs together.

## Error Codes

Common safe error codes include:

- `unsupported_version`
- `unknown_tool`
- `invalid_payload`
- `duplicate_request_id`
- `permission_denied`
- `cancelled`
- `provider_unavailable`
- `provider_failed`
- `internal_error`

Native errors should be redacted before crossing the bridge. Provider URLs, API keys, stack traces, and OS-specific sensitive details should not be sent to Web.

## Implementation Locations

- DTOs and tool descriptors: `apps/macos/InputoModules/Sources/InputoCore/Models/NativeExecutorContract.swift`
- Shared TypeScript bridge contracts: `packages/bridge-contracts-ts/src/index.ts`
- Bridge descriptor fixture: `contracts/bridge-tools.v1.json`
- Bridge dispatcher: `apps/macos/InputoModules/Sources/InputoComposerFeature/Bridge/InputoNativeBridgeDispatcher.swift`
- WKWebView host boundary: `apps/macos/InputoModules/Sources/InputoComposerFeature/Bridge/InputoNativeBridgeHost.swift`
- Web bridge client: `packages/web-composer/src/shared/bridge/bridgeClient.ts`
- Web composer bridge drift test: `packages/web-composer/src/shared/bridge/contractDrift.test.ts`
