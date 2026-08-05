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

CREATE TABLE IF NOT EXISTS sales_events (
  transaction_id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  project_type TEXT NOT NULL,
  sale_month TEXT NOT NULL,
  purchase_date INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sales_events_month
ON sales_events(sale_month DESC, project_type);

CREATE TABLE IF NOT EXISTS monthly_sales (
  sale_month TEXT NOT NULL,
  project_type TEXT NOT NULL,
  sale_count INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (sale_month, project_type)
);

CREATE INDEX IF NOT EXISTS idx_monthly_sales_month
ON monthly_sales(sale_month DESC);
