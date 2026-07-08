import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const schema = readFileSync(new URL("./sql/sync_production_schema.sql", import.meta.url), "utf8");

function runSql(sql) {
    const result = spawnSync("sqlite3", [":memory:"], {
        input: `${schema}\n${sql}`,
        encoding: "utf8",
    });

    return {
        status: result.status,
        stdout: result.stdout.trim(),
        stderr: result.stderr.trim(),
    };
}

function assertConstraintFailure(name, sql, expectedMessage) {
    const result = runSql(`
PRAGMA foreign_keys = ON;
${sql}
`);

    assert.notEqual(result.status, 0, `Production schema must reject ${name}`);
    assert.match(result.stderr, expectedMessage, `Production schema rejected ${name} with unexpected error: ${result.stderr}`);
}

const defaultsResult = runSql(`
PRAGMA foreign_keys = ON;
.mode list
.separator |

INSERT INTO sync_environments (id, name, worker_route, d1_database_name, r2_bucket_name, is_production, created_at, updated_at)
VALUES ('env-1', 'production', '/api/sync/production/v1', 'wsp_sync_production', 'wsp-sync-production', 1, '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');

INSERT INTO sync_rollout_flags (id, environment_id, flag_key, updated_at)
VALUES ('flag-1', 'env-1', 'production-writes', '2026-07-08T00:00:00Z');

INSERT INTO sync_users (id, external_subject_hash, created_at, updated_at)
VALUES ('user-1', 'subject-hash-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');

INSERT INTO sync_devices (id, user_id, created_at)
VALUES ('device-1', 'user-1', '2026-07-08T00:00:00Z');

INSERT INTO sync_projects (id, user_id, created_at, updated_at)
VALUES ('project-1', 'user-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');

INSERT INTO sync_project_entitlements (project_id, user_id, created_at)
VALUES ('project-1', 'user-1', '2026-07-08T00:00:00Z');

INSERT INTO sync_device_cursors (project_id, device_id, updated_at)
VALUES ('project-1', 'device-1', '2026-07-08T00:00:00Z');

INSERT INTO sync_migration_runs (id, user_id, project_id, source_system, target_environment_id, updated_at)
VALUES ('migration-1', 'user-1', 'project-1', 'cloudkit', 'env-1', '2026-07-08T00:00:00Z');

INSERT INTO sync_operations (id, project_id, user_id, device_id, server_sequence, received_at, entity_type, entity_id, operation_type, schema_version)
VALUES ('op-1', 'project-1', 'user-1', 'device-1', 1, '2026-07-08T00:00:00Z', 'Project', 'project-1', 'upsert', 1);

INSERT INTO sync_projects (id, user_id, created_at, updated_at)
VALUES ('project-2', 'user-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');

INSERT INTO sync_operations (id, project_id, user_id, device_id, server_sequence, received_at, entity_type, entity_id, operation_type, schema_version)
VALUES ('op-2', 'project-2', 'user-1', 'device-1', 1, '2026-07-08T00:00:00Z', 'Project', 'project-2', 'upsert', 1);

INSERT INTO sync_audit_events (id, environment_id, user_id, project_id, device_id, event_type, created_at)
VALUES ('audit-1', 'env-1', 'user-1', 'project-1', 'device-1', 'schema_smoke', '2026-07-08T00:00:00Z');

SELECT 'schema_version', version FROM sync_schema_versions WHERE id = 'sync-production-foundation-v1';
SELECT 'environment_defaults', is_production, writes_enabled FROM sync_environments WHERE id = 'env-1';
SELECT 'rollout_defaults', enabled, rollout_percent, kill_switch_active FROM sync_rollout_flags WHERE id = 'flag-1';
SELECT 'user_defaults', consent_state, lifecycle_state FROM sync_users WHERE id = 'user-1';
SELECT 'device_defaults', lifecycle_state FROM sync_devices WHERE id = 'device-1';
SELECT 'project_defaults', source_system, migration_state, latest_sequence, writes_enabled FROM sync_projects WHERE id = 'project-1';
SELECT 'entitlement_defaults', role, can_read, can_write FROM sync_project_entitlements WHERE project_id = 'project-1' AND user_id = 'user-1';
SELECT 'cursor_defaults', last_pulled_sequence, last_pushed_sequence, last_applied_sequence, apply_state FROM sync_device_cursors WHERE project_id = 'project-1' AND device_id = 'device-1';
SELECT 'nullable_migration_payloads', preflight_summary_json IS NULL, progress_json IS NULL FROM sync_migration_runs WHERE id = 'migration-1';
SELECT 'nullable_operation_payloads', payload_json IS NULL, payload_r2_key IS NULL, payload_hash IS NULL FROM sync_operations WHERE id = 'op-1';
SELECT 'nullable_audit_details', redacted_details_json IS NULL FROM sync_audit_events WHERE id = 'audit-1';
SELECT 'project_scoped_operation_sequences', COUNT(*) FROM sync_operations WHERE server_sequence = 1;
`);

assert.equal(defaultsResult.status, 0, defaultsResult.stderr || "Production schema default smoke failed");
assert(defaultsResult.stdout.includes("schema_version|1"), "Production schema seed version must exist");
assert(defaultsResult.stdout.includes("environment_defaults|1|0"), "Production environment writes must default disabled");
assert(defaultsResult.stdout.includes("rollout_defaults|0|0|0"), "Rollout flags must default disabled with no rollout and no kill switch");
assert(defaultsResult.stdout.includes("user_defaults|missing|active"), "User consent/lifecycle defaults must remain fail-closed");
assert(defaultsResult.stdout.includes("device_defaults|active"), "Device lifecycle default must be active");
assert(defaultsResult.stdout.includes("project_defaults|cloudkit|not_started|0|0"), "Project sync defaults must remain non-writing/not-started");
assert(defaultsResult.stdout.includes("entitlement_defaults|owner|1|0"), "Project entitlements must default read-only");
assert(defaultsResult.stdout.includes("cursor_defaults|0|0|0|idle"), "Device cursors must default to idle zero state");
assert(defaultsResult.stdout.includes("nullable_migration_payloads|1|1"), "Migration summary/progress payload columns must remain nullable");
assert(defaultsResult.stdout.includes("nullable_operation_payloads|1|1|1"), "Operation payload/reference/hash columns must remain nullable");
assert(defaultsResult.stdout.includes("nullable_audit_details|1"), "Audit redacted details column must remain nullable");
assert(defaultsResult.stdout.includes("project_scoped_operation_sequences|2"), "Operation server sequences must be scoped per project, not globally unique");

const foreignKeyResult = runSql(`
PRAGMA foreign_keys = ON;
INSERT INTO sync_devices (id, user_id, created_at)
VALUES ('device-without-user', 'missing-user', '2026-07-08T00:00:00Z');
`);

assert.notEqual(foreignKeyResult.status, 0, "Production schema must reject devices without a valid user");
assert.match(foreignKeyResult.stderr, /FOREIGN KEY constraint failed/i, "Production schema must enforce user/device foreign keys");

assertConstraintFailure("duplicate environment names", `
INSERT INTO sync_environments (id, name, worker_route, d1_database_name, r2_bucket_name, created_at, updated_at)
VALUES ('env-1', 'production', '/api/sync/production/v1', 'wsp_sync_production', 'wsp-sync-production', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_environments (id, name, worker_route, d1_database_name, r2_bucket_name, created_at, updated_at)
VALUES ('env-2', 'production', '/api/sync/production/v1', 'wsp_sync_production', 'wsp-sync-production', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
`, /UNIQUE constraint failed: sync_environments\.name/i);

assertConstraintFailure("duplicate external subject hashes", `
INSERT INTO sync_users (id, external_subject_hash, created_at, updated_at)
VALUES ('user-1', 'subject-hash-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_users (id, external_subject_hash, created_at, updated_at)
VALUES ('user-2', 'subject-hash-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
`, /UNIQUE constraint failed: sync_users\.external_subject_hash/i);

assertConstraintFailure("duplicate rollout flags per environment", `
INSERT INTO sync_environments (id, name, worker_route, d1_database_name, r2_bucket_name, created_at, updated_at)
VALUES ('env-1', 'production', '/api/sync/production/v1', 'wsp_sync_production', 'wsp-sync-production', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_rollout_flags (id, environment_id, flag_key, updated_at)
VALUES ('flag-1', 'env-1', 'production-writes', '2026-07-08T00:00:00Z');
INSERT INTO sync_rollout_flags (id, environment_id, flag_key, updated_at)
VALUES ('flag-2', 'env-1', 'production-writes', '2026-07-08T00:00:00Z');
`, /UNIQUE constraint failed: sync_rollout_flags\.environment_id, sync_rollout_flags\.flag_key/i);

assertConstraintFailure("duplicate asset storage keys", `
INSERT INTO sync_users (id, external_subject_hash, created_at, updated_at)
VALUES ('user-1', 'subject-hash-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_projects (id, user_id, created_at, updated_at)
VALUES ('project-1', 'user-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_assets (id, project_id, entity_type, entity_id, r2_key, content_hash, byte_count, created_at, updated_at)
VALUES ('asset-1', 'project-1', 'TextFile', 'file-1', 'assets/project-1/file-1', 'hash-1', 12, '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_assets (id, project_id, entity_type, entity_id, r2_key, content_hash, byte_count, created_at, updated_at)
VALUES ('asset-2', 'project-1', 'TextFile', 'file-2', 'assets/project-1/file-1', 'hash-2', 24, '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
`, /UNIQUE constraint failed: sync_assets\.r2_key/i);

assertConstraintFailure("duplicate project operation sequences", `
INSERT INTO sync_users (id, external_subject_hash, created_at, updated_at)
VALUES ('user-1', 'subject-hash-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_devices (id, user_id, created_at)
VALUES ('device-1', 'user-1', '2026-07-08T00:00:00Z');
INSERT INTO sync_projects (id, user_id, created_at, updated_at)
VALUES ('project-1', 'user-1', '2026-07-08T00:00:00Z', '2026-07-08T00:00:00Z');
INSERT INTO sync_operations (id, project_id, user_id, device_id, server_sequence, received_at, entity_type, entity_id, operation_type, schema_version)
VALUES ('op-1', 'project-1', 'user-1', 'device-1', 1, '2026-07-08T00:00:00Z', 'Project', 'project-1', 'upsert', 1);
INSERT INTO sync_operations (id, project_id, user_id, device_id, server_sequence, received_at, entity_type, entity_id, operation_type, schema_version)
VALUES ('op-2', 'project-1', 'user-1', 'device-1', 1, '2026-07-08T00:00:00Z', 'Project', 'project-1', 'upsert', 1);
`, /UNIQUE constraint failed: sync_operations\.project_id, sync_operations\.server_sequence/i);

console.log("sync production schema smoke ok");