require("dotenv").config();
const { Pool } = require("pg");

// We use Neon (serverless Postgres). Paste the Neon connection string into
// DATABASE_URL in your .env file. Until then, the API silently falls back to
// reading the CSV / clusters.json files so the server still runs.
const connectionString = process.env.DATABASE_URL;

let pool = null;

if (connectionString) {
  pool = new Pool({
    connectionString,
    // Neon requires SSL. rejectUnauthorized:false avoids CA-chain issues with
    // the pooled endpoint while still encrypting the connection.
    ssl: { rejectUnauthorized: false },
    max: Number(process.env.PG_POOL_MAX) || 10,
  });

  pool.on("error", (err) => {
    console.error("[pg] unexpected idle client error:", err.message);
  });

  console.log("[pg] Postgres pool initialised");
} else {
  console.warn(
    "[pg] DATABASE_URL not set — Postgres disabled, using file/CSV fallback"
  );
}

const isConfigured = () => pool !== null;

const query = (text, params) => {
  if (!pool) throw new Error("DATABASE_URL not configured");
  return pool.query(text, params);
};

module.exports = { pool, query, isConfigured };
