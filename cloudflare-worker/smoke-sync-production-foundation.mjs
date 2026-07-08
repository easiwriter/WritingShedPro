import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const workerSource = readFileSync(new URL("./src/index.js", import.meta.url), "utf8")
    .replace('import SYSTEM_PROMPT from "./system-prompt.txt";', 'const SYSTEM_PROMPT = "";');
const productionContract = JSON.parse(readFileSync(new URL("./sync-production-foundation-contract.json", import.meta.url), "utf8"));
const workerModule = await import(`data:text/javascript;base64,${Buffer.from(workerSource).toString("base64")}`);
const worker = workerModule.default;

const productionToken = "production-smoke-token";
const productionBaseUrl = "https://wsp.example.test/api/sync/production/v1";
const routeSpecificSmokeCoverage = new Set([
    "/health",
    "/users/summary",
    "/identity/check",
    "/identity/enrollment/preflight",
    "/entitlements/preflight",
    "/environment/preflight",
    "/migration/preflight",
    "/assets/preflight",
    "/apply/preflight",
    "/orchestrator/eligibility",
    "/release/readiness",
]);

assert.deepEqual(
    [...routeSpecificSmokeCoverage].sort(),
    productionContract.routes.map((route) => route.route).sort(),
    "Every production route in the contract must have deliberate route-specific smoke coverage"
);

function makeRequest(path, options = {}) {
    const headers = new Headers(options.headers ?? {});
    if (!headers.has("Content-Type") && options.body !== undefined) {
        headers.set("Content-Type", "application/json");
    }

    return new Request(`${productionBaseUrl}${path}`, {
        method: options.method ?? "POST",
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
    });
}

function makeRawRequest(path, options = {}) {
    const headers = new Headers(options.headers ?? {});
    if (!headers.has("Content-Type")) {
        headers.set("Content-Type", "application/json");
    }

    return new Request(`${productionBaseUrl}${path}`, {
        method: options.method ?? "POST",
        headers,
        body: options.body,
    });
}

function makeAggregateOnlyDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production users summary must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production users summary must not prepare mutation SQL");

            return {
                bind: forbiddenMutation,
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            total_user_count: 7,
                            active_user_count: 5,
                            consent_granted_user_count: 4,
                            revoked_or_deleted_user_count: 1,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            total_device_count: 9,
                            active_device_count: 6,
                            revoked_device_count: 2,
                        };
                    }
                    throw new Error(`Unexpected aggregate table query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeIdentityCheckDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production identity smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production identity check must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production identity check must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            account_id: "account-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            role: "owner",
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    throw new Error(`Unexpected identity check query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeIdentityEnrollmentPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production identity enrollment smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production identity enrollment preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production identity enrollment preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            account_id: "account-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    throw new Error(`Unexpected identity enrollment preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeUnregisteredIdentityEnrollmentPreflightDb() {
    const db = makeIdentityEnrollmentPreflightDb();
    const originalPrepare = db.prepare.bind(db);

    return {
        preparedStatements: db.preparedStatements,
        prepare(sql) {
            const statement = originalPrepare(sql);

            return {
                ...statement,
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return null;
                    }
                    throw new Error(`Unexpected unregistered identity enrollment preflight query: ${sql}`);
                },
            };
        },
        batch: db.batch,
        exec: db.exec,
        dump: db.dump,
    };
}

function makeRevokedIdentityEnrollmentPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production revoked identity enrollment smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production revoked identity enrollment preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production revoked identity enrollment preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            account_id: "account-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: "2026-07-08T00:00:00Z",
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: "2026-07-08T00:00:00Z",
                        };
                    }
                    throw new Error(`Unexpected revoked identity enrollment preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeEntitlementsPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production entitlement smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production entitlements preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production entitlements preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_projects")) {
                        return {
                            id: "project-1",
                            migration_state: "ready",
                            writes_enabled: 0,
                            archived_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            role: "owner",
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    throw new Error(`Unexpected entitlements preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeMissingProjectEntitlementsPreflightDb() {
    const db = makeEntitlementsPreflightDb();
    const originalPrepare = db.prepare.bind(db);

    return {
        preparedStatements: db.preparedStatements,
        prepare(sql) {
            const statement = originalPrepare(sql);

            return {
                ...statement,
                async first() {
                    if (sql.includes("FROM sync_projects") || sql.includes("FROM sync_project_entitlements")) {
                        return null;
                    }
                    return statement.first();
                },
            };
        },
        batch: db.batch,
        exec: db.exec,
        dump: db.dump,
    };
}

function makeUnregisteredEntitlementsPreflightDb() {
    const db = makeEntitlementsPreflightDb();
    const originalPrepare = db.prepare.bind(db);

    return {
        preparedStatements: db.preparedStatements,
        prepare(sql) {
            const statement = originalPrepare(sql);

            return {
                ...statement,
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return null;
                    }
                    throw new Error(`Unexpected unregistered entitlements preflight query: ${sql}`);
                },
            };
        },
        batch: db.batch,
        exec: db.exec,
        dump: db.dump,
    };
}

function makeConsentMissingEntitlementsPreflightDb() {
    const db = makeEntitlementsPreflightDb();
    const originalPrepare = db.prepare.bind(db);

    return {
        preparedStatements: db.preparedStatements,
        prepare(sql) {
            const statement = originalPrepare(sql);

            return {
                ...statement,
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "missing",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    return statement.first();
                },
            };
        },
        batch: db.batch,
        exec: db.exec,
        dump: db.dump,
    };
}

function makeRevokedEntitlementsPreflightDb() {
    const db = makeEntitlementsPreflightDb();
    const originalPrepare = db.prepare.bind(db);

    return {
        preparedStatements: db.preparedStatements,
        prepare(sql) {
            const statement = originalPrepare(sql);

            return {
                ...statement,
                async first() {
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            role: "owner",
                            can_read: 1,
                            can_write: 1,
                            revoked_at: "2026-07-08T00:00:00Z",
                        };
                    }
                    return statement.first();
                },
            };
        },
        batch: db.batch,
        exec: db.exec,
        dump: db.dump,
    };
}

function makeMigrationPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production migration smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production migration preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production migration preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_projects")) {
                        return {
                            id: "project-1",
                            migration_state: "ready",
                            writes_enabled: 0,
                            archived_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    throw new Error(`Unexpected migration preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeNoQueryDb() {
    const forbiddenQuery = () => {
        throw new Error("Production smoke DB mock received a query before JSON validation completed");
    };

    return {
        prepare: forbiddenQuery,
        batch: forbiddenQuery,
        exec: forbiddenQuery,
        dump: forbiddenQuery,
    };
}

function makeNoWriteBlobStorage() {
    const forbiddenBlobWrite = () => {
        throw new Error("Production asset smoke blob mock received a write/upload call");
    };

    return {
        put: forbiddenBlobWrite,
        delete: forbiddenBlobWrite,
        createMultipartUpload: forbiddenBlobWrite,
        resumeMultipartUpload: forbiddenBlobWrite,
    };
}

function makeAssetPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production asset smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production asset preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production asset preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_projects")) {
                        return {
                            id: "project-1",
                            migration_state: "ready",
                            writes_enabled: 0,
                            archived_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    throw new Error(`Unexpected asset preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeApplyPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production apply smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production apply preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production apply preflight must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_projects")) {
                        return {
                            id: "project-1",
                            migration_state: "ready",
                            writes_enabled: 1,
                            latest_sequence: 1,
                            archived_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_device_cursors")) {
                        return {
                            last_applied_sequence: 0,
                            apply_state: "idle",
                        };
                    }
                    throw new Error(`Unexpected apply preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeOrchestratorEligibilityDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production orchestrator smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production orchestrator eligibility must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production orchestrator eligibility must not prepare mutation SQL");

            return {
                bind() {
                    return this;
                },
                async first() {
                    if (sql.includes("FROM sync_users")) {
                        return {
                            id: "user-1",
                            consent_state: "granted",
                            lifecycle_state: "active",
                            revoked_at: null,
                            deleted_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_devices")) {
                        return {
                            id: "device-1",
                            lifecycle_state: "active",
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_projects")) {
                        return {
                            id: "project-1",
                            writes_enabled: 1,
                            latest_sequence: 12,
                            archived_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_project_entitlements")) {
                        return {
                            can_read: 1,
                            can_write: 1,
                            revoked_at: null,
                        };
                    }
                    if (sql.includes("FROM sync_device_cursors")) {
                        return {
                            last_pulled_sequence: 10,
                            last_pushed_sequence: 11,
                            last_applied_sequence: 9,
                            apply_state: "idle",
                        };
                    }
                    throw new Error(`Unexpected orchestrator eligibility query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeReleaseReadinessDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production release smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production release readiness must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production release readiness must not prepare mutation SQL");

            return {
                bind: forbiddenMutation,
                async first() {
                    if (sql.includes("FROM sync_environments")) {
                        return {
                            production_environment_count: 1,
                            write_enabled_count: 0,
                        };
                    }
                    if (sql.includes("FROM sync_rollout_flags")) {
                        return {
                            flag_count: 1,
                            active_kill_switch_count: 0,
                        };
                    }
                    throw new Error(`Unexpected release readiness query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeEnvironmentPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production environment smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production environment preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production environment preflight must not prepare mutation SQL");

            return {
                bind: forbiddenMutation,
                async first() {
                    if (sql.includes("FROM sync_environments")) {
                        return {
                            production_environment_count: 1,
                            write_enabled_count: 0,
                        };
                    }
                    if (sql.includes("FROM sync_rollout_flags")) {
                        return {
                            flag_count: 2,
                            enabled_flag_count: 0,
                            active_kill_switch_count: 0,
                        };
                    }
                    throw new Error(`Unexpected environment preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeBlockedEnvironmentPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production blocked environment smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production blocked environment preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production blocked environment preflight must not prepare mutation SQL");

            return {
                bind: forbiddenMutation,
                async first() {
                    if (sql.includes("FROM sync_environments")) {
                        return {
                            production_environment_count: 1,
                            write_enabled_count: 1,
                        };
                    }
                    if (sql.includes("FROM sync_rollout_flags")) {
                        return {
                            flag_count: 2,
                            enabled_flag_count: 1,
                            active_kill_switch_count: 1,
                        };
                    }
                    throw new Error(`Unexpected blocked environment preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

function makeMissingEnvironmentPreflightDb() {
    const preparedStatements = [];
    const forbiddenMutation = () => {
        throw new Error("Production missing environment smoke DB mock received a mutation call");
    };

    return {
        preparedStatements,
        prepare(sql) {
            preparedStatements.push(sql);
            assert.match(sql, /^\s*SELECT\b/i, "Production missing environment preflight must only prepare SELECT statements");
            assert.doesNotMatch(sql, /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b/i, "Production missing environment preflight must not prepare mutation SQL");

            return {
                bind: forbiddenMutation,
                async first() {
                    if (sql.includes("FROM sync_environments")) {
                        return {
                            production_environment_count: 0,
                            write_enabled_count: 0,
                        };
                    }
                    if (sql.includes("FROM sync_rollout_flags")) {
                        return {
                            flag_count: 0,
                            enabled_flag_count: 0,
                            active_kill_switch_count: 0,
                        };
                    }
                    throw new Error(`Unexpected missing environment preflight query: ${sql}`);
                },
                all: forbiddenMutation,
                run: forbiddenMutation,
                raw: forbiddenMutation,
            };
        },
        batch: forbiddenMutation,
        exec: forbiddenMutation,
        dump: forbiddenMutation,
    };
}

async function readJson(response) {
    return JSON.parse(await response.text());
}

function completeReleaseEvidence() {
    return {
        schemaDeployed: true,
        authVerified: true,
        migrationDrillPassed: true,
        assetDrillPassed: true,
        applierRollbackPassed: true,
        orchestratorDrillPassed: true,
        monitoringAlertsVerified: true,
        supportRunbookVerified: true,
        backupExportVerified: true,
        quotaControlsVerified: true,
        environmentSeparationVerified: true,
        multiDeviceConvergencePassed: true,
        killSwitchTested: true,
    };
}

function makeAsset(index, overrides = {}) {
    return {
        id: `asset-${index}`,
        entityType: "TextFile",
        entityId: `file-${index}`,
        contentHash: `sha256:asset-${index}`,
        byteCount: 1234,
        proposedR2Key: `assets/user-1/project-1/asset-${index}`,
        contentType: "application/octet-stream",
        ...overrides,
    };
}

function migrationInventory() {
    return {
        projectCount: 1,
        folderCount: 3,
        textFileCount: 12,
        versionCount: 20,
        publicationCount: 2,
        relationshipLinkCount: 6,
        styleCount: 18,
        referenceCount: 4,
        commentCount: 5,
        footnoteCount: 7,
        assetCount: 3,
        estimatedAssetBytes: 4096,
    };
}

const healthResponse = await worker.fetch(makeRequest("/health", { method: "GET" }), {});
const healthBody = await readJson(healthResponse);
assert.equal(healthResponse.status, 200, "Production health must be public and available without bindings");
assert.equal(healthResponse.headers.get("Cache-Control"), "no-store", "Production health response must be no-store");
assert.deepEqual(healthBody, {
    ok: true,
    service: "wsp-sync-production",
    version: "2026-07-08-foundation-v1",
    phase: "server-foundation",
    productionDbConfigured: false,
    productionBlobsConfigured: false,
    authConfigured: false,
    writesEnabled: false,
    appMutationEnabled: false,
});

const configuredHealthResponse = await worker.fetch(makeRequest("/health", { method: "GET" }), {
    SYNC_PRODUCTION_TOKEN: productionToken,
    SYNC_PRODUCTION_DB: makeAggregateOnlyDb(),
    SYNC_PRODUCTION_BLOBS: {},
});
const configuredHealthBody = await readJson(configuredHealthResponse);
assert.equal(configuredHealthResponse.status, 200, "Production health must remain public when bindings are configured");
assert.equal(configuredHealthBody.productionDbConfigured, true, "Production health must report configured DB binding");
assert.equal(configuredHealthBody.productionBlobsConfigured, true, "Production health must report configured blob binding");
assert.equal(configuredHealthBody.authConfigured, true, "Production health must report configured auth token");
assert.equal(configuredHealthBody.writesEnabled, false, "Production health must keep writes disabled");
assert.equal(configuredHealthBody.appMutationEnabled, false, "Production health must keep app mutation disabled");

const healthWrongMethodResponse = await worker.fetch(makeRequest("/health", { method: "POST", body: {} }), {});
assert.equal(healthWrongMethodResponse.status, 405, "Production health must reject non-GET methods");
assert.equal(healthWrongMethodResponse.headers.get("Cache-Control"), "no-store", "Production health method rejection must be no-store");

const notFoundResponse = await worker.fetch(makeRequest("/not-a-production-route", { method: "GET" }), {});
assert.equal(notFoundResponse.status, 404, "Production namespace must reject unknown routes before auth");
assert.equal(notFoundResponse.headers.get("Cache-Control"), "no-store", "Production route miss must be no-store");

const protectedRoutes = productionContract.routes.filter((route) => route.public === false);
for (const route of protectedRoutes) {
    const wrongMethodResponse = await worker.fetch(makeRequest(route.route, { method: "GET" }), {
        SYNC_PRODUCTION_TOKEN: productionToken,
    });
    assert.equal(wrongMethodResponse.status, 405, `${route.route} must reject non-POST methods before auth/body work`);
    assert.equal(wrongMethodResponse.headers.get("Cache-Control"), "no-store", `${route.route} method rejection must be no-store`);

    const missingAuthResponse = await worker.fetch(makeRequest(route.route, { body: {} }), {
        SYNC_PRODUCTION_TOKEN: productionToken,
    });
    assert.equal(missingAuthResponse.status, 401, `${route.route} must reject missing auth before DB/body work`);
    assert.equal(missingAuthResponse.headers.get("Cache-Control"), "no-store", `${route.route} missing-auth response must be no-store`);

    const wrongTokenResponse = await worker.fetch(
        makeRequest(route.route, {
            body: {},
            headers: { Authorization: "Bearer incorrect-production-token" },
        }),
        { SYNC_PRODUCTION_TOKEN: productionToken }
    );
    assert.equal(wrongTokenResponse.status, 401, `${route.route} must reject mismatched production auth tokens before DB/body work`);
    assert.equal(wrongTokenResponse.headers.get("Cache-Control"), "no-store", `${route.route} wrong-token response must be no-store`);

    const unconfiguredTokenResponse = await worker.fetch(
        makeRequest(route.route, {
            body: {},
            headers: { Authorization: `Bearer ${productionToken}` },
        }),
        {}
    );
    assert.equal(unconfiguredTokenResponse.status, 401, `${route.route} must reject requests when production auth token is not configured`);
    assert.equal(unconfiguredTokenResponse.headers.get("Cache-Control"), "no-store", `${route.route} unconfigured-token response must be no-store`);

    const unconfiguredDbResponse = await worker.fetch(
        makeRawRequest(route.route, {
            body: "{",
            headers: { Authorization: `Bearer ${productionToken}` },
        }),
        { SYNC_PRODUCTION_TOKEN: productionToken }
    );
    assert.equal(unconfiguredDbResponse.status, 503, `${route.route} must reject requests when production DB is not configured`);
    assert.equal(unconfiguredDbResponse.headers.get("Cache-Control"), "no-store", `${route.route} unconfigured-DB response must be no-store`);

    const invalidJsonResponse = await worker.fetch(
        makeRawRequest(route.route, {
            body: "{",
            headers: { Authorization: `Bearer ${productionToken}` },
        }),
        {
            SYNC_PRODUCTION_TOKEN: productionToken,
            SYNC_PRODUCTION_DB: makeNoQueryDb(),
            SYNC_PRODUCTION_BLOBS: {},
        }
    );
    assert.equal(invalidJsonResponse.status, 400, `${route.route} must reject invalid JSON before route-specific DB work`);
    assert.equal(invalidJsonResponse.headers.get("Cache-Control"), "no-store", `${route.route} invalid-JSON response must be no-store`);
}

const unauthorizedResponse = await worker.fetch(makeRequest("/users/summary", { body: {} }), {
    SYNC_PRODUCTION_TOKEN: productionToken,
});
assert.equal(unauthorizedResponse.status, 401, "Users summary must reject missing auth before doing any work");
assert.equal(unauthorizedResponse.headers.get("Cache-Control"), "no-store", "Unauthorized response must be no-store");

const missingDbResponse = await worker.fetch(
    makeRequest("/users/summary", {
        body: {},
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    { SYNC_PRODUCTION_TOKEN: productionToken }
);
assert.equal(missingDbResponse.status, 503, "Users summary must fail closed when production DB is not configured");
assert.equal(missingDbResponse.headers.get("Cache-Control"), "no-store", "Missing DB response must be no-store");

const assetPreflightDb = makeAssetPreflightDb();
const missingBlobResponse = await worker.fetch(
    makeRequest("/assets/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            assets: [
                {
                    id: "asset-1",
                    entityType: "TextFile",
                    entityId: "file-1",
                    contentHash: "sha256:asset-1",
                    byteCount: 1234,
                    proposedR2Key: "assets/user-1/project-1/asset-1",
                    contentType: "application/octet-stream",
                },
            ],
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: assetPreflightDb,
    }
);
const missingBlobBody = await readJson(missingBlobResponse);
assert.equal(missingBlobResponse.status, 200, "Asset preflight must return readiness blockers rather than attempting transfer without blobs");
assert.equal(missingBlobResponse.headers.get("Cache-Control"), "no-store", "Asset preflight missing-blob response must be no-store");
assert.equal(missingBlobBody.readyToTransferAssets, false, "Asset preflight must not be ready without blob storage");
assert.equal(missingBlobBody.readyToAdvanceCursor, false, "Asset preflight must not advance cursors without verified assets");
assert.equal(missingBlobBody.writesEnabled, false, "Asset preflight must keep writes disabled");
assert.equal(missingBlobBody.appMutationEnabled, false, "Asset preflight must keep app mutation disabled");
assert.deepEqual(missingBlobBody.blockers, ["production_blob_storage_not_configured"]);
assert.equal(missingBlobBody.manifest.assetCount, 1, "Asset preflight must normalize the supplied manifest");
assert.equal(assetPreflightDb.preparedStatements.length, 4, "Asset preflight should only query identity, device, project, and entitlement readiness");

const assetReadyDb = makeAssetPreflightDb();
const assetReadyResponse = await worker.fetch(
    makeRequest("/assets/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            assets: [makeAsset(1)],
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: assetReadyDb,
        SYNC_PRODUCTION_BLOBS: makeNoWriteBlobStorage(),
    }
);
const assetReadyBody = await readJson(assetReadyResponse);
assert.equal(assetReadyResponse.status, 200, "Asset preflight must return readiness without uploading assets");
assert.equal(assetReadyResponse.headers.get("Cache-Control"), "no-store", "Asset preflight ready response must be no-store");
assert.equal(assetReadyBody.readyToTransferAssets, true, "Asset preflight may report transfer readiness when bindings and identity are ready");
assert.equal(assetReadyBody.readyToAdvanceCursor, false, "Asset preflight must not advance cursor before verified uploads");
assert.equal(assetReadyBody.writesEnabled, false, "Asset preflight must keep writes disabled when transfer-ready");
assert.equal(assetReadyBody.appMutationEnabled, false, "Asset preflight must keep app mutation disabled when transfer-ready");
assert.deepEqual(assetReadyBody.blockers, []);
assert.equal(assetReadyBody.manifest.requiresTransfer, true, "Asset preflight must report transfer requirement without performing transfer");
assert.equal(assetReadyDb.preparedStatements.length, 4, "Asset preflight ready path should only query identity, device, project, and entitlement readiness");

const duplicateAssetIdResponse = await worker.fetch(
    makeRequest("/assets/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            assets: [makeAsset(1), makeAsset(1)],
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: makeNoQueryDb(),
        SYNC_PRODUCTION_BLOBS: makeNoWriteBlobStorage(),
    }
);
const duplicateAssetIdBody = await readJson(duplicateAssetIdResponse);
assert.equal(duplicateAssetIdResponse.status, 400, "Asset preflight must reject duplicate asset ids before DB or blob work");
assert.equal(duplicateAssetIdResponse.headers.get("Cache-Control"), "no-store", "Duplicate asset id response must be no-store");
assert.deepEqual(duplicateAssetIdBody, { error: "Asset ids must be unique" });

const duplicateAssetKeyResponse = await worker.fetch(
    makeRequest("/assets/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            assets: [
                makeAsset(1, { proposedR2Key: "assets/shared-key" }),
                makeAsset(2, { proposedR2Key: "assets/shared-key" }),
            ],
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: makeNoQueryDb(),
        SYNC_PRODUCTION_BLOBS: makeNoWriteBlobStorage(),
    }
);
const duplicateAssetKeyBody = await readJson(duplicateAssetKeyResponse);
assert.equal(duplicateAssetKeyResponse.status, 400, "Asset preflight must reject duplicate proposed R2 keys before DB or blob work");
assert.equal(duplicateAssetKeyResponse.headers.get("Cache-Control"), "no-store", "Duplicate asset key response must be no-store");
assert.deepEqual(duplicateAssetKeyBody, { error: "Asset proposedR2Key values must be unique" });

const oversizedAssetManifestResponse = await worker.fetch(
    makeRequest("/assets/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            assets: Array.from(
                { length: productionContract.policy.maxAssetManifestItems + 1 },
                (_, index) => makeAsset(index + 1)
            ),
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: makeNoQueryDb(),
        SYNC_PRODUCTION_BLOBS: {},
    }
);
const oversizedAssetManifestBody = await readJson(oversizedAssetManifestResponse);
assert.equal(oversizedAssetManifestResponse.status, 400, "Asset preflight must reject oversized manifests before DB or blob work");
assert.equal(oversizedAssetManifestResponse.headers.get("Cache-Control"), "no-store", "Oversized asset manifest response must be no-store");
assert.deepEqual(oversizedAssetManifestBody, { error: "assets exceeds 1000" });

const oversizedApplyWindowResponse = await worker.fetch(
    makeRequest("/apply/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            operationWindow: {
                baseSequence: 0,
                startSequence: 1,
                endSequence: productionContract.policy.maxApplyWindowOperations + 1,
                operationCount: productionContract.policy.maxApplyWindowOperations + 1,
                payloadHash: "sha256:operation-window-1",
                hasUnresolvedDependencies: false,
                hasPendingAssets: false,
            },
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: makeNoQueryDb(),
    }
);
const oversizedApplyWindowBody = await readJson(oversizedApplyWindowResponse);
assert.equal(oversizedApplyWindowResponse.status, 400, "Apply preflight must reject oversized operation windows before DB or cursor work");
assert.equal(oversizedApplyWindowResponse.headers.get("Cache-Control"), "no-store", "Oversized apply window response must be no-store");
assert.deepEqual(oversizedApplyWindowBody, { error: "operationWindow.operationCount exceeds 500" });

const applyPreflightDb = makeApplyPreflightDb();
const applierMissingResponse = await worker.fetch(
    makeRequest("/apply/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            operationWindow: {
                baseSequence: 0,
                startSequence: 1,
                endSequence: 1,
                operationCount: 1,
                payloadHash: "sha256:operation-window-1",
                hasUnresolvedDependencies: false,
                hasPendingAssets: false,
            },
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: applyPreflightDb,
    }
);
const applierMissingBody = await readJson(applierMissingResponse);
assert.equal(applierMissingResponse.status, 200, "Apply preflight must return readiness blockers without applying operations");
assert.equal(applierMissingResponse.headers.get("Cache-Control"), "no-store", "Apply preflight applier-missing response must be no-store");
assert.equal(applierMissingBody.readyToApply, false, "Apply preflight must remain disabled without a SwiftData applier");
assert.equal(applierMissingBody.readyToAdvanceCursor, false, "Apply preflight must not advance cursor before app apply commits");
assert.equal(applierMissingBody.writesEnabled, false, "Apply preflight must keep writes disabled");
assert.equal(applierMissingBody.appMutationEnabled, false, "Apply preflight must keep app mutation disabled");
assert.deepEqual(applierMissingBody.blockers, ["production_swiftdata_applier_not_implemented"]);
assert.equal(applierMissingBody.currentCursorSequence, 0, "Apply preflight must report current cursor sequence without advancing it");
assert.equal(applierMissingBody.projectLatestSequence, 1, "Apply preflight must report project latest sequence without mutating it");
assert.equal(applyPreflightDb.preparedStatements.length, 5, "Apply preflight should only query identity, device, project, entitlement, and cursor readiness");

const orchestratorEligibilityDb = makeOrchestratorEligibilityDb();
const orchestratorDisabledResponse = await worker.fetch(
    makeRequest("/orchestrator/eligibility", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            trigger: "manual",
            hasNetwork: true,
            appState: "foreground",
            previousTransportFailure: false,
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: orchestratorEligibilityDb,
    }
);
const orchestratorDisabledBody = await readJson(orchestratorDisabledResponse);
assert.equal(orchestratorDisabledResponse.status, 200, "Orchestrator eligibility must return readiness blockers without scheduling lifecycle work");
assert.equal(orchestratorDisabledResponse.headers.get("Cache-Control"), "no-store", "Orchestrator eligibility response must be no-store");
assert.equal(orchestratorDisabledBody.eligibleToRun, false, "Orchestrator eligibility must remain disabled until lifecycle wiring exists");
assert.equal(orchestratorDisabledBody.eligibleToApply, false, "Orchestrator eligibility must not allow app apply");
assert.equal(orchestratorDisabledBody.eligibleToAdvanceCursor, false, "Orchestrator eligibility must not allow cursor advancement");
assert.equal(orchestratorDisabledBody.writesEnabled, false, "Orchestrator eligibility must keep writes disabled");
assert.equal(orchestratorDisabledBody.appMutationEnabled, false, "Orchestrator eligibility must keep app mutation disabled");
assert.deepEqual(orchestratorDisabledBody.blockers, ["production_orchestrator_not_wired", "production_swiftdata_applier_not_implemented"]);
assert.deepEqual(orchestratorDisabledBody.cursor, {
    lastPulledSequence: 10,
    lastPushedSequence: 11,
    lastAppliedSequence: 9,
    applyState: "idle",
});
assert.equal(orchestratorDisabledBody.latestSequence, 12, "Orchestrator eligibility must report latest sequence without mutating it");
assert.equal(orchestratorEligibilityDb.preparedStatements.length, 5, "Orchestrator eligibility should only query identity, device, project, entitlement, and cursor readiness");

const releaseReadinessDb = makeReleaseReadinessDb();
const releaseDisabledResponse = await worker.fetch(
    makeRequest("/release/readiness", {
        body: { evidence: completeReleaseEvidence() },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: releaseReadinessDb,
    }
);
const releaseDisabledBody = await readJson(releaseDisabledResponse);
assert.equal(releaseDisabledResponse.status, 200, "Release readiness must return blockers without enabling production writes");
assert.equal(releaseDisabledResponse.headers.get("Cache-Control"), "no-store", "Release readiness response must be no-store");
assert.equal(releaseDisabledBody.evidenceComplete, true, "Release readiness must recognize complete supplied evidence");
assert.equal(releaseDisabledBody.readyToRelease, false, "Release readiness must remain disabled without an enable endpoint");
assert.equal(releaseDisabledBody.readyToEnableProductionWrites, false, "Release readiness must not enable production writes");
assert.equal(releaseDisabledBody.writesEnabled, false, "Release readiness must keep writes disabled");
assert.equal(releaseDisabledBody.appMutationEnabled, false, "Release readiness must keep app mutation disabled");
assert.deepEqual(releaseDisabledBody.blockers, ["production_release_enable_endpoint_not_implemented"]);
assert.deepEqual(releaseDisabledBody.environment, {
    productionEnvironmentCount: 1,
    writeEnabledCount: 0,
});
assert.deepEqual(releaseDisabledBody.rollout, {
    flagCount: 1,
    activeKillSwitchCount: 0,
});
assert.equal(releaseReadinessDb.preparedStatements.length, 2, "Release readiness should only query environment and rollout summaries");

const identityCheckDb = makeIdentityCheckDb();
const identityReadOnlyResponse = await worker.fetch(
    makeRequest("/identity/check", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: identityCheckDb,
    }
);
const identityReadOnlyBody = await readJson(identityReadOnlyResponse);
assert.equal(identityReadOnlyResponse.status, 200, "Identity check must return read-only authorization status");
assert.equal(identityReadOnlyResponse.headers.get("Cache-Control"), "no-store", "Identity check response must be no-store");
assert.deepEqual(identityReadOnlyBody, {
    ok: true,
    authorized: true,
    userRegistered: true,
    deviceRegistered: true,
    projectEntitled: true,
    canRead: true,
    canWrite: false,
    writesEnabled: false,
    reasons: [],
    version: "2026-07-08-foundation-v1",
});
assert.equal(identityCheckDb.preparedStatements.length, 3, "Identity check should only query user, device, and entitlement readiness");

const identityEnrollmentDb = makeIdentityEnrollmentPreflightDb();
const identityEnrollmentResponse = await worker.fetch(
    makeRequest("/identity/enrollment/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            consentAcknowledged: true,
            backupExportVerified: true,
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: identityEnrollmentDb,
    }
);
const identityEnrollmentBody = await readJson(identityEnrollmentResponse);
assert.equal(identityEnrollmentResponse.status, 200, "Identity enrollment preflight must return blockers without creating identity records");
assert.equal(identityEnrollmentResponse.headers.get("Cache-Control"), "no-store", "Identity enrollment preflight response must be no-store");
assert.equal(identityEnrollmentBody.readyToEnrollUser, false, "Identity enrollment preflight must not enroll users in the foundation phase");
assert.equal(identityEnrollmentBody.readyToRegisterDevice, false, "Identity enrollment preflight must not register devices in the foundation phase");
assert.equal(identityEnrollmentBody.readyToCreateProjectEntitlements, false, "Identity enrollment preflight must not create entitlements in the foundation phase");
assert.equal(identityEnrollmentBody.userAlreadyRegistered, true, "Identity enrollment preflight may report existing user state");
assert.equal(identityEnrollmentBody.deviceAlreadyRegistered, true, "Identity enrollment preflight may report existing device state");
assert.equal(identityEnrollmentBody.writesEnabled, false, "Identity enrollment preflight must keep writes disabled");
assert.equal(identityEnrollmentBody.appMutationEnabled, false, "Identity enrollment preflight must keep app mutation disabled");
assert.deepEqual(identityEnrollmentBody.blockers, ["production_identity_enrollment_not_implemented"]);
assert.equal(identityEnrollmentBody.nextStep, "implement_disabled_identity_enrollment_writer", "Identity enrollment preflight must point at a disabled future writer");
assert.equal(identityEnrollmentDb.preparedStatements.length, 2, "Identity enrollment preflight should only query user and device readiness");

const identityEnrollmentMissingEvidenceDb = makeIdentityEnrollmentPreflightDb();
const identityEnrollmentMissingEvidenceResponse = await worker.fetch(
    makeRequest("/identity/enrollment/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            consentAcknowledged: false,
            backupExportVerified: false,
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: identityEnrollmentMissingEvidenceDb,
    }
);
const identityEnrollmentMissingEvidenceBody = await readJson(identityEnrollmentMissingEvidenceResponse);
assert.equal(identityEnrollmentMissingEvidenceResponse.status, 200, "Identity enrollment preflight must report missing evidence as blockers without writing");
assert.equal(identityEnrollmentMissingEvidenceResponse.headers.get("Cache-Control"), "no-store", "Identity enrollment missing-evidence response must be no-store");
assert.equal(identityEnrollmentMissingEvidenceBody.readyToEnrollUser, false, "Identity enrollment missing-evidence path must not enroll users");
assert.equal(identityEnrollmentMissingEvidenceBody.readyToRegisterDevice, false, "Identity enrollment missing-evidence path must not register devices");
assert.equal(identityEnrollmentMissingEvidenceBody.writesEnabled, false, "Identity enrollment missing-evidence path must keep writes disabled");
assert.equal(identityEnrollmentMissingEvidenceBody.appMutationEnabled, false, "Identity enrollment missing-evidence path must keep app mutation disabled");
assert.deepEqual(identityEnrollmentMissingEvidenceBody.blockers, [
    "production_identity_enrollment_not_implemented",
    "consent_not_acknowledged",
    "backup_export_not_verified",
]);
assert.equal(identityEnrollmentMissingEvidenceDb.preparedStatements.length, 2, "Identity enrollment missing-evidence path should only query user and device readiness");

const unregisteredIdentityEnrollmentDb = makeUnregisteredIdentityEnrollmentPreflightDb();
const unregisteredIdentityEnrollmentResponse = await worker.fetch(
    makeRequest("/identity/enrollment/preflight", {
        body: {
            userSubjectHash: "new-subject-1",
            deviceId: "new-device-1",
            consentAcknowledged: true,
            backupExportVerified: true,
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: unregisteredIdentityEnrollmentDb,
    }
);
const unregisteredIdentityEnrollmentBody = await readJson(unregisteredIdentityEnrollmentResponse);
assert.equal(unregisteredIdentityEnrollmentResponse.status, 200, "Identity enrollment preflight must not auto-create unregistered users");
assert.equal(unregisteredIdentityEnrollmentResponse.headers.get("Cache-Control"), "no-store", "Identity enrollment unregistered response must be no-store");
assert.equal(unregisteredIdentityEnrollmentBody.readyToEnrollUser, false, "Identity enrollment unregistered path must keep enrollment disabled");
assert.equal(unregisteredIdentityEnrollmentBody.readyToRegisterDevice, false, "Identity enrollment unregistered path must keep device registration disabled");
assert.equal(unregisteredIdentityEnrollmentBody.readyToCreateProjectEntitlements, false, "Identity enrollment unregistered path must keep entitlement creation disabled");
assert.equal(unregisteredIdentityEnrollmentBody.userAlreadyRegistered, false, "Identity enrollment unregistered path must report missing user state");
assert.equal(unregisteredIdentityEnrollmentBody.deviceAlreadyRegistered, false, "Identity enrollment unregistered path must report missing device state");
assert.equal(unregisteredIdentityEnrollmentBody.writesEnabled, false, "Identity enrollment unregistered path must keep writes disabled");
assert.equal(unregisteredIdentityEnrollmentBody.appMutationEnabled, false, "Identity enrollment unregistered path must keep app mutation disabled");
assert.deepEqual(unregisteredIdentityEnrollmentBody.blockers, ["production_identity_enrollment_not_implemented"]);
assert.equal(unregisteredIdentityEnrollmentDb.preparedStatements.length, 1, "Identity enrollment unregistered path should only query user readiness");

const revokedIdentityEnrollmentDb = makeRevokedIdentityEnrollmentPreflightDb();
const revokedIdentityEnrollmentResponse = await worker.fetch(
    makeRequest("/identity/enrollment/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            consentAcknowledged: true,
            backupExportVerified: true,
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: revokedIdentityEnrollmentDb,
    }
);
const revokedIdentityEnrollmentBody = await readJson(revokedIdentityEnrollmentResponse);
assert.equal(revokedIdentityEnrollmentResponse.status, 200, "Identity enrollment preflight must report revoked identity blockers without writing");
assert.equal(revokedIdentityEnrollmentResponse.headers.get("Cache-Control"), "no-store", "Identity enrollment revoked response must be no-store");
assert.equal(revokedIdentityEnrollmentBody.readyToEnrollUser, false, "Identity enrollment revoked path must keep enrollment disabled");
assert.equal(revokedIdentityEnrollmentBody.readyToRegisterDevice, false, "Identity enrollment revoked path must keep device registration disabled");
assert.equal(revokedIdentityEnrollmentBody.readyToCreateProjectEntitlements, false, "Identity enrollment revoked path must keep entitlement creation disabled");
assert.equal(revokedIdentityEnrollmentBody.writesEnabled, false, "Identity enrollment revoked path must keep writes disabled");
assert.equal(revokedIdentityEnrollmentBody.appMutationEnabled, false, "Identity enrollment revoked path must keep app mutation disabled");
assert.deepEqual(revokedIdentityEnrollmentBody.blockers, [
    "production_identity_enrollment_not_implemented",
    "user_revoked_or_deleted",
    "device_revoked",
]);
assert.equal(revokedIdentityEnrollmentDb.preparedStatements.length, 2, "Identity enrollment revoked path should only query user and device readiness");

const entitlementsPreflightDb = makeEntitlementsPreflightDb();
const entitlementsPreflightResponse = await worker.fetch(
    makeRequest("/entitlements/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            requestedRole: "owner",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: entitlementsPreflightDb,
    }
);
const entitlementsPreflightBody = await readJson(entitlementsPreflightResponse);
assert.equal(entitlementsPreflightResponse.status, 200, "Entitlements preflight must return blockers without granting access");
assert.equal(entitlementsPreflightResponse.headers.get("Cache-Control"), "no-store", "Entitlements preflight response must be no-store");
assert.equal(entitlementsPreflightBody.readyToGrantProjectEntitlement, false, "Entitlements preflight must not grant project access");
assert.equal(entitlementsPreflightBody.readyToUpdateProjectEntitlement, false, "Entitlements preflight must not update project access");
assert.equal(entitlementsPreflightBody.userRegistered, true, "Entitlements preflight must report existing user state");
assert.equal(entitlementsPreflightBody.deviceRegistered, true, "Entitlements preflight must report existing device state");
assert.equal(entitlementsPreflightBody.projectRegistered, true, "Entitlements preflight must report existing project state");
assert.equal(entitlementsPreflightBody.entitlementExists, true, "Entitlements preflight must report existing entitlement state");
assert.equal(entitlementsPreflightBody.currentRole, "owner", "Entitlements preflight may report current role without changing it");
assert.equal(entitlementsPreflightBody.currentCanRead, true, "Entitlements preflight may report current read access");
assert.equal(entitlementsPreflightBody.currentCanWrite, false, "Entitlements preflight must not expose write enablement in the foundation phase");
assert.equal(entitlementsPreflightBody.writesEnabled, false, "Entitlements preflight must keep writes disabled");
assert.equal(entitlementsPreflightBody.appMutationEnabled, false, "Entitlements preflight must keep app mutation disabled");
assert.deepEqual(entitlementsPreflightBody.blockers, ["production_project_entitlement_writer_not_implemented"]);
assert.equal(entitlementsPreflightBody.nextStep, "implement_disabled_project_entitlement_writer", "Entitlements preflight must point at a disabled future writer");
assert.equal(entitlementsPreflightDb.preparedStatements.length, 4, "Entitlements preflight should only query identity, device, project, and entitlement readiness");

const missingProjectEntitlementsDb = makeMissingProjectEntitlementsPreflightDb();
const missingProjectEntitlementsResponse = await worker.fetch(
    makeRequest("/entitlements/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "missing-project-1",
            requestedRole: "owner",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: missingProjectEntitlementsDb,
    }
);
const missingProjectEntitlementsBody = await readJson(missingProjectEntitlementsResponse);
assert.equal(missingProjectEntitlementsResponse.status, 200, "Entitlements preflight must report missing projects without creating them");
assert.equal(missingProjectEntitlementsResponse.headers.get("Cache-Control"), "no-store", "Entitlements missing-project response must be no-store");
assert.equal(missingProjectEntitlementsBody.readyToGrantProjectEntitlement, false, "Entitlements missing-project path must not grant access");
assert.equal(missingProjectEntitlementsBody.readyToUpdateProjectEntitlement, false, "Entitlements missing-project path must not update access");
assert.equal(missingProjectEntitlementsBody.projectRegistered, false, "Entitlements missing-project path must report missing project state");
assert.equal(missingProjectEntitlementsBody.entitlementExists, false, "Entitlements missing-project path must report missing entitlement state");
assert.deepEqual(missingProjectEntitlementsBody.blockers, [
    "production_project_entitlement_writer_not_implemented",
    "project_not_registered",
]);
assert.equal(missingProjectEntitlementsDb.preparedStatements.length, 4, "Entitlements missing-project path should only query identity, device, project, and entitlement readiness");

const unregisteredEntitlementsDb = makeUnregisteredEntitlementsPreflightDb();
const unregisteredEntitlementsResponse = await worker.fetch(
    makeRequest("/entitlements/preflight", {
        body: {
            userSubjectHash: "missing-subject-1",
            deviceId: "missing-device-1",
            projectId: "project-1",
            requestedRole: "owner",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: unregisteredEntitlementsDb,
    }
);
const unregisteredEntitlementsBody = await readJson(unregisteredEntitlementsResponse);
assert.equal(unregisteredEntitlementsResponse.status, 200, "Entitlements preflight must not auto-create unregistered users");
assert.equal(unregisteredEntitlementsResponse.headers.get("Cache-Control"), "no-store", "Entitlements unregistered response must be no-store");
assert.equal(unregisteredEntitlementsBody.readyToGrantProjectEntitlement, false, "Entitlements unregistered path must not grant access");
assert.equal(unregisteredEntitlementsBody.readyToUpdateProjectEntitlement, false, "Entitlements unregistered path must not update access");
assert.equal(unregisteredEntitlementsBody.userRegistered, false, "Entitlements unregistered path must report missing user state");
assert.equal(unregisteredEntitlementsBody.deviceRegistered, false, "Entitlements unregistered path must report missing device state");
assert.equal(unregisteredEntitlementsBody.projectRegistered, false, "Entitlements unregistered path must report missing project state");
assert.equal(unregisteredEntitlementsBody.entitlementExists, false, "Entitlements unregistered path must report missing entitlement state");
assert.equal(unregisteredEntitlementsBody.writesEnabled, false, "Entitlements unregistered path must keep writes disabled");
assert.equal(unregisteredEntitlementsBody.appMutationEnabled, false, "Entitlements unregistered path must keep app mutation disabled");
assert.deepEqual(unregisteredEntitlementsBody.blockers, [
    "production_project_entitlement_writer_not_implemented",
    "user_not_registered",
    "device_not_registered",
    "project_not_registered",
]);
assert.equal(unregisteredEntitlementsDb.preparedStatements.length, 1, "Entitlements unregistered path should only query user readiness");

const consentMissingEntitlementsDb = makeConsentMissingEntitlementsPreflightDb();
const consentMissingEntitlementsResponse = await worker.fetch(
    makeRequest("/entitlements/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            requestedRole: "owner",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: consentMissingEntitlementsDb,
    }
);
const consentMissingEntitlementsBody = await readJson(consentMissingEntitlementsResponse);
assert.equal(consentMissingEntitlementsResponse.status, 200, "Entitlements preflight must report missing consent without writing");
assert.equal(consentMissingEntitlementsResponse.headers.get("Cache-Control"), "no-store", "Entitlements missing-consent response must be no-store");
assert.equal(consentMissingEntitlementsBody.readyToGrantProjectEntitlement, false, "Entitlements missing-consent path must not grant access");
assert.equal(consentMissingEntitlementsBody.readyToUpdateProjectEntitlement, false, "Entitlements missing-consent path must not update access");
assert.equal(consentMissingEntitlementsBody.userRegistered, true, "Entitlements missing-consent path must report existing user state");
assert.equal(consentMissingEntitlementsBody.writesEnabled, false, "Entitlements missing-consent path must keep writes disabled");
assert.equal(consentMissingEntitlementsBody.appMutationEnabled, false, "Entitlements missing-consent path must keep app mutation disabled");
assert.deepEqual(consentMissingEntitlementsBody.blockers, [
    "production_project_entitlement_writer_not_implemented",
    "consent_not_granted",
]);
assert.equal(consentMissingEntitlementsDb.preparedStatements.length, 4, "Entitlements missing-consent path should only query identity, device, project, and entitlement readiness");

const revokedEntitlementsDb = makeRevokedEntitlementsPreflightDb();
const revokedEntitlementsResponse = await worker.fetch(
    makeRequest("/entitlements/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            requestedRole: "owner",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: revokedEntitlementsDb,
    }
);
const revokedEntitlementsBody = await readJson(revokedEntitlementsResponse);
assert.equal(revokedEntitlementsResponse.status, 200, "Entitlements preflight must report revoked entitlements without updating them");
assert.equal(revokedEntitlementsResponse.headers.get("Cache-Control"), "no-store", "Entitlements revoked response must be no-store");
assert.equal(revokedEntitlementsBody.readyToGrantProjectEntitlement, false, "Entitlements revoked path must not grant access");
assert.equal(revokedEntitlementsBody.readyToUpdateProjectEntitlement, false, "Entitlements revoked path must not update access");
assert.equal(revokedEntitlementsBody.entitlementExists, true, "Entitlements revoked path must report existing entitlement state");
assert.equal(revokedEntitlementsBody.currentCanWrite, false, "Entitlements revoked path must keep write access disabled");
assert.deepEqual(revokedEntitlementsBody.blockers, [
    "production_project_entitlement_writer_not_implemented",
    "project_entitlement_revoked",
]);
assert.equal(revokedEntitlementsDb.preparedStatements.length, 4, "Entitlements revoked path should only query identity, device, project, and entitlement readiness");

const environmentPreflightDb = makeEnvironmentPreflightDb();
const environmentPreflightResponse = await worker.fetch(
    makeRequest("/environment/preflight", {
        body: {},
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: environmentPreflightDb,
    }
);
const environmentPreflightBody = await readJson(environmentPreflightResponse);
assert.equal(environmentPreflightResponse.status, 200, "Environment preflight must return rollout state without enabling writes");
assert.equal(environmentPreflightResponse.headers.get("Cache-Control"), "no-store", "Environment preflight response must be no-store");
assert.equal(environmentPreflightBody.readyToEnableProductionWrites, false, "Environment preflight must not enable production writes");
assert.equal(environmentPreflightBody.readyToRunProductionMigration, false, "Environment preflight must not enable production migration");
assert.equal(environmentPreflightBody.readyToRunProductionApply, false, "Environment preflight must not enable production apply");
assert.equal(environmentPreflightBody.writesEnabled, false, "Environment preflight must keep writes disabled");
assert.equal(environmentPreflightBody.appMutationEnabled, false, "Environment preflight must keep app mutation disabled");
assert.deepEqual(environmentPreflightBody.blockers, ["production_environment_writes_not_enabled"]);
assert.deepEqual(environmentPreflightBody.environment, {
    productionEnvironmentCount: 1,
    writeEnabledCount: 0,
});
assert.deepEqual(environmentPreflightBody.rollout, {
    flagCount: 2,
    enabledFlagCount: 0,
    activeKillSwitchCount: 0,
});
assert.equal(environmentPreflightBody.nextStep, "keep_production_writes_disabled_until_release_gate", "Environment preflight must point at release-gated enablement");
assert.equal(environmentPreflightDb.preparedStatements.length, 2, "Environment preflight should only query environment and rollout summaries");

const blockedEnvironmentPreflightDb = makeBlockedEnvironmentPreflightDb();
const blockedEnvironmentPreflightResponse = await worker.fetch(
    makeRequest("/environment/preflight", {
        body: {},
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: blockedEnvironmentPreflightDb,
    }
);
const blockedEnvironmentPreflightBody = await readJson(blockedEnvironmentPreflightResponse);
assert.equal(blockedEnvironmentPreflightResponse.status, 200, "Environment preflight must report blocked rollout state without mutating it");
assert.equal(blockedEnvironmentPreflightResponse.headers.get("Cache-Control"), "no-store", "Blocked environment preflight response must be no-store");
assert.equal(blockedEnvironmentPreflightBody.readyToEnableProductionWrites, false, "Blocked environment preflight must not enable writes");
assert.equal(blockedEnvironmentPreflightBody.readyToRunProductionMigration, false, "Blocked environment preflight must not enable migration");
assert.equal(blockedEnvironmentPreflightBody.readyToRunProductionApply, false, "Blocked environment preflight must not enable apply");
assert.equal(blockedEnvironmentPreflightBody.writesEnabled, false, "Blocked environment preflight must keep writes disabled");
assert.equal(blockedEnvironmentPreflightBody.appMutationEnabled, false, "Blocked environment preflight must keep app mutation disabled");
assert.deepEqual(blockedEnvironmentPreflightBody.blockers, [
    "production_environment_writes_not_enabled",
    "production_writes_already_enabled",
    "rollout_kill_switch_active",
]);
assert.deepEqual(blockedEnvironmentPreflightBody.environment, {
    productionEnvironmentCount: 1,
    writeEnabledCount: 1,
});
assert.deepEqual(blockedEnvironmentPreflightBody.rollout, {
    flagCount: 2,
    enabledFlagCount: 1,
    activeKillSwitchCount: 1,
});
assert.equal(blockedEnvironmentPreflightDb.preparedStatements.length, 2, "Blocked environment preflight should only query environment and rollout summaries");

const missingEnvironmentPreflightDb = makeMissingEnvironmentPreflightDb();
const missingEnvironmentPreflightResponse = await worker.fetch(
    makeRequest("/environment/preflight", {
        body: {},
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: missingEnvironmentPreflightDb,
    }
);
const missingEnvironmentPreflightBody = await readJson(missingEnvironmentPreflightResponse);
assert.equal(missingEnvironmentPreflightResponse.status, 200, "Environment preflight must report missing environment state without writing");
assert.equal(missingEnvironmentPreflightResponse.headers.get("Cache-Control"), "no-store", "Missing environment preflight response must be no-store");
assert.equal(missingEnvironmentPreflightBody.readyToEnableProductionWrites, false, "Missing environment preflight must not enable writes");
assert.equal(missingEnvironmentPreflightBody.readyToRunProductionMigration, false, "Missing environment preflight must not enable migration");
assert.equal(missingEnvironmentPreflightBody.readyToRunProductionApply, false, "Missing environment preflight must not enable apply");
assert.equal(missingEnvironmentPreflightBody.writesEnabled, false, "Missing environment preflight must keep writes disabled");
assert.equal(missingEnvironmentPreflightBody.appMutationEnabled, false, "Missing environment preflight must keep app mutation disabled");
assert.deepEqual(missingEnvironmentPreflightBody.blockers, [
    "production_environment_writes_not_enabled",
    "production_environment_missing",
    "rollout_flags_missing",
]);
assert.deepEqual(missingEnvironmentPreflightBody.environment, {
    productionEnvironmentCount: 0,
    writeEnabledCount: 0,
});
assert.deepEqual(missingEnvironmentPreflightBody.rollout, {
    flagCount: 0,
    enabledFlagCount: 0,
    activeKillSwitchCount: 0,
});
assert.equal(missingEnvironmentPreflightDb.preparedStatements.length, 2, "Missing environment preflight should only query environment and rollout summaries");

const migrationPreflightDb = makeMigrationPreflightDb();
const migrationPlanOnlyResponse = await worker.fetch(
    makeRequest("/migration/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            inventory: migrationInventory(),
            backupExportVerified: true,
            consentAcknowledged: true,
            sourceSystem: "cloudkit",
            cloudKitState: "quiescent",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: migrationPreflightDb,
    }
);
const migrationPlanOnlyBody = await readJson(migrationPlanOnlyResponse);
assert.equal(migrationPlanOnlyResponse.status, 200, "Migration preflight must return planning status without creating migration runs");
assert.equal(migrationPlanOnlyResponse.headers.get("Cache-Control"), "no-store", "Migration preflight response must be no-store");
assert.equal(migrationPlanOnlyBody.readyToPlanMigration, true, "Migration preflight may report planning readiness for clean evidence");
assert.equal(migrationPlanOnlyBody.readyToApplyMigration, false, "Migration preflight must not allow apply in the foundation phase");
assert.equal(migrationPlanOnlyBody.writesEnabled, false, "Migration preflight must keep writes disabled");
assert.equal(migrationPlanOnlyBody.appMutationEnabled, false, "Migration preflight must keep app mutation disabled");
assert.deepEqual(migrationPlanOnlyBody.blockers, []);
assert.equal(migrationPlanOnlyBody.nextStep, "create_disabled_migration_run", "Migration preflight must only point at a disabled future run");
assert.equal(migrationPlanOnlyBody.inventory.totalRecords, 78, "Migration preflight must normalize total record count");
assert.equal(migrationPlanOnlyBody.estimatedOperationBatches, 1, "Migration preflight must estimate operation batches without writing");
assert.equal(migrationPlanOnlyBody.estimatedAssetBatches, 1, "Migration preflight must estimate asset batches without uploading");
assert.equal(migrationPreflightDb.preparedStatements.length, 4, "Migration preflight should only query identity, device, project, and entitlement readiness");

const migrationBlockedEvidenceDb = makeMigrationPreflightDb();
const migrationBlockedEvidenceResponse = await worker.fetch(
    makeRequest("/migration/preflight", {
        body: {
            userSubjectHash: "subject-1",
            deviceId: "device-1",
            projectId: "project-1",
            inventory: migrationInventory(),
            backupExportVerified: false,
            consentAcknowledged: false,
            sourceSystem: "local-only",
            cloudKitState: "importing",
        },
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: migrationBlockedEvidenceDb,
    }
);
const migrationBlockedEvidenceBody = await readJson(migrationBlockedEvidenceResponse);
assert.equal(migrationBlockedEvidenceResponse.status, 200, "Migration preflight must report bad evidence as blockers without creating migration runs");
assert.equal(migrationBlockedEvidenceResponse.headers.get("Cache-Control"), "no-store", "Migration blocked-evidence response must be no-store");
assert.equal(migrationBlockedEvidenceBody.readyToPlanMigration, false, "Migration preflight must not plan migration with bad evidence");
assert.equal(migrationBlockedEvidenceBody.readyToApplyMigration, false, "Migration blocked-evidence path must not allow apply");
assert.equal(migrationBlockedEvidenceBody.writesEnabled, false, "Migration blocked-evidence path must keep writes disabled");
assert.equal(migrationBlockedEvidenceBody.appMutationEnabled, false, "Migration blocked-evidence path must keep app mutation disabled");
assert.deepEqual(migrationBlockedEvidenceBody.blockers, [
    "request_consent_not_acknowledged",
    "backup_export_not_verified",
    "source_system_not_cloudkit",
    "cloudkit_state_not_ready",
]);
assert.equal(migrationBlockedEvidenceBody.nextStep, "resolve_preflight_blockers", "Migration blocked-evidence path must point at blocker resolution");
assert.equal(migrationBlockedEvidenceDb.preparedStatements.length, 4, "Migration blocked-evidence path should only query identity, device, project, and entitlement readiness");

const db = makeAggregateOnlyDb();
const successResponse = await worker.fetch(
    makeRequest("/users/summary", {
        body: {},
        headers: { Authorization: `Bearer ${productionToken}` },
    }),
    {
        SYNC_PRODUCTION_TOKEN: productionToken,
        SYNC_PRODUCTION_DB: db,
    }
);
const successBody = await readJson(successResponse);

assert.equal(successResponse.status, 200, "Users summary must return success for authorized aggregate mock DB");
assert.equal(successResponse.headers.get("Cache-Control"), "no-store", "Users summary success response must be no-store");
assert.deepEqual(successBody, {
    ok: true,
    totalUsers: 7,
    activeUsers: 5,
    consentGrantedUsers: 4,
    revokedOrDeletedUsers: 1,
    totalDevices: 9,
    activeDevices: 6,
    revokedDevices: 2,
    writesEnabled: false,
    appMutationEnabled: false,
    version: "2026-07-08-foundation-v1",
});
assert.equal(db.preparedStatements.length, 2, "Users summary must only issue user and device aggregate queries");
assert(db.preparedStatements.some((sql) => sql.includes("FROM sync_users")), "Users summary must read sync_users aggregate counts");
assert(db.preparedStatements.some((sql) => sql.includes("FROM sync_devices")), "Users summary must read sync_devices aggregate counts");

console.log("sync production foundation smoke ok");