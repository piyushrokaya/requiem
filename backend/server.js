require("dotenv").config();
const app = require("./src/app");
const { isConfigured } = require("./src/config/pg");
const { migrate } = require("./src/db/migrate");
const { startScheduler } = require("./src/jobs/refreshNews.job");

const PORT = process.env.PORT || 5000;

const start = async () => {
  // Ensure the Postgres tables exist (no-op if DATABASE_URL isn't set yet).
  if (isConfigured()) {
    try {
      await migrate();
    } catch (err) {
      console.error("DB migration failed:", err.stack || err.message || err);
    }
  } else {
    console.log("DATABASE_URL not set; serving from files (CSV fallback mode)");
  }

  // Start the news refresh scheduler (runs the Python pipeline + ingests to DB).
  startScheduler();

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
};

start();
