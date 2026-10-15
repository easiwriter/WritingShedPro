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
  created_at INTEGER NOT NULL,
  conversion_transaction_id TEXT,
  conversion_purchase_date INTEGER
);

CREATE INDEX IF NOT EXISTS idx_sales_events_month
ON sales_events(sale_month DESC, project_type);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_events_conversion_transaction
ON sales_events(conversion_transaction_id)
WHERE conversion_transaction_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS verified_store_transactions (
  transaction_id TEXT PRIMARY KEY,
  original_transaction_id TEXT,
  product_id TEXT NOT NULL,
  purchase_date INTEGER NOT NULL,
  original_purchase_date INTEGER,
  ownership_type TEXT,
  transaction_type TEXT,
  price INTEGER,
  currency TEXT,
  offer_type INTEGER,
  offer_identifier TEXT,
  environment TEXT NOT NULL,
  verified_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS transaction_verification_failures (
  transaction_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  failure_category TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  reason TEXT NOT NULL,
  first_seen_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 1,
  is_resolved INTEGER NOT NULL DEFAULT 0,
  resolved_at INTEGER,
  PRIMARY KEY (transaction_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_transaction_verification_failures_status
ON transaction_verification_failures(is_resolved, last_seen_at DESC);

CREATE TABLE IF NOT EXISTS monthly_sales (
  sale_month TEXT NOT NULL,
  project_type TEXT NOT NULL,
  sale_count INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (sale_month, project_type)
);

CREATE INDEX IF NOT EXISTS idx_monthly_sales_month
ON monthly_sales(sale_month DESC);
