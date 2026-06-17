import type {
  CommandReceivedPayload,
  PreviewPayload,
  PreviewPayloadCapabilities,
  PreviewPayloadKind,
  PreviewPayloadMetadata
} from "@inputo/bridge-contracts";

const KIND_ALIASES: Record<string, PreviewPayloadKind> = {
  text: "text",
  plain: "text",
  md: "markdown",
  markdown: "markdown",
  html: "html",
  safehtml: "html",
  document: "document",
  doc: "document",
  web: "document",
  app: "document",
  preview: "document"
};

const SAFE_HTML_TAGS = new Set([
  "a",
  "article",
  "blockquote",
  "br",
  "caption",
  "code",
  "dd",
  "div",
  "dl",
  "dt",
  "em",
  "figcaption",
  "figure",
  "footer",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "header",
  "hr",
  "i",
  "img",
  "kbd",
  "li",
  "main",
  "mark",
  "ol",
  "p",
  "pre",
  "section",
  "small",
  "span",
  "strong",
  "sub",
  "sup",
  "table",
  "tbody",
  "td",
  "th",
  "thead",
  "tr",
  "u",
  "ul"
]);

const GLOBAL_ATTRS = new Set(["aria-label", "aria-describedby", "role", "title"]);
const ATTRS_BY_TAG: Record<string, Set<string>> = {
  a: new Set(["href", "title"]),
  img: new Set(["alt", "src", "title"]),
  td: new Set(["colspan", "rowspan"]),
  th: new Set(["colspan", "rowspan"])
};

export function defaultPreviewCapabilities(kind: PreviewPayloadKind): PreviewPayloadCapabilities {
  return {
    allowInlineStyles: kind === "document",
    allowScripts: kind === "document",
    allowDataImages: kind === "html" || kind === "document",
    allowNetwork: false
  };
}

export function previewPayloadFromCommand(command: CommandReceivedPayload): PreviewPayload | null {
  const bodyText = command.bodyText.trim();
  if (!bodyText) {
    return null;
  }

  const explicitPayload = previewPayloadFromJSON(bodyText);
  if (explicitPayload) {
    return explicitPayload;
  }

  const commandKind = KIND_ALIASES[command.commandName];
  if (commandKind) {
    return makePayload(commandKind, extractFencedContent(bodyText).content, {
      title: `/${command.commandName}`,
      source: "web-command"
    });
  }

  if (command.commandName === "render") {
    const firstArgument = command.arguments[0]?.toLowerCase();
    const renderKind = firstArgument ? KIND_ALIASES[firstArgument] : undefined;
    if (renderKind) {
      return makePayload(renderKind, extractFencedContent(dropFirstToken(bodyText)).content, {
        title: `/render ${firstArgument}`,
        source: "web-command"
      });
    }
  }

  return null;
}

export function previewPayloadFromOutput(
  output: string,
  options: { isFinal: boolean } = { isFinal: false }
): PreviewPayload | null {
  const trimmed = output.trim();
  if (!trimmed) {
    return null;
  }

  const explicitPayload = previewPayloadFromJSON(trimmed);
  if (explicitPayload) {
    return explicitPayload;
  }

  const fenced = extractFencedContent(trimmed);
  const content = fenced.content.trim();
  const language = fenced.language?.toLowerCase();
  if (options.isFinal && (language === "html" || looksLikeFullHTMLDocument(content))) {
    return makePayload("document", content, {
      title: "HTML document",
      source: "llm-output",
      language: language ?? "html"
    });
  }
  if (language === "markdown" || language === "md") {
    return makePayload("markdown", content, {
      title: "Markdown preview",
      source: "llm-output",
      language
    });
  }
  if (options.isFinal && looksLikeFullHTMLDocument(trimmed)) {
    return makePayload("document", trimmed, {
      title: "HTML document",
      source: "llm-output",
      language: "html"
    });
  }
  if (looksLikeHTMLFragment(trimmed) && !containsScript(trimmed)) {
    return makePayload("html", trimmed, {
      title: "HTML preview",
      source: "llm-output",
      language: "html"
    });
  }
  return makePayload("markdown", output, {
    title: "Preview",
    source: "llm-output",
    language: "markdown"
  });
}

export function normalizePreviewPayload(value: unknown): PreviewPayload | null {
  if (!value || typeof value !== "object") {
    return null;
  }
  const record = value as Record<string, unknown>;
  if (typeof record.content !== "string") {
    return null;
  }
  const kind = typeof record.kind === "string" ? KIND_ALIASES[record.kind.toLowerCase()] : undefined;
  if (!kind) {
    return null;
  }

  const metadataRecord = typeof record.metadata === "object" && record.metadata !== null
    ? record.metadata as Record<string, unknown>
    : {};
  const title = typeof record.title === "string"
    ? record.title
    : (typeof metadataRecord.title === "string" ? metadataRecord.title : null);
  const defaults = defaultPreviewCapabilities(kind);
  const nextCapabilities = typeof record.capabilities === "object" && record.capabilities !== null
    ? record.capabilities as Record<string, unknown>
    : {};

  return {
    kind,
    content: record.content,
    title,
    metadata: {
      title: title ?? undefined,
      source: normalizeMetadataSource(metadataRecord.source),
      language: typeof metadataRecord.language === "string" ? metadataRecord.language : undefined,
      description: typeof metadataRecord.description === "string" ? metadataRecord.description : undefined
    },
    capabilities: {
      allowInlineStyles: kind === "document"
        ? nextCapabilities.allowInlineStyles !== false
        : Boolean(nextCapabilities.allowInlineStyles && defaults.allowInlineStyles),
      allowScripts: kind === "document"
        ? nextCapabilities.allowScripts !== false
        : false,
      allowDataImages: Boolean(nextCapabilities.allowDataImages ?? defaults.allowDataImages),
      allowNetwork: false
    }
  };
}

export function renderMarkdownToSafeHTML(markdown: string): string {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const html: string[] = [];
  let paragraph: string[] = [];
  let listItems: string[] = [];
  let codeFence: string[] | null = null;

  const flushParagraph = () => {
    if (paragraph.length === 0) {
      return;
    }
    html.push(`<p>${renderInlineMarkdown(paragraph.join(" "))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (listItems.length === 0) {
      return;
    }
    html.push(`<ul>${listItems.map((item) => `<li>${renderInlineMarkdown(item)}</li>`).join("")}</ul>`);
    listItems = [];
  };

  for (const line of lines) {
    const fence = line.match(/^\s*```/);
    if (fence) {
      if (codeFence) {
        html.push(`<pre><code>${escapeHTML(codeFence.join("\n"))}</code></pre>`);
        codeFence = null;
      } else {
        flushParagraph();
        flushList();
        codeFence = [];
      }
      continue;
    }
    if (codeFence) {
      codeFence.push(line);
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed) {
      flushParagraph();
      flushList();
      continue;
    }

    const heading = trimmed.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      flushParagraph();
      flushList();
      const level = heading[1].length;
      html.push(`<h${level}>${renderInlineMarkdown(heading[2])}</h${level}>`);
      continue;
    }

    const listItem = trimmed.match(/^[-*]\s+(.+)$/);
    if (listItem) {
      flushParagraph();
      listItems.push(listItem[1]);
      continue;
    }

    const quote = trimmed.match(/^>\s?(.+)$/);
    if (quote) {
      flushParagraph();
      flushList();
      html.push(`<blockquote>${renderInlineMarkdown(quote[1])}</blockquote>`);
      continue;
    }

    paragraph.push(trimmed);
  }

  if (codeFence) {
    html.push(`<pre><code>${escapeHTML(codeFence.join("\n"))}</code></pre>`);
  }
  flushParagraph();
  flushList();
  return html.join("");
}

export function sanitizePreviewHTML(html: string): string {
  if (typeof DOMParser === "undefined") {
    return escapeHTML(html);
  }
  const parser = new DOMParser();
  const document = parser.parseFromString(`<body>${html}</body>`, "text/html");
  return Array.from(document.body.childNodes).map(sanitizeNode).join("");
}

export function buildIsolatedDocument(payload: PreviewPayload, theme: "light" | "dark"): string {
  const parts = extractDocumentParts(payload.content);
  const title = escapeHTML(payload.title ?? payload.metadata?.title ?? "Inputo Preview");
  const bodyClass = theme === "dark" ? "theme-dark" : "theme-light";
  const scriptPrelude = payload.capabilities.allowScripts
    ? `<script>${DOCUMENT_PRELUDE_SCRIPT}<\\/script>`
    : "";

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; media-src data: blob:; connect-src 'none'; font-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
  <title>${title}</title>
  <style>${DOCUMENT_BASE_CSS}</style>
  ${scriptPrelude}
  ${stripUnsafeDocumentHead(parts.head)}
</head>
<body class="${bodyClass}">
${parts.body}
</body>
</html>`;
}

export function previewTitle(payload: PreviewPayload | null, fallback: string): string {
  return payload?.title ?? payload?.metadata?.title ?? fallback;
}

function makePayload(
  kind: PreviewPayloadKind,
  content: string,
  metadata: NonNullable<PreviewPayload["metadata"]>
): PreviewPayload {
  return {
    kind,
    content,
    title: metadata.title ?? null,
    metadata,
    capabilities: defaultPreviewCapabilities(kind)
  };
}

function previewPayloadFromJSON(input: string): PreviewPayload | null {
  if (!input.startsWith("{")) {
    return null;
  }
  try {
    return normalizePreviewPayload(JSON.parse(input));
  } catch {
    return null;
  }
}

function extractFencedContent(input: string): { content: string; language: string | null } {
  const match = input.trim().match(/^```([A-Za-z0-9_-]+)?\s*\n([\s\S]*?)\n```$/);
  if (!match) {
    return { content: input, language: null };
  }
  return { content: match[2], language: match[1] ?? null };
}

function looksLikeFullHTMLDocument(input: string): boolean {
  return /<!doctype\s+html/i.test(input) || /<html[\s>]/i.test(input);
}

function looksLikeHTMLFragment(input: string): boolean {
  return /^<([a-z][a-z0-9-]*)(\s|>|\/>)/i.test(input) && /<\/?[a-z][\s\S]*>/i.test(input);
}

function containsScript(input: string): boolean {
  return /<script[\s>]/i.test(input);
}

function dropFirstToken(input: string): string {
  return input.replace(/^\S+\s*/, "").trimStart();
}

function normalizeMetadataSource(value: unknown): PreviewPayloadMetadata["source"] | undefined {
  switch (value) {
    case "native":
    case "web-command":
    case "llm-output":
    case "developer":
      return value;
    default:
      return undefined;
  }
}

function renderInlineMarkdown(input: string): string {
  let output = escapeHTML(input);
  output = output.replace(/`([^`]+)`/g, "<code>$1</code>");
  output = output.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  output = output.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  output = output.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_match, label: string, href: string) => {
    const safeHref = safeURL(href);
    if (!safeHref) {
      return label;
    }
    return `<a href="${safeHref}" target="_blank" rel="noreferrer">${label}</a>`;
  });
  return output;
}

function sanitizeNode(node: ChildNode): string {
  if (node.nodeType === Node.TEXT_NODE) {
    return escapeHTML(node.textContent ?? "");
  }
  if (node.nodeType !== Node.ELEMENT_NODE) {
    return "";
  }
  const element = node as Element;
  const tag = element.tagName.toLowerCase();
  const children = Array.from(element.childNodes).map(sanitizeNode).join("");
  if (!SAFE_HTML_TAGS.has(tag)) {
    return children;
  }
  const attrs = sanitizeAttributes(tag, element);
  if (tag === "br" || tag === "hr") {
    return `<${tag}${attrs}>`;
  }
  return `<${tag}${attrs}>${children}</${tag}>`;
}

function sanitizeAttributes(tag: string, element: Element): string {
  const allowed = ATTRS_BY_TAG[tag] ?? new Set<string>();
  const attributes: string[] = [];
  for (const attr of Array.from(element.attributes)) {
    const name = attr.name.toLowerCase();
    if (name.startsWith("on") || name === "style") {
      continue;
    }
    if (!GLOBAL_ATTRS.has(name) && !allowed.has(name)) {
      continue;
    }
    if ((name === "href" || name === "src") && !safeURL(attr.value, name === "src")) {
      continue;
    }
    attributes.push(`${name}="${escapeAttribute(attr.value)}"`);
  }
  if (tag === "a") {
    attributes.push(`target="_blank"`, `rel="noreferrer"`);
  }
  return attributes.length > 0 ? ` ${attributes.join(" ")}` : "";
}

function safeURL(value: string, dataOnly = false): string | null {
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  if (dataOnly) {
    return /^data:image\//i.test(trimmed) ? escapeAttribute(trimmed) : null;
  }
  if (/^(https?:|mailto:|#|\/(?!\/))/i.test(trimmed)) {
    return escapeAttribute(trimmed);
  }
  return null;
}

function extractDocumentParts(input: string): { head: string; body: string } {
  if (!looksLikeFullHTMLDocument(input)) {
    return { head: "", body: input };
  }
  const withoutBase = input.replace(/<base\b[\s\S]*?>/gi, "");
  const head = withoutBase.match(/<head[^>]*>([\s\S]*?)<\/head>/i)?.[1] ?? "";
  const body = withoutBase.match(/<body[^>]*>([\s\S]*?)<\/body>/i)?.[1] ??
    withoutBase
      .replace(/<!doctype[\s\S]*?>/i, "")
      .replace(/<\/?html[\s\S]*?>/gi, "")
      .replace(/<head[\s\S]*?<\/head>/i, "");
  return { head, body };
}

function stripUnsafeDocumentHead(head: string): string {
  return head
    .replace(/<base\b[\s\S]*?>/gi, "")
    .replace(/<meta\b[^>]*http-equiv=["']?content-security-policy["']?[\s\S]*?>/gi, "");
}

function escapeHTML(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeAttribute(input: string): string {
  return escapeHTML(input).replace(/`/g, "&#96;");
}

const DOCUMENT_BASE_CSS = `
html, body {
  min-height: 100%;
  margin: 0;
}
body {
  color: #1d2329;
  background: #f7fafc;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
  line-height: 1.45;
}
body.theme-dark {
  color: #eef3f5;
  background: #101417;
}
* { box-sizing: border-box; }
img, video, canvas, svg { max-width: 100%; }
button, input, textarea, select { font: inherit; }
`;

const DOCUMENT_PRELUDE_SCRIPT = `
(() => {
  const disabled = () => {
    throw new Error("Network access is disabled in Inputo Preview Runtime V1.");
  };
  try {
    Object.defineProperty(window, "webkit", { value: undefined, configurable: false, writable: false });
    Object.defineProperty(window, "InputoNativeBridgeReceiveBase64", { value: undefined, configurable: false, writable: false });
    Object.defineProperty(window, "fetch", { value: disabled, configurable: false, writable: false });
    Object.defineProperty(window, "XMLHttpRequest", { value: function XMLHttpRequest() { disabled(); }, configurable: false, writable: false });
    Object.defineProperty(window, "WebSocket", { value: function WebSocket() { disabled(); }, configurable: false, writable: false });
    Object.defineProperty(window, "EventSource", { value: function EventSource() { disabled(); }, configurable: false, writable: false });
    Object.defineProperty(window, "open", { value: () => null, configurable: false, writable: false });
  } catch {}
  const report = (message) => {
    try {
      parent.postMessage({ type: "inputo.preview.error", message: String(message || "Preview script failed.") }, "*");
    } catch {}
  };
  window.addEventListener("error", (event) => report(event.message));
  window.addEventListener("unhandledrejection", () => report("Preview script promise rejected."));
})();
`;
