import {
    APIException,
    AppStoreServerAPIClient,
    Environment,
} from "@apple/app-store-server-library";

export const ANALYST_PRODUCT_ID = "com.writingshedpro.manuscriptanalyst";
export const DEFAULT_APP_BUNDLE_ID = "com.appworks.writingshedpro";

const AUTO_RENEWABLE_SUBSCRIPTION_TYPE = "Auto-Renewable Subscription";
const TRANSACTION_ID_PATTERN = /^\d{1,64}$/;

function decodeBase64URL(value) {
    const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
    const padding = "=".repeat((4 - (base64.length % 4)) % 4);
    const bytes = Uint8Array.from(atob(base64 + padding), (character) => character.charCodeAt(0));
    return new TextDecoder().decode(bytes);
}

export function decodeJWSTransaction(signedTransactionInfo) {
    if (typeof signedTransactionInfo !== "string") {
        throw new Error("Apple response did not include signed transaction information");
    }

    const segments = signedTransactionInfo.split(".");
    if (segments.length !== 3) {
        throw new Error("Apple returned malformed signed transaction information");
    }

    return JSON.parse(decodeBase64URL(segments[1]));
}

export function validateAnalystTransaction(
    transaction,
    requestedTransactionID,
    {
        bundleID = DEFAULT_APP_BUNDLE_ID,
        environment = Environment.PRODUCTION,
        now = Date.now(),
    } = {}
) {
    if (transaction.transactionId !== requestedTransactionID) {
        return "Apple returned a different transaction";
    }
    if (transaction.productId !== ANALYST_PRODUCT_ID) {
        return "Transaction is for a different product";
    }
    if (transaction.bundleId !== bundleID) {
        return "Transaction is for a different app";
    }
    if (transaction.environment !== environment) {
        return "Transaction is from a different App Store environment";
    }
    if (transaction.type !== AUTO_RENEWABLE_SUBSCRIPTION_TYPE) {
        return "Transaction is not an auto-renewable subscription";
    }
    if (transaction.revocationDate != null) {
        return "Subscription has been revoked";
    }
    if (transaction.isUpgraded === true) {
        return "Subscription transaction has been superseded";
    }
    if (!Number.isFinite(transaction.expiresDate) || transaction.expiresDate <= now) {
        return "Subscription has expired";
    }
    return null;
}

function appStoreEnvironment(env) {
    if (!env.APPLE_IAP_ENVIRONMENT || env.APPLE_IAP_ENVIRONMENT === Environment.PRODUCTION) {
        return Environment.PRODUCTION;
    }
    if (env.APPLE_IAP_ENVIRONMENT === Environment.SANDBOX) {
        return Environment.SANDBOX;
    }
    throw new Error("APPLE_IAP_ENVIRONMENT must be Production or Sandbox");
}

function createAppStoreClient(env, environment, bundleID) {
    return new AppStoreServerAPIClient(
        env.APPLE_IAP_PRIVATE_KEY,
        env.APPLE_IAP_KEY_ID,
        env.APPLE_IAP_ISSUER_ID,
        bundleID,
        environment
    );
}

export async function verifyStoreTransaction(
    transactionID,
    expectedProductID,
    env,
    clientFactory = createAppStoreClient
) {
    if (typeof transactionID !== "string" || !TRANSACTION_ID_PATTERN.test(transactionID)) {
        return { verified: false, status: 401, error: "Valid transaction required" };
    }
    if (typeof expectedProductID !== "string" || expectedProductID.length === 0) {
        return { verified: false, status: 400, error: "Valid product required" };
    }

    const requiredConfiguration = [
        env.APPLE_IAP_PRIVATE_KEY,
        env.APPLE_IAP_KEY_ID,
        env.APPLE_IAP_ISSUER_ID,
    ];
    if (requiredConfiguration.some((value) => typeof value !== "string" || value.length === 0)) {
        console.error("Apple transaction verification is not configured");
        return { verified: false, status: 503, error: "Transaction verification unavailable" };
    }

    let environment;
    try {
        environment = appStoreEnvironment(env);
    } catch (error) {
        console.error("Invalid Apple transaction environment configuration:", error.message);
        return { verified: false, status: 503, error: "Transaction verification unavailable" };
    }

    const bundleID = env.APPLE_APP_BUNDLE_ID || DEFAULT_APP_BUNDLE_ID;

    try {
        const client = clientFactory(env, environment, bundleID);
        const response = await client.getTransactionInfo(transactionID);
        const transaction = decodeJWSTransaction(response.signedTransactionInfo);

        if (transaction.transactionId !== transactionID) {
            return { verified: false, status: 403, error: "Apple returned a different transaction" };
        }
        if (transaction.productId !== expectedProductID) {
            return { verified: false, status: 403, error: "Transaction is for a different product" };
        }
        if (transaction.bundleId !== bundleID) {
            return { verified: false, status: 403, error: "Transaction is for a different app" };
        }
        if (transaction.environment !== environment) {
            return { verified: false, status: 403, error: "Transaction is from a different App Store environment" };
        }
        if (transaction.revocationDate != null) {
            return { verified: false, status: 403, error: "Transaction has been revoked" };
        }

        return { verified: true, transaction };
    } catch (error) {
        if (error instanceof APIException && [400, 401, 404].includes(error.httpStatusCode)) {
            console.warn("Apple rejected transaction verification");
            return { verified: false, status: 401, error: "Valid transaction required" };
        }

        console.error("Apple transaction verification failed:", error);
        return { verified: false, status: 502, error: "Transaction verification unavailable" };
    }
}

export async function verifyAnalystSubscription(
    transactionID,
    env,
    clientFactory = createAppStoreClient
) {
    const verification = await verifyStoreTransaction(
        transactionID,
        ANALYST_PRODUCT_ID,
        env,
        clientFactory
    );
    if (!verification.verified) {
        return {
            authorized: false,
            status: verification.status,
            error: verification.status === 503 || verification.status === 502
                ? "Subscription verification unavailable"
                : "Valid subscription required",
        };
    }

    const environment = appStoreEnvironment(env);
    const bundleID = env.APPLE_APP_BUNDLE_ID || DEFAULT_APP_BUNDLE_ID;
    const validationError = validateAnalystTransaction(
        verification.transaction,
        transactionID,
        { bundleID, environment }
    );
    if (validationError) {
        console.warn("Rejected Manuscript Analyst subscription:", validationError);
        return { authorized: false, status: 403, error: "Active subscription required" };
    }

    return {
        authorized: true,
        originalTransactionID: verification.transaction.originalTransactionId,
    };
}
