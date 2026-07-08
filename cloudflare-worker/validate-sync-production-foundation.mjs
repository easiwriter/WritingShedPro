import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const workerSource = readFileSync(new URL("./src/index.js", import.meta.url), "utf8");
const productionSchema = readFileSync(new URL("./sql/sync_production_schema.sql", import.meta.url), "utf8");
const productionSchemaSmoke = readFileSync(new URL("./smoke-sync-production-schema.mjs", import.meta.url), "utf8");
const packageJSON = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8"));
const productionContract = JSON.parse(readFileSync(new URL("./sync-production-foundation-contract.json", import.meta.url), "utf8"));
const readme = readFileSync(new URL("./README.md", import.meta.url), "utf8");
const wranglerToml = readFileSync(new URL("./wrangler.toml", import.meta.url), "utf8");
const productionHandlerStart = workerSource.indexOf("async function handleSyncProduction(");
const productionHandlerEnd = workerSource.indexOf("async function handleAdminMessages(");
const scratchHandlerStart = workerSource.indexOf("async function handleSyncPOC(");
const scratchHandlerEnd = productionHandlerStart;

assert(productionHandlerStart >= 0, "Worker is missing handleSyncProduction");
assert(productionHandlerEnd > productionHandlerStart, "Worker production section boundary was not found");
assert(scratchHandlerStart >= 0, "Worker is missing handleSyncPOC");
assert(scratchHandlerEnd > scratchHandlerStart, "Worker scratch POC section boundary was not found");

const productionSection = workerSource.slice(productionHandlerStart, productionHandlerEnd);
const scratchSection = workerSource.slice(scratchHandlerStart, scratchHandlerEnd);
const schemaContract = productionContract.schema;

assert(productionContract.namespace === "/api/sync/production/v1", "Production contract manifest must define the production namespace");
assert(productionContract.phase === "server-foundation", "Production contract manifest must define the server-foundation phase");
assert(productionContract.policy?.readOnly === true, "Production contract manifest must declare read-only foundation policy");
assert(productionContract.policy?.d1WritesAllowed === false, "Production contract manifest must forbid D1 writes");
assert(productionContract.policy?.r2WritesAllowed === false, "Production contract manifest must forbid R2 writes");
assert(productionContract.policy?.swiftDataMutationAllowed === false, "Production contract manifest must forbid SwiftData mutation");
assert(productionContract.policy?.cursorAdvanceAllowed === false, "Production contract manifest must forbid cursor advancement");
assert(productionContract.policy?.rolloutEnableAllowed === false, "Production contract manifest must forbid rollout enablement");
assert(productionContract.policy?.cacheControl === "no-store", "Production contract manifest must require no-store cache control");
assert(productionContract.policy?.maxAssetManifestItems === 1000, "Production contract manifest must define max asset manifest items");
assert(productionContract.policy?.maxApplyWindowOperations === 500, "Production contract manifest must define max apply window operations");
assert(Array.isArray(schemaContract?.requiredTables), "Production contract manifest must define schema.requiredTables");
assert(Array.isArray(schemaContract?.safeDefaults), "Production contract manifest must define schema.safeDefaults");
assert(Array.isArray(schemaContract?.requiredForeignKeys), "Production contract manifest must define schema.requiredForeignKeys");
assert(Array.isArray(schemaContract?.forbiddenClauses), "Production contract manifest must define schema.forbiddenClauses");
assert(Array.isArray(schemaContract?.requiredNullableColumns), "Production contract manifest must define schema.requiredNullableColumns");
assert(Array.isArray(schemaContract?.smokeNullableChecks), "Production contract manifest must define schema.smokeNullableChecks");
assert(Array.isArray(schemaContract?.smokeSequenceScopeChecks), "Production contract manifest must define schema.smokeSequenceScopeChecks");
assert(Array.isArray(schemaContract?.uniqueConstraints), "Production contract manifest must define schema.uniqueConstraints");
assert(Array.isArray(schemaContract?.smokeDuplicateRejections), "Production contract manifest must define schema.smokeDuplicateRejections");
assert(Array.isArray(schemaContract?.requiredIndexes), "Production contract manifest must define schema.requiredIndexes");
assert(readme.includes("The production foundation contract is read-only"), "README must document the read-only production foundation policy");
assert(readme.includes("D1 writes"), "README must document that production foundation forbids D1 writes");
assert(readme.includes("R2 writes/uploads"), "README must document that production foundation forbids R2 writes/uploads");
assert(readme.includes("SwiftData mutation"), "README must document that production foundation forbids SwiftData mutation");
assert(readme.includes("cursor advancement"), "README must document that production foundation forbids cursor advancement");
assert(readme.includes("rollout enablement"), "README must document that production foundation forbids rollout enablement");
assert(readme.includes("Cache-Control: no-store"), "README must document no-store cache control");
assert(readme.includes("Asset preflight accepts at most 1000 manifest items"), "README must document asset manifest item limit");
assert(readme.includes("Apply preflight accepts at most 500 operations per window"), "README must document apply window operation limit");
assert(Array.isArray(productionContract.routes), "Production contract manifest must define routes array");

const productionNamespace = productionContract.namespace;
const routeContracts = productionContract.routes;
const productionRoutes = routeContracts.map((contract) => contract.route);
const allowedMethods = new Set(["GET", "POST"]);
const seenRoutes = new Set();
const productionRouteLiterals = [...productionSection.matchAll(/"(\/[a-z][^"]*)"/g)]
    .map((match) => match[1])
    .filter((route) => route !== productionNamespace);

assert(productionSection.includes(`const basePath = "${productionNamespace}"`), "Worker production handler must use the manifest namespace");
assert(workerSource.includes("const MAX_SYNC_PRODUCTION_ASSET_MANIFEST_ITEMS = 1000"), "Worker must define production asset manifest item limit");
assert(productionSection.includes("MAX_SYNC_PRODUCTION_ASSET_MANIFEST_ITEMS"), "Production asset preflight must enforce asset manifest item limit");
assert(workerSource.includes("const MAX_SYNC_PRODUCTION_APPLY_WINDOW_OPERATIONS = 500"), "Worker must define production apply window operation limit");
assert(productionSection.includes("MAX_SYNC_PRODUCTION_APPLY_WINDOW_OPERATIONS"), "Production apply preflight must enforce operation window limit");

for (const contract of routeContracts) {
    assert(typeof contract.route === "string" && contract.route.startsWith("/"), "Each production route contract must define a route path");
    assert(!seenRoutes.has(contract.route), `Production contract has duplicate route ${contract.route}`);
    seenRoutes.add(contract.route);
    assert(allowedMethods.has(contract.method), `Production route ${contract.route} has unsupported method ${contract.method}`);
    assert(typeof contract.public === "boolean", `Production route ${contract.route} must define public`);
    assert(typeof contract.requiresAuth === "boolean", `Production route ${contract.route} must define requiresAuth`);
    assert(typeof contract.requiresProductionDb === "boolean", `Production route ${contract.route} must define requiresProductionDb`);
    assert(typeof contract.requiresProductionBlobs === "boolean", `Production route ${contract.route} must define requiresProductionBlobs`);
    assert(contract.aggregateOnly === undefined || typeof contract.aggregateOnly === "boolean", `Production route ${contract.route} aggregateOnly must be boolean when present`);
    if (contract.aggregateOnly) {
        assert(typeof contract.handler === "string" && contract.handler.length > 0, `Aggregate route ${contract.route} must define handler`);
        assert(Array.isArray(contract.allowedReadTables) && contract.allowedReadTables.length > 0, `Aggregate route ${contract.route} must define allowedReadTables`);
        assert(Array.isArray(contract.forbiddenDetailFields), `Aggregate route ${contract.route} must define forbiddenDetailFields`);
    }
    assert(Array.isArray(contract.requiredSource) && contract.requiredSource.length > 0, `Production route ${contract.route} must define requiredSource checks`);
    assert(Array.isArray(contract.requiredDocs) && contract.requiredDocs.length > 0, `Production route ${contract.route} must define requiredDocs checks`);
    assert(contract.requiredSource.every((text) => typeof text === "string" && text.length > 0), `Production route ${contract.route} has an empty requiredSource check`);
    assert(contract.requiredDocs.every((text) => typeof text === "string" && text.length > 0), `Production route ${contract.route} has an empty requiredDocs check`);
}

for (const route of productionRoutes) {
    assert(workerSource.includes(route), `Worker is missing production route ${route}`);
    assert(productionSection.includes(route), `Production handler does not route ${route}`);
}

for (const route of productionRouteLiterals) {
    assert(productionRoutes.includes(route), `Production handler route ${route} is missing from the contract manifest`);
}

for (const contract of routeContracts) {
    if (contract.method === "GET") {
        assert(
            productionSection.includes(`suffix === "${contract.route}"`) && productionSection.includes('request.method !== "GET"'),
            `Production route ${contract.route} must be guarded as GET in the handler`
        );
    } else if (contract.method === "POST") {
        assert(
            productionSection.includes(`"${contract.route}"`) && productionSection.includes('request.method !== "POST"'),
            `Production route ${contract.route} must be guarded as POST in the handler`
        );
    }
}

for (const contract of routeContracts) {
    if (contract.public) {
        assert(contract.route === "/health", `Only production health may be public, but ${contract.route} is public`);
        assert(contract.requiresAuth === false, `Public production route ${contract.route} must not require auth`);
        assert(readme.includes("Only production health is public"), `Production route ${contract.route} is missing README public-route contract`);
    } else {
        assert(contract.requiresAuth === true, `Non-public production route ${contract.route} must require auth`);
    }
    if (contract.requiresAuth) {
        assert(productionSection.includes("isAuthorizedSyncProductionRequest"), `Production route ${contract.route} must be behind production auth`);
        assert(readme.includes("All production foundation POST routes require `Authorization: Bearer <SYNC_PRODUCTION_TOKEN>`"), `Production route ${contract.route} is missing README auth contract`);
    }
    if (contract.requiresProductionDb) {
        assert(productionSection.includes("!env.SYNC_PRODUCTION_DB"), `Production route ${contract.route} must require production DB configuration`);
        assert(readme.includes("`SYNC_PRODUCTION_DB` to be configured"), `Production route ${contract.route} is missing README production DB contract`);
    }
    if (contract.requiresProductionBlobs) {
        assert(productionSection.includes("!env.SYNC_PRODUCTION_BLOBS"), `Production route ${contract.route} must require production blob storage configuration`);
        assert(readme.includes("`SYNC_PRODUCTION_BLOBS` to be configured"), `Production route ${contract.route} is missing README production blob contract`);
    }
    if (contract.aggregateOnly) {
        const handlerStart = productionSection.indexOf(`async function ${contract.handler}(`);
        const nextHandlerStart = productionSection.indexOf("\nasync function ", handlerStart + 1);
        assert(handlerStart >= 0 && nextHandlerStart > handlerStart, `Aggregate route ${contract.route} handler boundary was not found`);
        const handlerSection = productionSection.slice(handlerStart, nextHandlerStart);
        assert(handlerSection.includes("COUNT(*)"), `Aggregate route ${contract.route} must use aggregate counts`);

        const readTables = [...handlerSection.matchAll(/FROM\s+(sync_[a-z_]+)/g)].map((match) => match[1]);
        for (const table of contract.allowedReadTables) {
            assert(readTables.includes(table), `Aggregate route ${contract.route} must read allowed table ${table}`);
        }
        for (const table of readTables) {
            assert(contract.allowedReadTables.includes(table), `Aggregate route ${contract.route} must not read ${table}`);
        }
        for (const forbiddenField of contract.forbiddenDetailFields) {
            assert(!handlerSection.includes(forbiddenField), `Aggregate route ${contract.route} must not read detail field ${forbiddenField}`);
        }
    }
    assert(
        readme.includes(`${contract.method} ${productionNamespace}${contract.route}`),
        `Production route ${contract.route} is missing README method/path documentation`
    );
    for (const sourceText of contract.requiredSource) {
        assert(
            productionSection.includes(sourceText),
            `Production route ${contract.route} is missing source contract: ${sourceText}`
        );
    }
    for (const docText of contract.requiredDocs) {
        assert(
            readme.includes(docText),
            `Production route ${contract.route} is missing README contract: ${docText}`
        );
    }
}

const disabledContracts = [
    "writesEnabled: false",
    "appMutationEnabled: false",
    "readyToApplyMigration: false",
    "readyToAdvanceCursor: false",
    "readyToApply: false",
    "eligibleToRun: false",
    "readyToRelease: false",
    "readyToEnableProductionWrites: false",
];

for (const contract of disabledContracts) {
    assert(productionSection.includes(contract), `Production handler is missing disabled contract ${contract}`);
}

assert(productionSection.includes("SYNC_PRODUCTION_TOKEN"), "Production routes must use a separate production token");
assert(productionSection.includes("SYNC_PRODUCTION_DB"), "Production routes must use a separate production D1 binding");
assert(productionSection.includes("SYNC_PRODUCTION_BLOBS"), "Production asset routes must use a separate production R2 binding");
assert(workerSource.includes('"Cache-Control": "no-store"'), "JSON responses must default to no-store caching");
assert(!productionSection.includes("SYNC_POC_TOKEN"), "Production routes must not reference scratch POC token");
assert(!productionSection.includes("SYNC_DB"), "Production routes must not reference scratch POC D1 binding");
assert(!productionSection.includes("SYNC_BLOBS"), "Production routes must not reference scratch POC R2 binding");
assert(!scratchSection.includes("SYNC_PRODUCTION_TOKEN"), "Scratch POC routes must not reference production token");
assert(!scratchSection.includes("SYNC_PRODUCTION_DB"), "Scratch POC routes must not reference production D1 binding");
assert(!scratchSection.includes("SYNC_PRODUCTION_BLOBS"), "Scratch POC routes must not reference production R2 binding");
assert(wranglerToml.includes('binding = "SYNC_DB"'), "wrangler.toml is missing scratch POC D1 binding");
assert(wranglerToml.includes('binding = "SYNC_BLOBS"'), "wrangler.toml is missing scratch POC R2 binding");
assert(wranglerToml.includes('# binding = "SYNC_PRODUCTION_DB"'), "wrangler.toml must document commented production D1 binding");
assert(wranglerToml.includes('# binding = "SYNC_PRODUCTION_BLOBS"'), "wrangler.toml must document commented production R2 binding");
assert(!wranglerToml.includes('\nbinding = "SYNC_PRODUCTION_DB"'), "Production D1 binding must stay commented until explicitly enabled");
assert(!wranglerToml.includes('\nbinding = "SYNC_PRODUCTION_BLOBS"'), "Production R2 binding must stay commented until explicitly enabled");
assert(wranglerToml.includes('database_name = "wsp_sync_poc"'), "wrangler.toml must keep scratch POC database separate");
assert(wranglerToml.includes('# database_name = "wsp_sync_production"'), "wrangler.toml must document separate production database name");
assert(wranglerToml.includes('bucket_name = "wsp-sync-poc"'), "wrangler.toml must keep scratch POC bucket separate");
assert(wranglerToml.includes('# bucket_name = "wsp-sync-production"'), "wrangler.toml must document separate production bucket name");
assert(!productionSection.includes("readyToRelease: true"), "Production release must not be enabled by foundation routes");
assert(!productionSection.includes("readyToApply: true"), "Production apply must not be enabled by foundation routes");
assert(!productionSection.includes("eligibleToRun: true"), "Production orchestration must not be enabled by foundation routes");
assert(!productionSection.includes("readyToAdvanceCursor: true"), "Production cursor advancement must not be enabled by foundation routes");
assert(!productionSection.includes(".run()"), "Production foundation routes must not execute D1 write statements");
assert(!productionSection.match(/\bINSERT\b|\bUPDATE\b|\bDELETE\b/), "Production foundation routes must not contain write SQL");
assert(!productionSection.includes(".put("), "Production foundation routes must not write R2 objects");
assert(!productionSection.includes(".delete("), "Production foundation routes must not delete R2 objects");
assert(!productionSection.includes("createMultipartUpload"), "Production foundation routes must not start R2 multipart uploads");
assert(!productionSection.includes("resumeMultipartUpload"), "Production foundation routes must not resume R2 multipart uploads");
assert(!productionSection.match(/\bkill_switch_active\s*=\s*0\b/), "Production foundation routes must not disable kill switches");
assert(!productionSection.match(/\bwrites_enabled\s*=\s*1\b/), "Production foundation routes must not enable production writes");
assert(!productionSchema.match(/\bDROP\b|\bALTER\b|\bTRUNCATE\b/), "Production foundation schema must not contain destructive DDL");
const schemaInsertTargets = [...productionSchema.matchAll(/\bINSERT\s+(?:OR\s+IGNORE\s+)?INTO\s+([a-z_]+)/g)].map((match) => match[1]);
assert(schemaInsertTargets.length === 1 && schemaInsertTargets[0] === "sync_schema_versions", "Production foundation schema may only seed the schema version row");
assert(!productionSchema.match(/\bUPDATE\b|\bDELETE\b/), "Production foundation schema must not update or delete production data");

for (const table of schemaContract.requiredTables) {
    assert(productionSchema.includes(`CREATE TABLE IF NOT EXISTS ${table}`), `Production schema is missing ${table}`);
}

for (const schemaDefault of schemaContract.safeDefaults) {
    assert(productionSchema.includes(schemaDefault), `Production schema is missing safe default: ${schemaDefault}`);
}

for (const foreignKey of schemaContract.requiredForeignKeys) {
    assert(productionSchema.includes(foreignKey), `Production schema is missing foreign key: ${foreignKey}`);
}

for (const forbiddenClause of schemaContract.forbiddenClauses) {
    assert(!productionSchema.includes(forbiddenClause), `Production schema must not contain forbidden clause: ${forbiddenClause}`);
}

for (const nullableColumn of schemaContract.requiredNullableColumns) {
    assert(productionSchema.includes(nullableColumn), `Production schema is missing nullable column contract: ${nullableColumn}`);
    assert(!productionSchema.includes(`${nullableColumn} NOT NULL`), `Production schema must keep payload/diagnostic column nullable: ${nullableColumn}`);
}

for (const nullableCheck of schemaContract.smokeNullableChecks) {
    assert(
        productionSchemaSmoke.includes(`defaultsResult.stdout.includes("${nullableCheck}")`),
        `Production schema smoke is missing nullable-column coverage: ${nullableCheck}`
    );
}

for (const sequenceScopeCheck of schemaContract.smokeSequenceScopeChecks) {
    assert(
        productionSchemaSmoke.includes(`defaultsResult.stdout.includes("${sequenceScopeCheck}")`),
        `Production schema smoke is missing sequence-scope coverage: ${sequenceScopeCheck}`
    );
}

for (const uniqueConstraint of schemaContract.uniqueConstraints) {
    assert(productionSchema.includes(uniqueConstraint), `Production schema is missing unique constraint: ${uniqueConstraint}`);
}

for (const duplicateRejection of schemaContract.smokeDuplicateRejections) {
    assert(
        productionSchemaSmoke.includes(`assertConstraintFailure("${duplicateRejection}"`),
        `Production schema smoke is missing duplicate-rejection coverage: ${duplicateRejection}`
    );
}

for (const index of schemaContract.requiredIndexes) {
    assert(productionSchema.includes(index), `Production schema is missing lookup index contract: ${index}`);
}

const requiredScripts = [
    "sync:prod:d1:create",
    "sync:prod:d1:list",
    "sync:prod:d1:migrate",
    "sync:prod:d1:migrate:local",
    "sync:prod:r2:create",
    "sync:prod:syntax",
    "sync:prod:validate",
    "sync:prod:smoke",
    "sync:prod:schema:smoke",
    "sync:prod:smoke:all",
    "sync:prod:schema:parse",
    "sync:prod:validate:all",
];

for (const script of requiredScripts) {
    assert(packageJSON.scripts?.[script], `package.json is missing ${script}`);
}

assert(
    packageJSON.scripts["sync:prod:syntax"] === "node --check src/index.js && node --check smoke-sync-production-foundation.mjs && node --check smoke-sync-production-schema.mjs && node --check validate-sync-production-foundation.mjs",
    "package.json sync:prod:syntax must check Worker/smoke/validator syntax"
);
assert(
    packageJSON.scripts["sync:prod:validate"] === "npm run sync:prod:syntax && node validate-sync-production-foundation.mjs",
    "package.json sync:prod:validate must run production syntax checks and foundation contract"
);
assert(
    packageJSON.scripts["sync:prod:smoke"] === "node smoke-sync-production-foundation.mjs",
    "package.json sync:prod:smoke must run local production foundation smoke checks"
);
assert(
    packageJSON.scripts["sync:prod:schema:smoke"] === "node smoke-sync-production-schema.mjs",
    "package.json sync:prod:schema:smoke must run local production schema smoke checks"
);
assert(
    packageJSON.scripts["sync:prod:smoke:all"] === "npm run sync:prod:smoke && npm run sync:prod:schema:smoke",
    "package.json sync:prod:smoke:all must run route and schema smoke checks"
);
assert(
    packageJSON.scripts["sync:prod:schema:parse"] === "sqlite3 :memory: < sql/sync_production_schema.sql",
    "package.json sync:prod:schema:parse must parse the production schema in SQLite"
);
assert(
    packageJSON.scripts["sync:prod:validate:all"] === "npm run sync:prod:validate && npm run sync:prod:smoke:all && npm run sync:prod:schema:parse",
    "package.json sync:prod:validate:all must include Worker smoke, schema smoke, and SQLite schema parse validation"
);

const localValidationScripts = [
    "sync:prod:syntax",
    "sync:prod:validate",
    "sync:prod:smoke",
    "sync:prod:schema:smoke",
    "sync:prod:smoke:all",
    "sync:prod:schema:parse",
    "sync:prod:validate:all",
];

const forbiddenLocalScriptTerms = ["wrangler", "--remote", "curl", "http"];

for (const script of localValidationScripts) {
    for (const forbiddenTerm of forbiddenLocalScriptTerms) {
        assert(!packageJSON.scripts[script].includes(forbiddenTerm), `package.json ${script} must remain local-only and not include ${forbiddenTerm}`);
    }
}

const localOnlySources = [
    ["smoke-sync-production-foundation.mjs", readFileSync(new URL("./smoke-sync-production-foundation.mjs", import.meta.url), "utf8")],
    ["smoke-sync-production-schema.mjs", productionSchemaSmoke],
];
const productionFoundationSmoke = localOnlySources[0][1];

const forbiddenLocalSourceTerms = ["wrangler", "--remote", "fetch(\"http", "fetch('http"];
const forbiddenFileMutationTerms = ["writeFile", "appendFile", "rmSync", "unlinkSync", "mkdirSync", "rmdirSync"];

for (const [fileName, source] of localOnlySources) {
    for (const forbiddenTerm of forbiddenLocalSourceTerms) {
        assert(!source.includes(forbiddenTerm), `${fileName} must remain local-only and not include ${forbiddenTerm}`);
    }
    for (const forbiddenTerm of forbiddenFileMutationTerms) {
        assert(!source.includes(forbiddenTerm), `${fileName} must not mutate local files with ${forbiddenTerm}`);
    }
    assert(!source.includes("process.env"), `${fileName} must not read real environment variables or secrets`);
}

const schemaSmokeSpawnTargets = [...productionSchemaSmoke.matchAll(/spawnSync\("([^"]+)"/g)].map((match) => match[1]);
assert(!productionFoundationSmoke.includes("child_process"), "smoke-sync-production-foundation.mjs must not import child_process");
assert(!productionFoundationSmoke.match(/\bspawnSync\b|\bexecSync\b|\bspawn\(|\bexec\(/), "smoke-sync-production-foundation.mjs must not spawn subprocesses");
assert(productionFoundationSmoke.includes("data:text/javascript"), "smoke-sync-production-foundation.mjs must import the Worker from local source via data URL");
assert(productionFoundationSmoke.includes("Buffer.from(workerSource)"), "smoke-sync-production-foundation.mjs must build its local Worker import from workerSource");
assert(productionFoundationSmoke.includes('replace(\'import SYSTEM_PROMPT from "./system-prompt.txt";\''), "smoke-sync-production-foundation.mjs must stub system-prompt.txt for local Worker import");
assert(productionFoundationSmoke.includes("worker.fetch("), "smoke-sync-production-foundation.mjs must dispatch requests through local worker.fetch");
assert(productionFoundationSmoke.includes("routeSpecificSmokeCoverage"), "smoke-sync-production-foundation.mjs must declare explicit route smoke coverage");
assert(productionFoundationSmoke.includes("productionContract.routes.map"), "smoke-sync-production-foundation.mjs must compare smoke coverage against manifest routes");
assert(productionFoundationSmoke.includes("Every production route in the contract must have deliberate route-specific smoke coverage"), "smoke-sync-production-foundation.mjs must fail when manifest routes lack smoke coverage");
assert(productionFoundationSmoke.includes("makeAggregateOnlyDb"), "smoke-sync-production-foundation.mjs must use local mocked DB bindings");
assert(productionFoundationSmoke.includes("makeNoWriteBlobStorage"), "smoke-sync-production-foundation.mjs must use local mocked R2 bindings");
assert(productionFoundationSmoke.includes("Production smoke DB mock received a mutation call"), "smoke-sync-production-foundation.mjs must trap D1 mutation calls in mocks");
assert(productionFoundationSmoke.includes("Production asset smoke blob mock received a write/upload call"), "smoke-sync-production-foundation.mjs must trap R2 write/upload calls in mocks");
assert(productionFoundationSmoke.includes("Production asset smoke DB mock received a mutation call"), "smoke-sync-production-foundation.mjs asset mocks must trap D1 mutation calls");
const requiredR2WriteTrapMethods = ["put", "delete", "createMultipartUpload", "resumeMultipartUpload"];

for (const r2Method of requiredR2WriteTrapMethods) {
    assert(productionFoundationSmoke.includes(`${r2Method}: forbiddenBlobWrite`), `smoke-sync-production-foundation.mjs must trap R2 ${r2Method} calls`);
}
assert(productionFoundationSmoke.includes("must only prepare SELECT statements"), "smoke-sync-production-foundation.mjs must assert mocked D1 prepares are SELECT-only");
assert(productionFoundationSmoke.includes("must not prepare mutation SQL"), "smoke-sync-production-foundation.mjs must reject mutation SQL in mocked D1 prepares");
assert(productionFoundationSmoke.includes("INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE"), "smoke-sync-production-foundation.mjs must retain mutation SQL keyword guard");
assert(productionFoundationSmoke.includes('headers.get("Cache-Control")'), "smoke-sync-production-foundation.mjs must assert response cache headers");
assert(productionFoundationSmoke.includes('"no-store"'), "smoke-sync-production-foundation.mjs must assert no-store response caching");
const requiredRouteSmokeGateAssertions = [
    "notFoundResponse.status, 404",
    "wrongMethodResponse.status, 405",
    "missingAuthResponse.status, 401",
    "wrongTokenResponse.status, 401",
    "unconfiguredTokenResponse.status, 401",
    "unconfiguredDbResponse.status, 503",
    "invalidJsonResponse.status, 400",
];

for (const routeSmokeAssertion of requiredRouteSmokeGateAssertions) {
    assert(productionFoundationSmoke.includes(routeSmokeAssertion), `smoke-sync-production-foundation.mjs is missing shared route gate assertion: ${routeSmokeAssertion}`);
}

const requiredRouteSmokeBlockers = [
    "production_blob_storage_not_configured",
    "production_swiftdata_applier_not_implemented",
    "production_orchestrator_not_wired",
    "production_release_enable_endpoint_not_implemented",
];

for (const blocker of requiredRouteSmokeBlockers) {
    assert(productionFoundationSmoke.includes(blocker), `smoke-sync-production-foundation.mjs is missing route-specific blocker coverage: ${blocker}`);
}

const requiredRouteSmokeDisabledFlags = ["writesEnabled", "appMutationEnabled"];

for (const disabledFlag of requiredRouteSmokeDisabledFlags) {
    assert(productionFoundationSmoke.includes(disabledFlag), `smoke-sync-production-foundation.mjs must assert disabled flag: ${disabledFlag}`);
}
assert(
    productionFoundationSmoke.includes('const productionToken = "production-smoke-token"'),
    "smoke-sync-production-foundation.mjs must use a synthetic production smoke token"
);
assert(
    productionFoundationSmoke.includes('const productionBaseUrl = "https://wsp.example.test/api/sync/production/v1"'),
    "smoke-sync-production-foundation.mjs must use the reserved wsp.example.test smoke URL"
);
assert(!productionFoundationSmoke.includes("workers.dev"), "smoke-sync-production-foundation.mjs must not reference deployed Worker domains");
assert(!productionFoundationSmoke.includes("cloudflare.com"), "smoke-sync-production-foundation.mjs must not reference Cloudflare domains");
assert(
    schemaSmokeSpawnTargets.length === 1 && schemaSmokeSpawnTargets[0] === "sqlite3",
    "smoke-sync-production-schema.mjs may only spawn sqlite3 for in-memory schema checks"
);
assert(productionSchemaSmoke.includes('spawnSync("sqlite3", [":memory:"]'), "smoke-sync-production-schema.mjs must run SQLite only in memory");
assert(productionSchemaSmoke.includes("PRAGMA foreign_keys = ON"), "smoke-sync-production-schema.mjs must enable SQLite foreign-key enforcement");
assert(!productionSchemaSmoke.includes("execSync"), "smoke-sync-production-schema.mjs must not use execSync");

const requiredSchemaSmokeDefaultAssertions = [
    "schema_version|1",
    "environment_defaults|1|0",
    "rollout_defaults|0|0|0",
    "user_defaults|missing|active",
    "device_defaults|active",
    "project_defaults|cloudkit|not_started|0|0",
    "entitlement_defaults|owner|1|0",
    "cursor_defaults|0|0|0|idle",
];

for (const schemaSmokeAssertion of requiredSchemaSmokeDefaultAssertions) {
    assert(productionSchemaSmoke.includes(schemaSmokeAssertion), `smoke-sync-production-schema.mjs is missing default assertion: ${schemaSmokeAssertion}`);
}

const requiredSchemaSmokeInvariantAssertions = [
    "nullable_migration_payloads|1|1",
    "nullable_operation_payloads|1|1|1",
    "nullable_audit_details|1",
    "project_scoped_operation_sequences|2",
    "FOREIGN KEY constraint failed",
    "duplicate environment names",
    "duplicate external subject hashes",
    "duplicate rollout flags per environment",
    "duplicate asset storage keys",
    "duplicate project operation sequences",
];

for (const schemaSmokeAssertion of requiredSchemaSmokeInvariantAssertions) {
    assert(productionSchemaSmoke.includes(schemaSmokeAssertion), `smoke-sync-production-schema.mjs is missing invariant assertion: ${schemaSmokeAssertion}`);
}

const requiredRouteSmokeReadinessFields = [
    "readyToPlanMigration",
    "readyToApplyMigration",
    "readyToTransferAssets",
    "readyToAdvanceCursor",
    "readyToApply",
    "eligibleToRun",
    "eligibleToApply",
    "eligibleToAdvanceCursor",
    "readyToRelease",
    "readyToEnableProductionWrites",
];

for (const readinessField of requiredRouteSmokeReadinessFields) {
    assert(productionFoundationSmoke.includes(readinessField), `smoke-sync-production-foundation.mjs must assert readiness field: ${readinessField}`);
}

const requiredRouteSmokePolicyLimitChecks = [
    "productionContract.policy.maxAssetManifestItems + 1",
    "assets exceeds 1000",
    "productionContract.policy.maxApplyWindowOperations + 1",
    "operationWindow.operationCount exceeds 500",
];

for (const policyLimitCheck of requiredRouteSmokePolicyLimitChecks) {
    assert(productionFoundationSmoke.includes(policyLimitCheck), `smoke-sync-production-foundation.mjs is missing policy limit check: ${policyLimitCheck}`);
}

const requiredRouteSmokeReadOnlyQueryAssertions = [
    "identityCheckDb.preparedStatements.length, 3",
    "migrationPreflightDb.preparedStatements.length, 4",
    "assetPreflightDb.preparedStatements.length, 4",
    "assetReadyDb.preparedStatements.length, 4",
    "applyPreflightDb.preparedStatements.length, 5",
    "orchestratorEligibilityDb.preparedStatements.length, 5",
    "releaseReadinessDb.preparedStatements.length, 2",
    "db.preparedStatements.length, 2",
];

for (const queryAssertion of requiredRouteSmokeReadOnlyQueryAssertions) {
    assert(productionFoundationSmoke.includes(queryAssertion), `smoke-sync-production-foundation.mjs is missing read-only query assertion: ${queryAssertion}`);
}

for (const route of productionRoutes) {
    assert(readme.includes(`/api/sync/production/v1${route}`), `README is missing ${route} documentation`);
}

const requiredReadmeGuidance = [
    "npm run sync:prod:d1:create",
    "npm run sync:prod:r2:create",
    "npm run sync:prod:d1:migrate",
    "npm run sync:prod:syntax",
    "npm run sync:prod:validate",
    "npm run sync:prod:smoke",
    "npm run sync:prod:schema:smoke",
    "npm run sync:prod:smoke:all",
    "npm run sync:prod:schema:parse",
    "npm run sync:prod:validate:all",
    "npx wrangler secret put SYNC_PRODUCTION_TOKEN",
    "no app-side SwiftData mutation",
];

for (const guidance of requiredReadmeGuidance) {
    assert(readme.includes(guidance), `README is missing production guidance: ${guidance}`);
}

console.log("sync production foundation contract ok");