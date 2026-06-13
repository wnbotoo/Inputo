# Privacy

Inputo is designed around a small data surface: you open a local composer, send selected text to an OpenAI-compatible provider you configure, manually copy the result, and return to another app through app-level anchors.

This document describes the intended privacy boundary for the current macOS app. It should be updated whenever implementation behavior changes.

## Summary

- Inputo does not store input history or generated output history.
- Inputo does not capture screenshots, window titles, target-control contents, or arbitrary app content.
- Provider API keys are stored through the platform credential store, currently macOS Keychain.
- The bundled Web composer does not receive API keys and does not make provider requests directly.
- Clipboard writes happen only after an explicit user action.
- App anchors are app-level jump targets, not document or control-level surveillance.

## Data You Provide

You may enter or paste draft text and instructions into the composer. When you generate output, Inputo sends the prompt content needed for that request to the configured OpenAI-compatible provider.

Do not send secrets, regulated data, or confidential third-party content to a provider unless you have reviewed that provider's terms, retention policy, and security posture.

## Provider Configuration

Inputo stores provider settings locally. API keys are stored in Keychain and are not exposed to the Web composer through snapshots, bridge calls, logs, or settings summaries.

The configured provider receives generation requests. Inputo cannot control the provider's server-side logging, retention, training, or abuse-monitoring behavior.

## Local Web Composer

The composer body is bundled static HTML, CSS, and JavaScript loaded into `WKWebView` from local app resources. It is not a hosted web application.

The Web composer owns UI state and user interaction. Native code owns credentials, provider networking, clipboard writes, app anchors, permissions, file grants, and settings persistence.

## Clipboard and App Activation

Inputo does not paste automatically. Copying generated output requires an explicit user action. App anchors activate applications at the app level and are designed to avoid collecting window titles or target-control content.

## File Access

File tools are grant-scoped. Web code must not send arbitrary local paths to native code. A grant is created through a native picker or save panel before file read or write tools can operate. Web receives grant IDs and safe display metadata such as a display name, content type, and byte count; local paths remain native-owned.

## Diagnostics

The composer can show a compact local diagnostics summary for QA and support. It is limited to safe setup and contract metadata such as bridge version, bundled-asset state, provider configured/not configured, agent mode, tool count, and permission labels.

Diagnostic output must avoid secrets, prompts, generated text, provider URLs, local paths, screenshots, raw provider responses, and stack traces that reveal sensitive user data. Public issues and pull requests should use redacted examples.

## Security Reports

If you find a privacy or security issue, follow [SECURITY.md](SECURITY.md). Please do not post exploit details or sensitive user data in public issues.
