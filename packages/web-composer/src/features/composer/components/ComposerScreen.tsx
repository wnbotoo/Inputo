import { useComposerController } from "../hooks/useComposerController";

export function ComposerScreen() {
  const {
    viewState,
    composer,
    draftRef,
    hasOutput,
    previewText,
    canGenerate,
    isGenerating,
    status,
    providerSetup,
    fileTools,
    generate,
    cancelGeneration,
    clearComposer,
    copyOutput,
    openSettings,
    readTextFile,
    saveOutputFile,
    markCompositionActivity,
    handleDraftCompositionEnd,
    handleInstructionCompositionEnd,
    handleDraftChange,
    handleInstructionChange,
    handleRecipeChange,
    handleBeforeInput
  } = useComposerController();

  return (
    <main className="composer-shell" aria-label="Inputo composer">
      <section className="preview-panel" aria-label="Preview">
        <div className="panel-title-row">
          <h2>Preview</h2>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput}
            onClick={copyOutput}
          >
            Copy
          </button>
        </div>
        <textarea
          className={`preview-output${hasOutput ? "" : " is-empty"}`}
          readOnly
          spellCheck={false}
          aria-label="Generated preview"
          value={previewText}
        />
      </section>

      <section className="control-row" aria-label="Transform controls">
        <select
          value={composer.selectedRecipeID}
          aria-label="Preset"
          onChange={handleRecipeChange}
        >
          {viewState.recipes.map((recipe) => (
            <option key={recipe.id} value={recipe.id}>
              {recipe.name}
            </option>
          ))}
        </select>
        <input
          type="text"
          value={composer.instruction}
          autoComplete="off"
          spellCheck
          aria-label="Instruction"
          placeholder="Instruction"
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleInstructionCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleInstructionChange}
        />
      </section>

      {providerSetup ? (
        <section className="setup-row" aria-label="Provider setup">
          <div className="setup-copy">
            <strong>{providerSetup.message}</strong>
            <span>{providerSetup.detail}</span>
          </div>
          <button type="button" className="secondary-button" onClick={openSettings}>
            Settings
          </button>
        </section>
      ) : null}

      <section className="tool-row" aria-label="Native file tools">
        <span>{fileTools.label}</span>
        <div className="tool-buttons">
          <button
            type="button"
            className="secondary-button"
            disabled={!fileTools.canRead}
            onClick={readTextFile}
          >
            Read File
          </button>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput || !fileTools.canWrite}
            onClick={saveOutputFile}
          >
            Save
          </button>
        </div>
      </section>

      <section className="draft-panel" aria-label="Draft">
        <textarea
          ref={draftRef}
          className="draft-input"
          value={composer.draftText}
          autoComplete="off"
          spellCheck
          aria-label="Draft"
          placeholder="Paste or type the text you want Inputo to transform..."
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleDraftCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleDraftChange}
        />
        <div className="action-row">
          <p
            className={`status-text${status.isError ? " is-error" : ""}`}
            role="status"
            aria-live="polite"
          >
            {status.text}
          </p>
          <div className="action-buttons">
            <button
              type="button"
              className="secondary-button"
              disabled={composer.isGenerating && !viewState.activeRequestID}
              onClick={clearComposer}
            >
              Clear
            </button>
            {isGenerating ? (
              <button type="button" className="secondary-button" onClick={cancelGeneration}>
                Cancel
              </button>
            ) : null}
            <button
              type="button"
              className="primary-button"
              disabled={!canGenerate}
              onClick={generate}
            >
              {isGenerating ? "Generating" : "Generate"}
            </button>
          </div>
        </div>
      </section>
    </main>
  );
}
