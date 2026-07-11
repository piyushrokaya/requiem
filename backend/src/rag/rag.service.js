const { pool, isConfigured } = require("../config/pg");
const { runWithRetry } = require("../utils/dbRetry");
const { extractKeywords } = require("./nepaliStopwords");

const MAX_ARTICLES = 6;
const MAX_CLUSTERS = 3;
const BODY_CHARS = 500;

// to_tsquery blows up on bare operator characters (& | ! ( ) : '), so strip
// anything that isn't a letter/digit from each keyword. Devanagari letters
// pass through \w in JS's unicode-unaware regex, so we allow anything except
// the small set of tsquery-special punctuation.
const sanitizeKeywords = (keywords) =>
  keywords.map((k) => k.replace(/['&|!():*]/g, "").trim()).filter(Boolean);

// 'simple' config does exact-lexeme matching, not stemming — and Nepali
// glues postpositions straight onto the stem (ट्रम्प + को → ट्रम्पको), so a
// bare keyword from a question almost never matches the inflected form
// stored in search_vector. Prefix-match (word:*) instead of exact match so
// "ट्रम्प" still hits "ट्रम्पको"/"ट्रम्पले" etc.
const toTsQuery = (safeKeywords) => {
  if (!safeKeywords.length) return null;
  return safeKeywords.map((k) => `${k}:*`).join(" | ");
};

// ts_rank alone doesn't weight rare vs. common terms (no idf), so a single
// generic word shared with an unrelated story can outrank the real match —
// this is exactly what surfaced an unrelated cluster during testing. Instead
// we shortlist candidates with the OR tsquery (fast, uses the GIN index),
// then re-score that shortlist by how many DISTINCT question keywords each
// row actually matches — the same "count the overlap" idea the pipeline's
// own token_overlap() clustering uses, just applied at query time.
const searchArticles = async (tsQuery, keywords, limit) => {
  const { rows } = await runWithRetry(() =>
    pool.query(
      `SELECT a.id, a.source, a.title, a.content, a.category, a.published_at,
              count(*) FILTER (
                WHERE a.search_vector @@ to_tsquery('simple', kw.word || ':*')
              ) AS match_count,
              sum(ts_rank(a.search_vector, to_tsquery('simple', kw.word || ':*'))) AS rank_sum
         FROM articles a
         CROSS JOIN unnest($2::text[]) AS kw(word)
        WHERE a.search_vector @@ to_tsquery('simple', $1)
        GROUP BY a.id, a.source, a.title, a.content, a.category, a.published_at
        ORDER BY match_count DESC, rank_sum DESC, a.published_at DESC NULLS LAST
        LIMIT $3`,
      [tsQuery, keywords, limit]
    )
  );
  return rows;
};

const searchClusters = async (tsQuery, keywords, limit) => {
  const { rows } = await runWithRetry(() =>
    pool.query(
      `SELECT c.cluster_id, c.sources, c.titles, c.category, c.one_liner,
              c.short_summary, c.key_points, c.coverage_breakdown, c.missing_info,
              count(*) FILTER (
                WHERE c.search_vector @@ to_tsquery('simple', kw.word || ':*')
              ) AS match_count,
              sum(ts_rank(c.search_vector, to_tsquery('simple', kw.word || ':*'))) AS rank_sum
         FROM clusters c
         CROSS JOIN unnest($2::text[]) AS kw(word)
        WHERE c.search_vector @@ to_tsquery('simple', $1)
        GROUP BY c.cluster_id, c.sources, c.titles, c.category, c.one_liner,
                 c.short_summary, c.key_points, c.coverage_breakdown, c.missing_info
        ORDER BY match_count DESC, rank_sum DESC
        LIMIT $3`,
      [tsQuery, keywords, limit]
    )
  );
  return rows;
};

const articlesByCluster = async (clusterId, limit) => {
  const { rows } = await runWithRetry(() =>
    pool.query(
      `SELECT id, source, title, content, category, published_at
         FROM articles
        WHERE cluster_id = $1
        ORDER BY published_at DESC NULLS LAST
        LIMIT $2`,
      [clusterId, limit]
    )
  );
  return rows;
};

// Builds the context block handed to Gemini, plus a light-weight list of
// sources so the API response can show/read out "according to Gorkhapatra…".
const buildContext = ({ clusters, articles }) => {
  const blocks = [];
  const sources = new Set();

  for (const c of clusters) {
    const srcList = Array.isArray(c.sources) ? c.sources : [];
    srcList.forEach((s) => sources.add(s));
    blocks.push(
      [
        `CLUSTER (${c.category || "General"}) — sources: ${srcList.join(", ")}`,
        `ONE-LINER: ${c.one_liner || ""}`,
        `SUMMARY: ${c.short_summary || ""}`,
        `KEY POINTS: ${c.key_points || ""}`,
        `COVERAGE: ${c.coverage_breakdown || ""}`,
        `GAPS: ${c.missing_info || ""}`,
      ].join("\n")
    );
  }

  for (const a of articles) {
    sources.add(a.source);
    blocks.push(
      `SOURCE: ${a.source}\nTITLE: ${a.title}\nBODY: ${String(
        a.content || ""
      ).slice(0, BODY_CHARS)}`
    );
  }

  return { context: blocks.join("\n\n---\n\n"), sources: [...sources] };
};

// Live retrieval for a question. If clusterId is given (user is asking about
// a specific story on the तुलना screen), scope to that cluster only —
// otherwise search across everything, keyword-ranked, same as the pipeline's
// no-embeddings philosophy.
const retrieveContext = async ({ question, clusterId }) => {
  if (!isConfigured()) {
    throw new Error("DATABASE_URL not configured — RAG requires Postgres");
  }

  if (clusterId) {
    const articles = await articlesByCluster(clusterId, MAX_ARTICLES);
    const clusterRow = await runWithRetry(() =>
      pool.query(
        `SELECT cluster_id, sources, titles, category, one_liner, short_summary,
                key_points, coverage_breakdown, missing_info
           FROM clusters WHERE cluster_id = $1`,
        [clusterId]
      )
    );
    return buildContext({ clusters: clusterRow.rows, articles });
  }

  const keywords = sanitizeKeywords(extractKeywords(question));
  const tsQuery = toTsQuery(keywords);

  if (!tsQuery) {
    return { context: "", sources: [] };
  }

  const [clusters, articles] = await Promise.all([
    searchClusters(tsQuery, keywords, MAX_CLUSTERS),
    searchArticles(tsQuery, keywords, MAX_ARTICLES),
  ]);

  return buildContext({ clusters, articles });
};

module.exports = { retrieveContext, extractKeywords };
