const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const csv = require("csv-parser");
const { pool, isConfigured } = require("../config/pg");

// News is served from Postgres (Neon) when DATABASE_URL is configured, and
// falls back to reading the CSV directly otherwise. Both paths return the exact
// same JSON shape the Flutter app expects.

const CSV_PATH = path.join(__dirname, "../../data/all_articles_processed.csv");

const parsePublishedDate = (published) => {
  if (!published) return new Date(0);
  const dt = new Date(published);
  return Number.isNaN(dt.getTime()) ? new Date(0) : dt;
};

const rowToApiArticle = (row, index) => {
  const link = (row.link || "").trim();
  const source = (row.source || "Unknown").replace(/^\uFEFF/, "").trim();
  const title = (row.title || "").trim();
  const cleanText = (row.clean_text || "").trim();
  const rawDescription = (row.description || "").trim();
  const description = rawDescription || cleanText;
  const category = (row.category || "").trim();
  // Provide full article content when available.
  const content = cleanText || description;
  const createdAt = parsePublishedDate(row.published).toISOString();

  const idBase = link || `${source}:${title}:${index}`;
  const _id = crypto.createHash("sha1").update(idBase).digest("hex");

  return {
    _id,
    source,
    title,
    description,
    link,
    content,
    category,
    createdAt,
  };
};

const readAllFromCsv = async () => {
  return new Promise((resolve, reject) => {
    const rows = [];

    fs.createReadStream(CSV_PATH)
      .pipe(
        csv({
          mapHeaders: ({ header }) => header.trim(),
        })
      )
      .on("data", (row) => rows.push(row))
      .on("end", () => resolve(rows))
      .on("error", reject);
  });
};

const getNewsFromCsv = async ({ page = 1, limit = 10 }) => {
  const safePage = Number(page) > 0 ? Number(page) : 1;
  const safeLimit = Number(limit) > 0 ? Number(limit) : 10;

  const rows = await readAllFromCsv();

  // Sort newest first using published timestamp.
  rows.sort((a, b) => {
    const ad = parsePublishedDate(a.published).getTime();
    const bd = parsePublishedDate(b.published).getTime();
    return bd - ad;
  });

  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / safeLimit));
  const start = (safePage - 1) * safeLimit;
  const end = start + safeLimit;

  const data = rows
    .slice(start, end)
    .map((row, idx) => rowToApiArticle(row, start + idx));

  return {
    data,
    page: safePage,
    totalPages,
  };
};

// Read a page of news from Postgres, newest first.
const getNewsFromDb = async ({ page = 1, limit = 10 }) => {
  const safePage = Number(page) > 0 ? Number(page) : 1;
  const safeLimit = Number(limit) > 0 ? Number(limit) : 10;
  const offset = (safePage - 1) * safeLimit;

  const totalRes = await pool.query("SELECT COUNT(*)::int AS total FROM articles");
  const total = totalRes.rows[0].total;
  const totalPages = Math.max(1, Math.ceil(total / safeLimit));

  const { rows } = await pool.query(
    `SELECT id, source, title, description, link, content, category,
            COALESCE(published_at, first_seen_at) AS created_at
       FROM articles
      ORDER BY published_at DESC NULLS LAST
      LIMIT $1 OFFSET $2`,
    [safeLimit, offset]
  );

  const data = rows.map((r) => ({
    _id: r.id,
    source: r.source || "Unknown",
    title: r.title || "",
    description: r.description || "",
    link: r.link || "",
    content: r.content || "",
    category: r.category || "",
    createdAt: new Date(r.created_at).toISOString(),
  }));

  return { data, page: safePage, totalPages };
};

// Preferred entry point: use the DB when configured, else fall back to CSV.
const getNews = async (opts) => {
  if (isConfigured()) {
    try {
      return await getNewsFromDb(opts);
    } catch (err) {
      console.error(
        "[news.service] DB read failed, falling back to CSV:",
        err.message
      );
    }
  }
  return getNewsFromCsv(opts);
};

module.exports = {
  getNews,
  getNewsFromDb,
  getNewsFromCsv,
};