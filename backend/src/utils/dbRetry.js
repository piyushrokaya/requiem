// Neon scales compute to zero when idle, so the first query after a lull can
// fail/time out once before the compute wakes up. Retry a few times with
// backoff before giving up.
const runWithRetry = async (fn, retries = 3, baseDelayMs = 400) => {
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      await new Promise((r) => setTimeout(r, baseDelayMs * attempt));
    }
  }
  throw lastErr;
};

module.exports = { runWithRetry };
