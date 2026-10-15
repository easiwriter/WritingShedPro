import assert from "node:assert/strict";
import test from "node:test";
import {
    ANALYST_PRODUCT_ID,
    DEFAULT_APP_BUNDLE_ID,
    decodeJWSTransaction,
    validateAnalystTransaction,
    verifyAnalystSubscription,
    verifyStoreTransaction,
} from "../src/apple-subscription.mjs";

const transactionID = "2000000123456789";
const now = 1_800_000_000_000;

function validTransaction(overrides = {}) {
    return {
        transactionId: transactionID,
        originalTransactionId: "2000000000000001",
        productId: ANALYST_PRODUCT_ID,
        bundleId: DEFAULT_APP_BUNDLE_ID,
        environment: "Production",
        type: "Auto-Renewable Subscription",
        expiresDate: now + 60_000,
        ...overrides,
    };
}

function signedTransaction(payload) {
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
    return `${encode({ alg: "ES256" })}.${encode(payload)}.signature`;
}

test("decodes the Apple transaction payload", () => {
    assert.deepEqual(
        decodeJWSTransaction(signedTransaction(validTransaction())),
        validTransaction()
    );
});

test("accepts an active matching production subscription", () => {
    assert.equal(
        validateAnalystTransaction(validTransaction(), transactionID, { now }),
        null
    );
});

test("rejects wrong product, bundle, environment, type, ID, expiry, revocation, and upgrade", () => {
    const invalidTransactions = [
        validTransaction({ transactionId: "2000000999999999" }),
        validTransaction({ productId: "com.example.other" }),
        validTransaction({ bundleId: "com.example.other" }),
        validTransaction({ environment: "Sandbox" }),
        validTransaction({ type: "Non-Consumable" }),
        validTransaction({ expiresDate: now }),
        validTransaction({ revocationDate: now - 1 }),
        validTransaction({ isUpgraded: true }),
    ];

    for (const transaction of invalidTransactions) {
        assert.notEqual(
            validateAnalystTransaction(transaction, transactionID, { now }),
            null
        );
    }
});

test("fails closed when Apple credentials are missing", async () => {
    const result = await verifyAnalystSubscription(transactionID, {});
    assert.deepEqual(result, {
        authorized: false,
        status: 503,
        error: "Subscription verification unavailable",
    });
});

test("rejects malformed transaction identifiers without calling Apple", async () => {
    let createdClient = false;
    const result = await verifyAnalystSubscription(
        "not-a-transaction",
        {},
        () => {
            createdClient = true;
        }
    );

    assert.equal(createdClient, false);
    assert.equal(result.authorized, false);
    assert.equal(result.status, 401);
});

test("authorizes only a transaction returned by Apple that passes every check", async () => {
    const env = {
        APPLE_IAP_PRIVATE_KEY: "private-key",
        APPLE_IAP_KEY_ID: "key-id",
        APPLE_IAP_ISSUER_ID: "issuer-id",
    };
    const result = await verifyAnalystSubscription(
        transactionID,
        env,
        () => ({
            getTransactionInfo: async () => ({
                signedTransactionInfo: signedTransaction(validTransaction({
                    expiresDate: Date.now() + 60_000,
                })),
            }),
        })
    );

    assert.equal(result.authorized, true);
    assert.equal(result.originalTransactionID, "2000000000000001");
});

test("returns Apple transaction details for an exact product match", async () => {
    const env = {
        APPLE_IAP_PRIVATE_KEY: "private-key",
        APPLE_IAP_KEY_ID: "key-id",
        APPLE_IAP_ISSUER_ID: "issuer-id",
    };
    const transaction = validTransaction({
        productId: "com.writingshedpro.fullaccess",
        type: "Non-Consumable",
        purchaseDate: now,
        inAppOwnershipType: "PURCHASED",
        price: 39990,
        currency: "GBP",
    });

    const result = await verifyStoreTransaction(
        transactionID,
        transaction.productId,
        env,
        () => ({
            getTransactionInfo: async () => ({
                signedTransactionInfo: signedTransaction(transaction),
            }),
        })
    );

    assert.equal(result.verified, true);
    assert.deepEqual(result.transaction, transaction);
});

test("rejects a server transaction for a different product", async () => {
    const env = {
        APPLE_IAP_PRIVATE_KEY: "private-key",
        APPLE_IAP_KEY_ID: "key-id",
        APPLE_IAP_ISSUER_ID: "issuer-id",
    };
    const result = await verifyStoreTransaction(
        transactionID,
        "com.writingshedpro.fullaccess",
        env,
        () => ({
            getTransactionInfo: async () => ({
                signedTransactionInfo: signedTransaction(validTransaction()),
            }),
        })
    );

    assert.equal(result.verified, false);
    assert.equal(result.status, 403);
});
