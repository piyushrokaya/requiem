const { spawn } = require("child_process");
const path = require("path");
const cron = require("node-cron");
const { ingestAll } = require("../services/ingest.service");
const { isConfigured } = require("../config/pg");

// Backend root (one level up from src/). The Python script uses paths relative
// to this folder (e.g. "data/all_articles_processed.csv"), so we spawn it here.
const BACKEND_ROOT = path.join(__dirname, "../..");
// Wrapper that imports the pipeline and runs a SINGLE cycle, then exits. We use
// this instead of running data/nepali_news_pipeline.py directly, because that
// module's main() loops forever and would never let the process exit.
const PIPELINE_SCRIPT = path.join("scripts", "run_pipeline_once.py");

const envBool = (name, fallback) => {
  const v = process.env[name];
  if (v === undefined) return fallback;
  return String(v).toLowerCase() === "true";
};

// Runs the Python pipeline for ONE cycle and resolves when it exits.
// Never rejects — a failed pipeline shouldn't crash the server.
const runPythonPipelineOnce = () =>
  new Promise((resolve) => {
    const pythonBin = process.env.PYTHON_BIN || "python";
    console.log(`[refresh] python: ${pythonBin} ${PIPELINE_SCRIPT}`);

    const child = spawn(pythonBin, [PIPELINE_SCRIPT], {
      cwd: BACKEND_ROOT,
      env: process.env,
    });

    child.stdout.on("data", (d) => process.stdout.write(`[python] ${d}`));
    child.stderr.on("data", (d) => process.stderr.write(`[python] ${d}`));

    child.on("error", (err) => {
      console.error("[refresh] failed to start python:", err.message);
      resolve({ ok: false, error: err.message });
    });
    child.on("close", (code) => {
      console.log(`[refresh] python exited (code ${code})`);
      resolve({ ok: code === 0, code });
    });
  });

// Guard so a slow pipeline run isn't started again by the next cron tick.
let running = false;

const runRefresh = async () => {
  if (running) {
    console.log("[refresh] previous run still in progress; skipping this tick");
    return;
  }
  running = true;
  const startedAt = Date.now();
  try {
    if (envBool("RUN_PYTHON_ON_REFRESH", true)) {
      await runPythonPipelineOnce();
    } else {
      console.log(
        "[refresh] RUN_PYTHON_ON_REFRESH=false; ingesting existing data files only"
      );
    }

    if (isConfigured()) {
      const result = await ingestAll();
      console.log(
        `[refresh] ingested ${result.articles} articles, ${result.clusters} clusters`
      );
    } else {
      console.warn("[refresh] DATABASE_URL not set; skipped DB ingestion");
    }
  } catch (err) {
    console.error("[refresh] error:", err.message);
  } finally {
    running = false;
    console.log(
      `[refresh] done in ${((Date.now() - startedAt) / 1000).toFixed(1)}s`
    );
  }
};

// Starts the cron scheduler. Cadence and behaviour are env-configurable.
const startScheduler = () => {
  if (!envBool("SCHEDULER_ENABLED", true)) {
    console.log("[scheduler] disabled (SCHEDULER_ENABLED=false)");
    return;
  }

  const cronExpr = process.env.NEWS_REFRESH_CRON || "*/30 * * * *";
  if (!cron.validate(cronExpr)) {
    console.error(
      `[scheduler] invalid NEWS_REFRESH_CRON "${cronExpr}"; scheduler not started`
    );
    return;
  }

  console.log(`[scheduler] news refresh scheduled: "${cronExpr}"`);
  cron.schedule(cronExpr, runRefresh);

  if (envBool("RUN_REFRESH_ON_STARTUP", false)) {
    console.log("[scheduler] running initial refresh on startup");
    runRefresh();
  }
};

module.exports = { startScheduler, runRefresh, runPythonPipelineOnce };
