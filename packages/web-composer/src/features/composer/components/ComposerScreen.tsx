import { useComposerController } from "../hooks/useComposerController";
import { composerStrings } from "../model/composerStrings";

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

  return (
    <main className="composer-shell" aria-label="Inputo preview">
      <section className="preview-panel" aria-label="Preview">
        <div className="panel-title-row">
          <h2>{routedCommand ? `/${routedCommand.commandName}` : composerStrings.previewTitle}</h2>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput}
            onClick={copyOutput}
          >
            {composerStrings.copy}
          </button>
        </div>

        {routedCommand ? (
          <div className="web-command-preview" aria-label="Web command">
            <p>{routedCommand.inputText}</p>
            <span>Waiting for Web command runtime.</span>
          </div>
        ) : (
          <textarea
            className={`preview-output${hasOutput ? "" : " is-empty"}`}
            readOnly
            spellCheck={false}
            aria-label="Generated preview"
            value={previewText}
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
