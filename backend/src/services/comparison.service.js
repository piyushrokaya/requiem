const fs = require("fs");
const path = require("path");
const { pool, isConfigured } = require("../config/pg");

const CLUSTERS_PATH = path.join(__dirname, "../../data/clusters.json");

// Read a page of clusters from Postgres.
const getClustersFromDb = async ({ page, limit }) => {
  const offset = (page - 1) * limit;
  const { rows } = await pool.query(
    `SELECT cluster_id, sources, titles, category, one_liner,
            short_summary, key_points, missing_info, coverage_breakdown
       FROM clusters
      ORDER BY cluster_id ASC
      LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  return rows.map((r) => ({
    cluster_id: r.cluster_id,
    sources: r.sources || [],
    titles: r.titles || [],
    category: r.category || "",
    one_liner: r.one_liner || "",
    short_summary: r.short_summary || "",
    key_points: r.key_points || "",
    missing_info: r.missing_info || "",
    coverage_breakdown: r.coverage_breakdown || "",
  }));
};

// Fallback: read the clusters.json file directly.
const getClustersFromFile = async ({ page, limit }) => {
  const raw = await fs.promises.readFile(CLUSTERS_PATH, "utf8");
  const parsed = JSON.parse(raw);
  const clusters = Array.isArray(parsed) ? parsed : [];
  const start = (page - 1) * limit;
  return clusters.slice(start, start + limit);
};

const getClusters = async (opts) => {
  if (isConfigured()) {
    try {
      return await getClustersFromDb(opts);
    } catch (err) {
      console.error(
        "[comparison.service] DB read failed, falling back to file:",
        err.message
      );
    }
  }
  return getClustersFromFile(opts);
};

module.exports = { getClusters };
