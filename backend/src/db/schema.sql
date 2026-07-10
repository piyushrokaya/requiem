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
