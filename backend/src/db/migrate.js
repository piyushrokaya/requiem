const fs = require("fs");
const path = require("path");
const { pool, isConfigured } = require("../config/pg");

const SCHEMA_PATH = path.join(__dirname, "schema.sql");

// Neon scales the compute to zero when idle. The first query after that has to
// wake it, and can fail/timeout once before the compute is ready. Retrying a
// few times with backoff rides through the cold start.
const runWithRetry = async (fn, retries = 5, baseDelayMs = 600) => {
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const msg = (err && (err.message || err.code)) || "unknown error";
      console.warn(
        `[migrate] attempt ${attempt}/${retries} failed (${msg}); retrying...`
      );
      await new Promise((r) => setTimeout(r, baseDelayMs * attempt));
    }
  }
  throw lastErr;
};

// Ensures all tables/indexes exist. Idempotent — safe on every server start.
const migrate = async () => {
  if (!isConfigured()) {
    console.warn("[migrate] DATABASE_URL not set; skipping migration");
    return;
  }
  const sql = fs.readFileSync(SCHEMA_PATH, "utf8");
  await runWithRetry(() => pool.query(sql));
  console.log("[migrate] schema ensured");
};

module.exports = { migrate };

// Allow running directly:  npm run migrate
if (require.main === module) {
  migrate()
    .then(() => {
      console.log("[migrate] done");
      process.exit(0);
    })
    .catch((err) => {
      console.error("[migrate] failed:", err.message);
      process.exit(1);
    });
}
