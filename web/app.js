(function () {
  const canvas = document.getElementById("game-canvas");
  const statusEl = document.getElementById("game-status");
  const aiStatusEl = document.getElementById("ai-status");
  const searchModeSelect = document.getElementById("search-mode-select");
  const runAIButton = document.getElementById("run-ai-button");
  const platformerAI = (window.platformerAI = window.platformerAI || {});
  const resultRows = {
    "Uniform Cost Search": document.getElementById("result-ucs"),
    "Greedy Best-First Search": document.getElementById("result-greedy"),
    "A* Search": document.getElementById("result-astar"),
  };
  const defaultSearchMode = "Uniform Cost Search";
  const searchModeAliases = {
    UCS: "Uniform Cost Search",
    Greedy: "Greedy Best-First Search",
    "Greedy Best First Search": "Greedy Best-First Search",
    "A Star Search": "A* Search",
    Astar: "A* Search",
    "A*": "A* Search",
  };
  let displayedSearchMode = "";
  let displayedSelection = "";

  function normalizeSearchMode(value) {
    const name = String(value || "").trim();
    if (searchModeAliases[name]) {
      return searchModeAliases[name];
    }
    if (
      name === "Uniform Cost Search" ||
      name === "Greedy Best-First Search" ||
      name === "A* Search"
    ) {
      return name;
    }
    return defaultSearchMode;
  }

  platformerAI.selectedSearchMode = normalizeSearchMode(platformerAI.selectedSearchMode);

  if (typeof platformerAI.lastSearchMode !== "string") {
    platformerAI.lastSearchMode = "";
  }

  if (typeof platformerAI.runRequestId !== "number") {
    platformerAI.runRequestId = 0;
  }

  if (!platformerAI.results || typeof platformerAI.results !== "object") {
    platformerAI.results = {};
  }

  function setStatus(message) {
    statusEl.textContent = message;
    statusEl.hidden = false;
  }

  function hideStatus() {
    statusEl.hidden = true;
  }

  function updateAIStatus() {
    const selected = String(platformerAI.selectedSearchMode || "").trim();
    const searchMode = String(platformerAI.lastSearchMode || "").trim();
    if (
      !aiStatusEl ||
      (selected === displayedSelection && searchMode === displayedSearchMode)
    ) {
      return;
    }
    displayedSelection = selected;
    displayedSearchMode = searchMode;
    aiStatusEl.textContent = searchMode
      ? "Selected: " + selected + " | Last run: " + searchMode
      : "Selected: " + selected;
  }

  function syncSelectedSearchMode() {
    if (!searchModeSelect) {
      return;
    }
    platformerAI.selectedSearchMode = searchModeSelect.value;
    updateAIStatus();
  }

  if (searchModeSelect) {
    searchModeSelect.value = platformerAI.selectedSearchMode;
    searchModeSelect.addEventListener("change", syncSelectedSearchMode);
  }

  if (runAIButton) {
    runAIButton.disabled = true;
    runAIButton.addEventListener("click", function () {
      syncSelectedSearchMode();
      platformerAI.runRequestId += 1;
      canvas.focus();
    });
  }

  function setMetric(row, metric, value) {
    const cell = row.querySelector('[data-metric="' + metric + '"]');
    if (cell) {
      cell.textContent = value;
    }
  }

  function formatMs(value) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.round(number) + " ms" : "-";
  }

  function formatCount(value) {
    const number = Number(value);
    return Number.isFinite(number) ? String(Math.round(number)) : "-";
  }

  function formatCost(value) {
    const number = Number(value);
    return Number.isFinite(number) ? number.toFixed(1) : "-";
  }

  platformerAI.recordResult = function (result) {
    if (!result || typeof result !== "object") {
      return;
    }
    const searchMode = normalizeSearchMode(result && result.searchMode);
    const row = resultRows[searchMode];
    if (!row) {
      return;
    }

    platformerAI.results[searchMode] = result;
    row.classList.toggle("is-success", Boolean(result.success));
    row.classList.toggle("is-failure", !result.success);
    setMetric(row, "result", result.success ? "Success" : "Failure");
    setMetric(row, "runtime", formatMs(result.runtimeMs));
    setMetric(row, "nodes", formatCount(result.nodesExpanded));
    setMetric(row, "path", formatCount(result.pathLength));
    setMetric(row, "cost", formatCost(result.pathCost));
    setMetric(row, "jumps", formatCount(result.jumps));
  };

  function loadEngineScript() {
    return new Promise(function (resolve, reject) {
      const script = document.createElement("script");
      script.src = "build/index.js";
      script.onload = resolve;
      script.onerror = function () {
        reject(
          new Error(
            'Godot web export not found at web/build/. Export the Godot project from game/ using HTML5 preset with file name "index.html" into web/build/.'
          )
        );
      };
      document.head.appendChild(script);
    });
  }

  syncSelectedSearchMode();
  setStatus("Loading engine\u2026");
  window.setInterval(updateAIStatus, 250);

  loadEngineScript()
    .then(function () {
      if (typeof Engine !== "function") {
        throw new Error(
          "Godot engine script loaded but did not register the Engine class."
        );
      }
      const engine = new Engine({
        executable: "build/index",
        canvas: canvas,
        canvasResizePolicy: 0,
      });
      setStatus("Loading game\u2026");
      return engine
        .startGame({
          onProgress: function (current, total) {
            if (total > 0) {
              const pct = Math.floor((current / total) * 100);
              setStatus("Loading game\u2026 " + pct + "%");
            }
          },
        })
        .then(function () {
          if (runAIButton) {
            runAIButton.disabled = false;
          }
          hideStatus();
        });
    })
    .catch(function (err) {
      setStatus(err && err.message ? err.message : String(err));
      console.error(err);
    });
})();
