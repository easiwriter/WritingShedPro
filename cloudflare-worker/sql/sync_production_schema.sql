-- WSP Cloudflare Sync production foundation schema (Cloudflare D1)
-- Server foundation only: no app-side SwiftData mutation is wired to this schema.
-- Run only after creating an environment-specific production sync database:
-- npx wrangler d1 execute wsp_sync_production --remote --file=./sql/sync_production_schema.sql

CREATE TABLE IF NOT EXISTS sync_schema_versions (
  id TEXT PRIMARY KEY,
  schema_name TEXT NOT NULL,
  version INTEGER NOT NULL,
  applied_at TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS sync_environments (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  worker_route TEXT NOT NULL,
  d1_database_name TEXT NOT NULL,
  r2_bucket_name TEXT NOT NULL,
  is_production INTEGER NOT NULL DEFAULT 0,
  writes_enabled INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_rollout_flags (
  id TEXT PRIMARY KEY,
  environment_id TEXT NOT NULL,
  flag_key TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 0,
  rollout_percent INTEGER NOT NULL DEFAULT 0,
  kill_switch_active INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  updated_at TEXT NOT NULL,
  updated_by TEXT,
  UNIQUE(environment_id, flag_key),
  FOREIGN KEY(environment_id) REFERENCES sync_environments(id)
);

CREATE TABLE IF NOT EXISTS sync_users (
  id TEXT PRIMARY KEY,
  account_id TEXT,
  external_subject_hash TEXT NOT NULL UNIQUE,
  consent_state TEXT NOT NULL DEFAULT 'missing',
  lifecycle_state TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revoked_at TEXT,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_users_account
ON sync_users(account_id, lifecycle_state);

CREATE TABLE IF NOT EXISTS sync_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  display_name TEXT,
  platform TEXT,
  app_version TEXT,
  schema_version INTEGER,
  lifecycle_state TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  last_seen_at TEXT,
  revoked_at TEXT,
  FOREIGN KEY(user_id) REFERENCES sync_users(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_devices_user
ON sync_devices(user_id, lifecycle_state);

CREATE TABLE IF NOT EXISTS sync_projects (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  canonical_name TEXT,
  project_type TEXT,
  source_system TEXT NOT NULL DEFAULT 'cloudkit',
  migration_state TEXT NOT NULL DEFAULT 'not_started',
  latest_sequence INTEGER NOT NULL DEFAULT 0,
  writes_enabled INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  FOREIGN KEY(user_id) REFERENCES sync_users(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_projects_user
ON sync_projects(user_id, migration_state, updated_at DESC);

CREATE TABLE IF NOT EXISTS sync_project_entitlements (
  project_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'owner',
  can_read INTEGER NOT NULL DEFAULT 1,
  can_write INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  PRIMARY KEY(project_id, user_id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(user_id) REFERENCES sync_users(id)
);

CREATE TABLE IF NOT EXISTS sync_migration_runs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  project_id TEXT,
  source_system TEXT NOT NULL,
  target_environment_id TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'planned',
  preflight_summary_json TEXT,
  progress_json TEXT,
  failure_reason TEXT,
  started_at TEXT,
  completed_at TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES sync_users(id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(target_environment_id) REFERENCES sync_environments(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_migration_runs_user_state
ON sync_migration_runs(user_id, state, updated_at DESC);

CREATE TABLE IF NOT EXISTS sync_assets (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  r2_key TEXT NOT NULL UNIQUE,
  content_hash TEXT NOT NULL,
  byte_count INTEGER NOT NULL,
  transfer_state TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY(project_id) REFERENCES sync_projects(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_assets_entity
ON sync_assets(project_id, entity_type, entity_id, transfer_state);

CREATE TABLE IF NOT EXISTS sync_operations (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  client_sequence INTEGER,
  client_timestamp TEXT,
  received_at TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  base_sequence INTEGER,
  payload_json TEXT,
  payload_r2_key TEXT,
  payload_hash TEXT,
  schema_version INTEGER NOT NULL,
  apply_blocked_reason TEXT,
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(user_id) REFERENCES sync_users(id),
  FOREIGN KEY(device_id) REFERENCES sync_devices(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_operations_project_sequence
ON sync_operations(project_id, server_sequence);

CREATE INDEX IF NOT EXISTS idx_sync_operations_entity
ON sync_operations(project_id, entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_sync_operations_device
ON sync_operations(device_id, received_at);

CREATE TABLE IF NOT EXISTS sync_device_cursors (
  project_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  last_pulled_sequence INTEGER NOT NULL DEFAULT 0,
  last_pushed_sequence INTEGER NOT NULL DEFAULT 0,
  last_applied_sequence INTEGER NOT NULL DEFAULT 0,
  apply_state TEXT NOT NULL DEFAULT 'idle',
  updated_at TEXT NOT NULL,
  PRIMARY KEY(project_id, device_id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(device_id) REFERENCES sync_devices(id)
);

CREATE TABLE IF NOT EXISTS sync_tombstones (
  project_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  deleted_at TEXT NOT NULL,
  deleted_by_device_id TEXT,
  PRIMARY KEY(project_id, entity_type, entity_id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(operation_id) REFERENCES sync_operations(id)
);

CREATE TABLE IF NOT EXISTS sync_audit_events (
  id TEXT PRIMARY KEY,
  environment_id TEXT NOT NULL,
  user_id TEXT,
  project_id TEXT,
  device_id TEXT,
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info',
  redacted_details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(environment_id) REFERENCES sync_environments(id),
  FOREIGN KEY(user_id) REFERENCES sync_users(id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id),
  FOREIGN KEY(device_id) REFERENCES sync_devices(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_audit_events_project_created
ON sync_audit_events(project_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_audit_events_user_created
ON sync_audit_events(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS sync_support_actions (
  id TEXT PRIMARY KEY,
  environment_id TEXT NOT NULL,
  user_id TEXT,
  project_id TEXT,
  action_type TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'requested',
  redacted_reason TEXT,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  FOREIGN KEY(environment_id) REFERENCES sync_environments(id),
  FOREIGN KEY(user_id) REFERENCES sync_users(id),
  FOREIGN KEY(project_id) REFERENCES sync_projects(id)
);

INSERT OR IGNORE INTO sync_schema_versions (id, schema_name, version, applied_at, notes)
VALUES ('sync-production-foundation-v1', 'sync_production', 1, datetime('now'), 'Production foundation schema only; no app mutation wired.');