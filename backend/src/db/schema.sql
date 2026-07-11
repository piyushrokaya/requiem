-- Schema for the Sanksep news backend (Neon / Postgres).
-- Safe to run repeatedly: everything uses IF NOT EXISTS.

-- All news articles ever fetched. This table ACCUMULATES history — old news is
-- never deleted, only inserted or refreshed (upsert on id). That is what lets
-- us serve "old news too" on demand.
CREATE TABLE IF NOT EXISTS articles (
  id            TEXT PRIMARY KEY,                 -- sha1(link) or sha1(source:title:index)
  source        TEXT NOT NULL DEFAULT 'Unknown',
  title         TEXT NOT NULL DEFAULT '',
  description   TEXT NOT NULL DEFAULT '',
  link          TEXT UNIQUE,                      -- nullable: multiple NULLs allowed
  content       TEXT,
  category      TEXT,
  cluster_id    INTEGER,
  sentiment     TEXT,
  published_at  TIMESTAMPTZ,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_articles_published_at
  ON articles (published_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_articles_cluster_id ON articles (cluster_id);
CREATE INDEX IF NOT EXISTS idx_articles_category ON articles (category);

-- Trending multi-source clusters (the /api/compare data). These are the LLM's
-- current analysis and are fully replaced on every refresh, because cluster ids
-- are recomputed each pipeline run.
CREATE TABLE IF NOT EXISTS clusters (
  cluster_id         INTEGER PRIMARY KEY,
  sources            JSONB NOT NULL DEFAULT '[]'::jsonb,
  titles             JSONB NOT NULL DEFAULT '[]'::jsonb,
  category           TEXT,
  one_liner          TEXT,
  short_summary      TEXT,
  key_points         TEXT,
  missing_info       TEXT,
  coverage_breakdown TEXT,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── RAG (QnA) support ──────────────────────────────────────────
-- Full-text search columns, no embeddings. We tested multilingual embeddings
-- on Nepali (Devanagari) in the pipeline and they perform worse than plain
-- keyword overlap, so retrieval here uses Postgres tsvector/ts_rank instead —
-- same "no embeddings" philosophy as the clustering step, just at query time.
-- 'simple' config is used (no English stemming dictionary would help Nepali
-- anyway); it still normalises whitespace/punctuation which is all we need.
ALTER TABLE articles ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(content, ''))
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_articles_search_vector
  ON articles USING GIN (search_vector);

ALTER TABLE clusters ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('simple',
      coalesce(one_liner, '') || ' ' || coalesce(short_summary, '') || ' ' ||
      coalesce(key_points, '') || ' ' || coalesce(coverage_breakdown, '') || ' ' ||
      coalesce(missing_info, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_clusters_search_vector
  ON clusters USING GIN (search_vector);

-- Pre-generated + live Q&A pairs. Not read yet by the live retrieval path,
-- but kept ready so common questions can later be served from cache instead
-- of hitting Gemini every time.
CREATE TABLE IF NOT EXISTS qa_pairs (
  id          SERIAL PRIMARY KEY,
  cluster_id  INTEGER REFERENCES clusters(cluster_id) ON DELETE CASCADE,
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qa_pairs_cluster_id ON qa_pairs (cluster_id);
