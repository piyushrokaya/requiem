// Manually trigger one news refresh (run Python pipeline + ingest to Postgres).
// Usage: npm run refresh
const { runRefresh } = require("../src/jobs/refreshNews.job");

runRefresh()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
