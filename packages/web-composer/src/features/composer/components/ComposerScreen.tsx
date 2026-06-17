import { useComposerController } from "../hooks/useComposerController";
import { composerStrings } from "../model/composerStrings";
import { previewTitle } from "../model/previewRuntime";
import { PreviewRuntime } from "./PreviewRuntime";

export function ComposerScreen() {
  const {
    viewState,
    composer,
    hasOutput,
    previewText,
    isGenerating,
    status,
    copyOutput
  } = useComposerController();
  const routedCommand = viewState.routedCommand;
  const previewPayload = viewState.previewPayload;
  const title = previewTitle(
    previewPayload,
    routedCommand ? `/${routedCommand.commandName}` : composerStrings.previewTitle
  );

  return (
    <main className="composer-shell" aria-label="Inputo preview">
      <section className="preview-panel" aria-label="Preview">
        <div className="panel-title-row">
          <h2>{title}</h2>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput}
            onClick={copyOutput}
          >
            {composerStrings.copy}
          </button>
        </div>

        {routedCommand && !previewPayload ? (
          <div className="web-command-preview" aria-label="Web command">
            <p>{routedCommand.inputText}</p>
            <span>Waiting for Web command runtime.</span>
          </div>
        ) : (
          <PreviewRuntime
            payload={previewPayload}
            fallbackText={previewText}
            hasFallbackOutput={hasOutput}
            isGenerating={isGenerating}
          />
        )}

        <p
          className={`status-text${status.isError ? " is-error" : ""}`}
          role="status"
          aria-live="polite"
          aria-atomic="true"
        >
          {status.text || (isGenerating ? composerStrings.generatingStatus : "")}
        </p>
      </section>
    </main>
  );
}
