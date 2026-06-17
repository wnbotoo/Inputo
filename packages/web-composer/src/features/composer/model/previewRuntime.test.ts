import { describe, expect, it } from "vitest";
import {
  buildIsolatedDocument,
  normalizePreviewPayload,
  previewPayloadFromCommand,
  renderMarkdownToSafeHTML
} from "./previewRuntime";

describe("previewRuntime", () => {
  it("parses typed preview commands", () => {
    const payload = previewPayloadFromCommand({
      commandName: "preview",
      inputText: "/preview ```html\n<h1>Hello</h1>\n```",
      bodyText: "```html\n<h1>Hello</h1>\n```",
      arguments: ["```html", "<h1>Hello</h1>", "```"]
    });

    expect(payload?.kind).toBe("document");
    expect(payload?.content).toBe("<h1>Hello</h1>");
    expect(payload?.capabilities.allowScripts).toBe(true);
    expect(payload?.capabilities.allowNetwork).toBe(false);
  });

  it("normalizes explicit preview payload JSON and disables network", () => {
    const payload = normalizePreviewPayload({
      kind: "document",
      content: "<script>fetch('/x')</script>",
      capabilities: {
        allowInlineStyles: true,
        allowScripts: true,
        allowDataImages: true,
        allowNetwork: true
      }
    });

    expect(payload?.capabilities.allowScripts).toBe(true);
    expect(payload?.capabilities.allowNetwork).toBe(false);
  });

  it("renders common markdown to safe HTML", () => {
    const html = renderMarkdownToSafeHTML("# Title\n\n- **One**\n- `Two`");

    expect(html).toContain("<h1>Title</h1>");
    expect(html).toContain("<strong>One</strong>");
    expect(html).toContain("<code>Two</code>");
  });

  it("injects restrictive CSP and bridge hardening into isolated documents", () => {
    const document = buildIsolatedDocument({
      kind: "document",
      content: "<html><head><base href=\"https://example.com\"></head><body><h1>Hi</h1></body></html>",
      title: "Doc",
      capabilities: {
        allowInlineStyles: true,
        allowScripts: true,
        allowDataImages: true,
        allowNetwork: false
      }
    }, "dark");

    expect(document).toContain("connect-src 'none'");
    expect(document).toContain("Object.defineProperty(window, \"fetch\"");
    expect(document).toContain("Object.defineProperty(window, \"webkit\"");
    expect(document).not.toContain("<base");
    expect(document).toContain("theme-dark");
  });
});
