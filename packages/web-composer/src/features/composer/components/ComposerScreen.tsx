import { useComposerController } from "../hooks/useComposerController";
import { composerStrings } from "../model/composerStrings";

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
    diagnostics,
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
          <h2>{composerStrings.previewTitle}</h2>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput}
            onClick={copyOutput}
          >
            {composerStrings.copy}
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
          aria-label={composerStrings.presetLabel}
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
          aria-label={composerStrings.instructionLabel}
          placeholder={composerStrings.instructionPlaceholder}
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleInstructionCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleInstructionChange}
        />
      </section>

      {providerSetup ? (
        <section className="setup-row" aria-label={composerStrings.providerSetupLabel}>
          <div className="setup-copy">
            <strong>{providerSetup.message}</strong>
            <span>{providerSetup.detail}</span>
          </div>
          <button type="button" className="secondary-button" onClick={openSettings}>
            {composerStrings.settings}
          </button>
        </section>
      ) : null}

      <section className="tool-row" aria-label={composerStrings.nativeFileToolsLabel}>
        <span>{fileTools.label}</span>
        <div className="tool-buttons">
          <button
            type="button"
            className="secondary-button"
            disabled={!fileTools.canRead}
            onClick={readTextFile}
            title={fileTools.readDetail}
          >
            {composerStrings.readFile}
          </button>
          <button
            type="button"
            className="secondary-button"
            disabled={!hasOutput || !fileTools.canWrite}
            onClick={saveOutputFile}
            title={fileTools.writeDetail}
          >
            {composerStrings.save}
          </button>
        </div>
      </section>

      <section className="inspector-row" aria-label={composerStrings.diagnosticsLabel}>
        <details>
          <summary>
            <span>{composerStrings.diagnosticsSummary}</span>
            <strong>{diagnostics.summary}</strong>
          </summary>
          <div className="inspector-detail">
            <dl className="diagnostics-list">
              {diagnostics.items.map((item) => (
                <div key={item.label}>
                  <dt>{item.label}</dt>
                  <dd>{item.value}</dd>
                </div>
              ))}
            </dl>
            <div className="permission-list" aria-label={composerStrings.permissionsSummary}>
              {diagnostics.permissions.map((permission) => (
                <div className="permission-item" key={permission.id}>
                  <span>{permission.label}</span>
                  <strong className={`permission-state is-${permission.tone}`}>
                    {permission.stateLabel}
                  </strong>
                  <p>{permission.detail}</p>
                </div>
              ))}
            </div>
          </div>
        </details>
      </section>

      <section className="draft-panel" aria-label={composerStrings.draftLabel}>
        <textarea
          ref={draftRef}
          className="draft-input"
          value={composer.draftText}
          autoComplete="off"
          spellCheck
          aria-label={composerStrings.draftLabel}
          aria-describedby="composer-status"
          placeholder={composerStrings.draftPlaceholder}
          onCompositionStart={() => markCompositionActivity(true)}
          onCompositionUpdate={() => markCompositionActivity(true)}
          onCompositionEnd={handleDraftCompositionEnd}
          onBeforeInput={handleBeforeInput}
          onChange={handleDraftChange}
        />
        <div className="action-row">
          <p
            className={`status-text${status.isError ? " is-error" : ""}`}
            id="composer-status"
            role="status"
            aria-live="polite"
            aria-atomic="true"
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
              {composerStrings.clear}
            </button>
            {isGenerating ? (
              <button type="button" className="secondary-button" onClick={cancelGeneration}>
                {composerStrings.cancel}
              </button>
            ) : null}
            <button
              type="button"
              className="primary-button"
              disabled={!canGenerate}
              onClick={generate}
            >
              {isGenerating ? composerStrings.generating : composerStrings.generate}
            </button>
          </div>
        </div>
      </section>
    </main>
  );
}
