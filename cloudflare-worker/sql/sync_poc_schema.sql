-- WSP Cloudflare Sync POC schema (Cloudflare D1)
-- Phase 0: creates inspectable operation-log tables only.
-- Run with:
-- npx wrangler d1 execute wsp_sync_poc --file=./sql/sync_poc_schema.sql

CREATE TABLE IF NOT EXISTS sync_devices (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT
);

CREATE TABLE IF NOT EXISTS sync_projects (
  id TEXT PRIMARY KEY,
  canonical_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  latest_sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sync_operations (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  client_timestamp TEXT,
  received_at TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  base_sequence INTEGER,
  payload_json TEXT,
  payload_r2_key TEXT,
  payload_hash TEXT,
  FOREIGN KEY(project_id) REFERENCES sync_projects(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_operations_project_sequence
ON sync_operations(project_id, server_sequence);

CREATE INDEX IF NOT EXISTS idx_sync_operations_entity
ON sync_operations(project_id, entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_sync_operations_device
ON sync_operations(device_id, received_at);

CREATE TABLE IF NOT EXISTS sync_tombstones (
  project_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY(project_id, entity_type, entity_id)
);

CREATE TABLE IF NOT EXISTS sync_device_cursors (
  project_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  last_pulled_sequence INTEGER NOT NULL DEFAULT 0,
  last_pushed_sequence INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(project_id, device_id)
);

CREATE TABLE IF NOT EXISTS sync_snapshots (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  r2_key TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_snapshots_project_sequence
ON sync_snapshots(project_id, server_sequence DESC);

CREATE TABLE IF NOT EXISTS sync_conflicts (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  operation_id TEXT,
  device_id TEXT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  payload_json TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_conflicts_project_created
ON sync_conflicts(project_id, created_at DESC);
