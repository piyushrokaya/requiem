const express = require("express");
const router = express.Router();
const {
  getNews,
  getNewsById,
  getNewsBySource,
  getNewsByCluster,
  getSources,
  getStats,
  triggerFetch,
} = require("../controllers/newsController");

// Static routes first (before parameterized)
router.get("/", getNews);                          // GET /api/news
router.get("/sources", getSources);                // GET /api/news/sources
router.get("/stats", getStats);                    // GET /api/news/stats
router.post("/fetch", triggerFetch);               // POST /api/news/fetch

// Parameterized routes
router.get("/source/:source", getNewsBySource);    // GET /api/news/source/:source
router.get("/cluster/:clusterId", getNewsByCluster); // GET /api/news/cluster/:clusterId
router.get("/:id", getNewsById);                   // GET /api/news/:id

module.exports = router;