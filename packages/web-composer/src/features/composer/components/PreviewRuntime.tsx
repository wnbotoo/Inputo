import { useEffect, useMemo, useRef, useState } from "react";
import type { PreviewPayload } from "@inputo/bridge-contracts";
import {
  buildIsolatedDocument,
  renderMarkdownToSafeHTML,
  sanitizePreviewHTML
} from "../model/previewRuntime";

interface PreviewRuntimeProps {
  payload: PreviewPayload | null;
  fallbackText: string;
  hasFallbackOutput: boolean;
  isGenerating: boolean;
}

export function PreviewRuntime({
  payload,
  fallbackText,
  hasFallbackOutput,
  isGenerating
}: PreviewRuntimeProps) {
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const [runtimeError, setRuntimeError] = useState<string | null>(null);

  useEffect(() => {
    setRuntimeError(null);
  }, [payload]);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (!iframeRef.current || event.source !== iframeRef.current.contentWindow) {
        return;
      }
      const data = event.data as { type?: string; message?: unknown } | null;
      if (data?.type === "inputo.preview.error") {
        setRuntimeError(
          typeof data.message === "string" && data.message.trim().length > 0
            ? data.message
            : "Preview runtime failed."
        );
      }
    };
    window.addEventListener("message", handleMessage);
    return () => {
      window.removeEventListener("message", handleMessage);
    };
  }, []);

  const inlineHTML = useMemo(() => {
    if (!payload || payload.kind === "document" || payload.kind === "text") {
      return "";
    }
    if (payload.kind === "markdown") {
      return renderMarkdownToSafeHTML(payload.content);
    }
    return sanitizePreviewHTML(payload.content);
  }, [payload]);

  if (!payload) {
    return (
      <textarea
        className={`preview-output${hasFallbackOutput ? "" : " is-empty"}`}
        readOnly
        spellCheck={false}
        aria-label="Generated preview"
        value={fallbackText}
      />
    );
  }

  if (payload.kind === "document") {
    const theme = document.documentElement.dataset.theme === "dark" ? "dark" : "light";
    const sandbox = payload.capabilities.allowScripts ? "allow-scripts" : "";
    return (
      <div className="preview-runtime-frame-wrap">
        <iframe
          key={`${payload.title ?? payload.metadata?.title ?? "preview"}:${payload.content}`}
          ref={iframeRef}
          className="preview-runtime-frame"
          title={payload.title ?? payload.metadata?.title ?? "Inputo preview document"}
          sandbox={sandbox}
          srcDoc={buildIsolatedDocument(payload, theme)}
        />
        <RuntimeBadge
          text={runtimeError ?? (isGenerating ? "Rendering..." : "Isolated document")}
          isError={Boolean(runtimeError)}
        />
      </div>
    );
  }

  if (payload.kind === "text") {
    return (
      <pre className="preview-runtime-text" aria-label="Text preview">
        {payload.content}
      </pre>
    );
  }

  return (
    <div className="preview-runtime-rich" aria-label="Rendered preview">
      <div dangerouslySetInnerHTML={{ __html: inlineHTML }} />
    </div>
  );
}

function RuntimeBadge({ text, isError }: { text: string; isError: boolean }) {
  return (
    <span className={`preview-runtime-badge${isError ? " is-error" : ""}`} role={isError ? "alert" : "status"}>
      {text}
    </span>
  );
}
