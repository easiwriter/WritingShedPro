-- WSP Messages schema (Cloudflare D1)
-- Run with:
-- npx wrangler d1 execute <DATABASE_NAME> --file=./sql/messages_schema.sql

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  is_critical INTEGER NOT NULL DEFAULT 0 CHECK (is_critical IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_messages_archived_updated
ON messages(is_archived, updated_at DESC);
