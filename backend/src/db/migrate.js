const fs = require("fs");
const path = require("path");
const { pool, isConfigured } = require("../config/pg");
const { runWithRetry } = require("../utils/dbRetry");

const SCHEMA_PATH = path.join(__dirname, "schema.sql");

// Ensures all tables/indexes exist. Idempotent — safe on every server start.
const migrate = async () => {
  if (!isConfigured()) {
    console.warn("[migrate] DATABASE_URL not set; skipping migration");
    return;
  }
  const sql = fs.readFileSync(SCHEMA_PATH, "utf8");
  await runWithRetry(() => pool.query(sql), 5, 600);
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
