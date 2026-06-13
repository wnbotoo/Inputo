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
| `file.pickReadGrant` | Open a native picker and create a read grant. | User-mediated file grant |
| `file.readText` | Read text through an existing grant. | Grant-scoped file read |
| `file.pickWriteGrant` | Open a native save panel and create a write grant. | User-mediated file grant |
| `file.writeText` | Write text through an existing grant. | Grant-scoped file write |
| `network.fetch` | Reserved and currently denied. | Disabled |

## Events

| Event | Meaning |
| --- | --- |
| `llm.started` | Native accepted a generation request. |
| `llm.delta` | Streaming text delta. |
| `llm.completed` | Generation completed successfully. |
| `llm.failed` | Generation failed with a display-safe message. |
| `llm.cancelled` | Generation was cancelled. |

Events may include a `requestID`. Web ignores events for a different active request.

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
- Bridge dispatcher: `apps/macos/InputoModules/Sources/InputoComposerFeature/Bridge/InputoNativeBridgeDispatcher.swift`
- WKWebView host boundary: `apps/macos/InputoModules/Sources/InputoComposerFeature/Bridge/InputoNativeBridgeHost.swift`
- Web bridge client: `packages/web-composer/src/shared/bridge/bridgeClient.ts`
- Web bridge types: `packages/web-composer/src/shared/bridge/types.ts`
