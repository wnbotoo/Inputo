(() => {
  "use strict";

  const VERSION = 1;
  const USER_ACTION = { userAction: true, confirmed: false };
  const SYNC_DELAY_MS = 160;
  const COMPOSITION_ESCAPE_GRACE_MS = 700;

  const elements = {
    output: document.getElementById("outputText"),
    copy: document.getElementById("copyButton"),
    recipe: document.getElementById("recipeSelect"),
    instruction: document.getElementById("instructionInput"),
    draft: document.getElementById("draftInput"),
    status: document.getElementById("statusText"),
    clear: document.getElementById("clearButton"),
    cancel: document.getElementById("cancelButton"),
    generate: document.getElementById("generateButton")
  };

  const pending = new Map();
  let recipes = [];
  let composer = {
    draftText: "",
    instruction: "",
    selectedRecipeID: "polish",
    generatedOutput: "",
    isGenerating: false,
    canGenerate: false,
    canCopy: false,
    statusMessage: null,
    errorMessage: null
  };
  let activeRequestID = null;
  let draftSyncTimer = null;
  let instructionSyncTimer = null;
  let isComposingText = false;
  let lastCompositionActivityAt = 0;

  window.InputoNativeThemeSet = (theme) => {
    const nextTheme = theme === "dark" ? "dark" : "light";
    document.documentElement.dataset.theme = nextTheme;
  };

  window.InputoNativeThemeSet(window.InputoInitialTheme || (
    window.matchMedia?.("(prefers-color-scheme: dark)")?.matches ? "dark" : "light"
  ));

  function makeID(prefix) {
    const random = Math.random().toString(36).slice(2);
    return `${prefix}-${Date.now().toString(36)}-${random}`;
  }

  function postEnvelope(envelope) {
    const handler = window.webkit?.messageHandlers?.inputoNative;
    if (!handler) {
      throw new Error("Native bridge is unavailable.");
    }
    handler.postMessage(JSON.stringify(envelope));
  }

  function callTool(tool, payload = {}, context = null, id = makeID(tool.replaceAll(".", "-"))) {
    const envelope = {
      version: VERSION,
      id,
      type: "tool.call",
      tool,
      payload
    };
    if (context) {
      envelope.context = context;
    }

    return new Promise((resolve) => {
      pending.set(id, { resolve });
      try {
        postEnvelope(envelope);
      } catch (error) {
        pending.delete(id);
        resolve({
          version: VERSION,
          id,
          type: "tool.result",
          ok: false,
          error: {
            code: "internal_error",
            message: error.message,
            field: null,
            retryable: false
          }
        });
      }
    });
  }

  function decodeBase64JSON(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return JSON.parse(new TextDecoder().decode(bytes));
  }

  window.InputoNativeBridgeReceiveBase64 = (base64) => {
    let message;
    try {
      message = decodeBase64JSON(base64);
    } catch {
      setStatus("Native bridge returned an unreadable message.", true);
      return;
    }

    if (message.type === "event") {
      handleNativeEvent(message);
      return;
    }

    const pendingRequest = pending.get(message.id);
    if (pendingRequest) {
      pending.delete(message.id);
      pendingRequest.resolve(message);
    }
  };

  window.InputoComposerFocus = () => {
    requestAnimationFrame(() => {
      elements.draft.focus();
    });
  };

  function setStatus(text, isError = false) {
    elements.status.textContent = text || "";
    elements.status.classList.toggle("is-error", isError);
  }

  function applySnapshot(snapshot) {
    recipes = Array.isArray(snapshot.recipes) ? snapshot.recipes : recipes;
    applyComposer(snapshot.composer);
    renderRecipes();
    render();
  }

  function applyComposer(nextComposer) {
    composer = { ...composer, ...nextComposer };
    render();
  }

  function renderRecipes() {
    const selected = composer.selectedRecipeID;
    elements.recipe.replaceChildren();
    for (const recipe of recipes) {
      const option = document.createElement("option");
      option.value = recipe.id;
      option.textContent = recipe.name;
      elements.recipe.append(option);
    }
    elements.recipe.value = selected;
  }

  function render() {
    renderRecipesIfNeeded();
    updateFieldValue(elements.recipe, composer.selectedRecipeID);
    updateFieldValue(elements.instruction, composer.instruction);
    updateFieldValue(elements.draft, composer.draftText);

    const hasOutput = composer.generatedOutput.trim().length > 0;
    const previewText = hasOutput
      ? composer.generatedOutput
      : (composer.isGenerating ? "Generating..." : "No preview yet.");
    elements.output.value = previewText;
    elements.output.classList.toggle("is-empty", !hasOutput);

    const canGenerate = composer.draftText.trim().length > 0 && !composer.isGenerating && !activeRequestID;
    elements.generate.disabled = !canGenerate;
    elements.generate.textContent = composer.isGenerating || activeRequestID ? "Generating" : "Generate";
    elements.copy.disabled = !hasOutput;
    elements.clear.disabled = composer.isGenerating && !activeRequestID;
    elements.cancel.hidden = !(composer.isGenerating || activeRequestID);

    if (composer.errorMessage) {
      setStatus(composer.errorMessage, true);
    } else if (composer.statusMessage) {
      setStatus(composer.statusMessage, false);
    } else if (composer.isGenerating || activeRequestID) {
      setStatus("Generating...", false);
    } else {
      setStatus("", false);
    }
  }

  function renderRecipesIfNeeded() {
    if (elements.recipe.options.length !== recipes.length) {
      renderRecipes();
    }
  }

  function updateFieldValue(element, value) {
    const nextValue = value || "";
    if (document.activeElement === element) {
      return;
    }
    if (element.value !== nextValue) {
      element.value = nextValue;
    }
  }

  function scheduleDraftSync() {
    clearTimeout(draftSyncTimer);
    draftSyncTimer = setTimeout(() => {
      callTool("composer.setDraft", { draftText: composer.draftText })
        .then(applyToolComposerResult);
    }, SYNC_DELAY_MS);
  }

  function scheduleInstructionSync() {
    clearTimeout(instructionSyncTimer);
    instructionSyncTimer = setTimeout(() => {
      callTool("composer.setInstruction", { instruction: composer.instruction })
        .then(applyToolComposerResult);
    }, SYNC_DELAY_MS);
  }

  function cancelPendingSync() {
    clearTimeout(draftSyncTimer);
    clearTimeout(instructionSyncTimer);
    draftSyncTimer = null;
    instructionSyncTimer = null;
  }

  function markCompositionActivity(isActive = true) {
    isComposingText = isActive;
    lastCompositionActivityAt = performance.now();
  }

  function wasRecentlyComposing() {
    return performance.now() - lastCompositionActivityAt < COMPOSITION_ESCAPE_GRACE_MS;
  }

  function applyToolComposerResult(response) {
    if (response?.ok && response.payload) {
      applyComposer(response.payload);
    } else if (response?.error) {
      composer.errorMessage = response.error.message;
      render();
    }
  }

  async function generate() {
    if (composer.draftText.trim().length === 0 || composer.isGenerating || activeRequestID) {
      return;
    }

    cancelPendingSync();
    const requestID = makeID("llm-stream");
    activeRequestID = requestID;
    composer = {
      ...composer,
      generatedOutput: "",
      isGenerating: true,
      statusMessage: null,
      errorMessage: null
    };
    render();

    const response = await callTool(
      "llm.stream",
      {
        draftText: composer.draftText,
        instruction: composer.instruction,
        recipeID: composer.selectedRecipeID
      },
      USER_ACTION,
      requestID
    );

    activeRequestID = null;
    if (response.ok && response.payload?.composer) {
      applyComposer(response.payload.composer);
    } else if (response.error) {
      composer = {
        ...composer,
        isGenerating: false,
        errorMessage: response.error.message
      };
      render();
    }
  }

  async function cancelGeneration() {
    if (!activeRequestID) {
      return;
    }
    const requestID = activeRequestID;
    await callTool("llm.cancel", { requestID });
  }

  async function clearComposer() {
    await callTool("composer.clear", {}, USER_ACTION)
      .then((response) => {
        activeRequestID = null;
        applyToolComposerResult(response);
      });
  }

  async function copyOutput() {
    await callTool("clipboard.copyGeneratedOutput", {}, USER_ACTION)
      .then(applyToolComposerResult);
  }

  function handleNativeEvent(message) {
    if (message.requestID && activeRequestID && message.requestID !== activeRequestID) {
      return;
    }

    switch (message.event) {
      case "llm.started":
        composer = {
          ...composer,
          generatedOutput: "",
          isGenerating: true,
          statusMessage: null,
          errorMessage: null
        };
        break;
      case "llm.delta":
        composer = {
          ...composer,
          generatedOutput: `${composer.generatedOutput}${message.payload?.text || ""}`,
          isGenerating: true
        };
        break;
      case "llm.completed":
        composer = {
          ...composer,
          isGenerating: false,
          statusMessage: "Ready to copy.",
          errorMessage: null
        };
        activeRequestID = null;
        break;
      case "llm.failed":
        composer = {
          ...composer,
          isGenerating: false,
          errorMessage: message.payload?.message || "Generation failed."
        };
        activeRequestID = null;
        break;
      case "llm.cancelled":
        composer = {
          ...composer,
          isGenerating: false,
          statusMessage: "Generation cancelled.",
          errorMessage: null
        };
        activeRequestID = null;
        break;
      default:
        break;
    }
    render();
  }

  elements.draft.addEventListener("compositionstart", () => {
    markCompositionActivity(true);
  });

  elements.draft.addEventListener("compositionupdate", () => {
    markCompositionActivity(true);
  });

  elements.draft.addEventListener("compositionend", () => {
    markCompositionActivity(false);
    composer.draftText = elements.draft.value;
    scheduleDraftSync();
    render();
  });

  elements.draft.addEventListener("beforeinput", (event) => {
    if (event.isComposing || event.inputType === "insertCompositionText") {
      markCompositionActivity(true);
    }
  });

  elements.draft.addEventListener("input", (event) => {
    composer.draftText = elements.draft.value;
    composer.errorMessage = null;
    if (event.isComposing) {
      markCompositionActivity(true);
    }
    if (!isComposingText) {
      scheduleDraftSync();
    }
    render();
  });

  elements.instruction.addEventListener("compositionstart", () => {
    markCompositionActivity(true);
  });

  elements.instruction.addEventListener("compositionupdate", () => {
    markCompositionActivity(true);
  });

  elements.instruction.addEventListener("compositionend", () => {
    markCompositionActivity(false);
    composer.instruction = elements.instruction.value;
    scheduleInstructionSync();
    render();
  });

  elements.instruction.addEventListener("beforeinput", (event) => {
    if (event.isComposing || event.inputType === "insertCompositionText") {
      markCompositionActivity(true);
    }
  });

  elements.instruction.addEventListener("input", (event) => {
    composer.instruction = elements.instruction.value;
    composer.errorMessage = null;
    if (event.isComposing) {
      markCompositionActivity(true);
    }
    if (!isComposingText) {
      scheduleInstructionSync();
    }
    render();
  });

  elements.recipe.addEventListener("change", () => {
    composer.selectedRecipeID = elements.recipe.value;
    callTool("composer.selectRecipe", { recipeID: composer.selectedRecipeID })
      .then(applyToolComposerResult);
    render();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      if (event.isComposing || isComposingText || wasRecentlyComposing()) {
        return;
      }
      event.preventDefault();
      callTool("app.hideComposer", {}, USER_ACTION);
      return;
    }

    if ((event.metaKey || event.ctrlKey) && event.key === "Enter" && !event.isComposing) {
      event.preventDefault();
      generate();
    }
  });

  elements.generate.addEventListener("click", generate);
  elements.cancel.addEventListener("click", cancelGeneration);
  elements.clear.addEventListener("click", clearComposer);
  elements.copy.addEventListener("click", copyOutput);

  callTool("app.snapshot")
    .then((response) => {
      if (response.ok && response.payload) {
        applySnapshot(response.payload);
        window.InputoComposerFocus();
      } else {
        setStatus(response.error?.message || "Could not load native state.", true);
      }
    });
})();
