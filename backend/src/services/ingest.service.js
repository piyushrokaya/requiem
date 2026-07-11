const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const csv = require("csv-parser");
const { pool, isConfigured } = require("../config/pg");
const { stripHtml } = require("../utils/sanitizeText");

// The Python pipeline still writes these two files. This service reads them and
// loads the data into Postgres so the API can serve (and keep) history.
const DATA_DIR = path.join(__dirname, "../../data");
const CSV_PATH = path.join(DATA_DIR, "all_articles_processed.csv");
const CLUSTERS_PATH = path.join(DATA_DIR, "clusters.json");

const parsePublishedDate = (published) => {
  if (!published) return null;
  const dt = new Date(published);
  return Number.isNaN(dt.getTime()) ? null : dt;
};

const clean = (v) => (v || "").toString().replace(/^﻿/, "").trim();

// Convert one raw CSV row into the shape we store in the articles table.
const rowToArticle = (row, index) => {
  const link = clean(row.link);
  const source = clean(row.source) || "Unknown";
  const title = stripHtml(clean(row.title));
  const cleanText = stripHtml(clean(row.clean_text));
  const description = stripHtml(clean(row.description)) || cleanText;
  const category = clean(row.category);
  const content = cleanText || description;
  const sentiment = clean(row.sentiment) || null;

  const clusterRaw = Number.parseInt(row.cluster_id, 10);
  const cluster_id = Number.isNaN(clusterRaw) ? null : clusterRaw;

  const idBase = link || `${source}:${title}:${index}`;
  const id = crypto.createHash("sha1").update(idBase).digest("hex");

  return {
    id,
    source,
    title,
    description,
    link: link || null, // NULL so multiple empty links don't collide on UNIQUE
    content,
    category: category || null,
    cluster_id,
    sentiment,
    published_at: parsePublishedDate(row.published),
  };
};

const readArticlesFromCsv = () =>
  new Promise((resolve, reject) => {
    if (!fs.existsSync(CSV_PATH)) return resolve([]);
    const rows = [];
    fs.createReadStream(CSV_PATH)
      .pipe(csv({ mapHeaders: ({ header }) => header.trim() }))
      .on("data", (row) => rows.push(row))
      .on("end", () => resolve(rows.map((r, i) => rowToArticle(r, i))))
      .on("error", reject);
  });

// Dedupe by id (same link => same id). Last occurrence wins. This prevents the
// "ON CONFLICT cannot affect row a second time" error when a chunk has dupes.
const dedupeById = (articles) => {
  const map = new Map();
  for (const a of articles) map.set(a.id, a);
  return [...map.values()];
};

const ARTICLE_COLS = [
  "id",
  "source",
  "title",
  "description",
  "link",
  "content",
  "category",
  "cluster_id",
  "sentiment",
  "published_at",
];

const upsertArticles = async (articles) => {
  const rows = dedupeById(articles);
  if (!rows.length) return 0;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const CHUNK = 100;
    for (let i = 0; i < rows.length; i += CHUNK) {
      const chunk = rows.slice(i, i + CHUNK);
      const values = [];
      const tuples = chunk.map((a, r) => {
        const base = r * ARTICLE_COLS.length;
        ARTICLE_COLS.forEach((c) => values.push(a[c]));
        return `(${ARTICLE_COLS.map((_, c) => `$${base + c + 1}`).join(",")})`;
      });
      const sql = `
        INSERT INTO articles (${ARTICLE_COLS.join(",")})
        VALUES ${tuples.join(",")}
        ON CONFLICT (id) DO UPDATE SET
          source       = EXCLUDED.source,
          title        = EXCLUDED.title,
          description  = EXCLUDED.description,
          link         = EXCLUDED.link,
          content      = EXCLUDED.content,
          category     = EXCLUDED.category,
          cluster_id   = EXCLUDED.cluster_id,
          sentiment    = EXCLUDED.sentiment,
          published_at = EXCLUDED.published_at,
          updated_at   = now()
      `;
      await client.query(sql, values);
    }
    await client.query("COMMIT");
    return rows.length;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
};

const readClustersFromJson = async () => {
  if (!fs.existsSync(CLUSTERS_PATH)) return [];
  const raw = await fs.promises.readFile(CLUSTERS_PATH, "utf8");
  const parsed = JSON.parse(raw);
  return Array.isArray(parsed) ? parsed : [];
};

// Clusters are the CURRENT trending analysis; cluster ids are recomputed each
// run, so we replace the whole table rather than upsert.
const replaceClusters = async (clusters) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // DELETE (not TRUNCATE): the qa_pairs table has a FK to clusters, and
    // Postgres refuses to TRUNCATE a table referenced by a foreign key. DELETE
    // cascades to qa_pairs rows tied to the old (recomputed) cluster ids, while
    // leaving any cluster-independent cached Q&A (cluster_id IS NULL) intact.
    await client.query("DELETE FROM clusters");

    const seen = new Set();
    let inserted = 0;
    for (const c of clusters) {
      const cid = Number.parseInt(c.cluster_id, 10);
      if (Number.isNaN(cid) || seen.has(cid)) continue;
      seen.add(cid);

      await client.query(
        `INSERT INTO clusters
           (cluster_id, sources, titles, category, one_liner,
            short_summary, key_points, missing_info, coverage_breakdown, updated_at)
         VALUES ($1, $2::jsonb, $3::jsonb, $4, $5, $6, $7, $8, $9, now())`,
        [
          cid,
          JSON.stringify(Array.isArray(c.sources) ? c.sources : []),
          JSON.stringify(Array.isArray(c.titles) ? c.titles : []),
          c.category || null,
          c.one_liner || null,
          c.short_summary || null,
          c.key_points || null,
          c.missing_info || null,
          c.coverage_breakdown || null,
        ]
      );
      inserted += 1;
    }
    await client.query("COMMIT");
    return inserted;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
};

// Load both files into Postgres. Called by the scheduler after each Python run.
const ingestAll = async () => {
  if (!isConfigured()) {
    throw new Error("DATABASE_URL not configured; cannot ingest");
  }
  const articles = await readArticlesFromCsv();
  const articleCount = await upsertArticles(articles);

  const clusters = await readClustersFromJson();
  const clusterCount = await replaceClusters(clusters);

  return { articles: articleCount, clusters: clusterCount };
};

module.exports = { ingestAll, upsertArticles, replaceClusters };
