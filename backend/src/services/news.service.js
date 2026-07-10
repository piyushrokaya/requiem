const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const csv = require("csv-parser");
const { pool, isConfigured } = require("../config/pg");
const { runWithRetry } = require("../utils/dbRetry");
const { stripHtml } = require("../utils/sanitizeText");

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
  const title = stripHtml((row.title || "").trim());
  const cleanText = stripHtml((row.clean_text || "").trim());
  const rawDescription = stripHtml((row.description || "").trim());
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

const getNewsFromCsv = async ({ page = 1, limit = 10, category }) => {
  const safePage = Number(page) > 0 ? Number(page) : 1;
  const safeLimit = Number(limit) > 0 ? Number(limit) : 10;

  let rows = await readAllFromCsv();

  if (category) {
    const wanted = category.trim().toLowerCase();
    rows = rows.filter((r) => (r.category || "").trim().toLowerCase() === wanted);
  }

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
const getNewsFromDb = async ({ page = 1, limit = 10, category }) => {
  const safePage = Number(page) > 0 ? Number(page) : 1;
  const safeLimit = Number(limit) > 0 ? Number(limit) : 10;
  const offset = (safePage - 1) * safeLimit;

  const whereClause = category ? "WHERE lower(category) = lower($1)" : "";
  const categoryParams = category ? [category] : [];

  const totalRes = await runWithRetry(() =>
    pool.query(
      `SELECT COUNT(*)::int AS total FROM articles ${whereClause}`,
      categoryParams
    )
  );
  const total = totalRes.rows[0].total;
  const totalPages = Math.max(1, Math.ceil(total / safeLimit));

  const { rows } = await runWithRetry(() =>
    pool.query(
      `SELECT id, source, title, description, link, content, category,
              COALESCE(published_at, first_seen_at) AS created_at
         FROM articles
        ${whereClause}
        ORDER BY published_at DESC NULLS LAST
        LIMIT $${categoryParams.length + 1} OFFSET $${categoryParams.length + 2}`,
      [...categoryParams, safeLimit, offset]
    )
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

const getCategoriesFromDb = async () => {
  const { rows } = await runWithRetry(() =>
    pool.query(
      `SELECT DISTINCT category FROM articles
        WHERE category IS NOT NULL AND category <> ''
        ORDER BY category ASC`
    )
  );
  return rows.map((r) => r.category);
};

const getCategoriesFromCsv = async () => {
  const rows = await readAllFromCsv();
  const set = new Set();
  for (const r of rows) {
    const c = (r.category || "").trim();
    if (c) set.add(c);
  }
  return [...set].sort();
};

// Distinct category values currently available, for filter UIs / voice prompts.
const getCategories = async () => {
  if (isConfigured()) {
    try {
      return await getCategoriesFromDb();
    } catch (err) {
      console.error(
        "[news.service] DB category read failed, falling back to CSV:",
        err.message
      );
    }
  }
  return getCategoriesFromCsv();
};

module.exports = {
  getNews,
  getNewsFromDb,
  getNewsFromCsv,
  getCategories,
};