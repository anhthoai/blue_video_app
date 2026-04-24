import { ServiceAccount, cert, getApps, initializeApp } from 'firebase-admin/app';
import { MulticastMessage, getMessaging } from 'firebase-admin/messaging';

type PushNotificationPayload = {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  sound?: string;
};

let hasLoggedDisabledState = false;
let hasLoggedConfigurationError = false;

function isPushEnabled() {
  return process.env['ENABLE_PUSH_NOTIFICATIONS'] === 'true';
}

function normalizeServiceAccountJson(rawJson: string) {
  const trimmed = rawJson.trim();

  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }

  return trimmed;
}

function buildServiceAccount(): ServiceAccount | null {
  const rawJson = process.env['FIREBASE_SERVICE_ACCOUNT_JSON'];
  if (rawJson) {
    try {
      return JSON.parse(normalizeServiceAccountJson(rawJson)) as ServiceAccount;
    } catch (error) {
      if (!hasLoggedConfigurationError) {
        console.error(
          'Invalid FIREBASE_SERVICE_ACCOUNT_JSON. Use a single-line escaped JSON string, a single-quoted multiline JSON value, or set FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY instead:',
          error
        );
      }
      hasLoggedConfigurationError = true;
    }
  }

  const projectId = process.env['FIREBASE_PROJECT_ID'];
  const clientEmail = process.env['FIREBASE_CLIENT_EMAIL'];
  const privateKey = process.env['FIREBASE_PRIVATE_KEY']?.replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    if (!hasLoggedConfigurationError) {
      console.warn(
        'FCM is enabled but Firebase service account credentials are missing. ' +
            'Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY.'
      );
      hasLoggedConfigurationError = true;
    }
    return null;
  }

  return {
    projectId,
    clientEmail,
    privateKey,
  };
}

function getMessagingClient() {
  if (!isPushEnabled()) {
    if (!hasLoggedDisabledState) {
      console.log('FCM push notifications are disabled by configuration.');
      hasLoggedDisabledState = true;
    }
    return null;
  }

  const serviceAccount = buildServiceAccount();
  if (!serviceAccount) {
    return null;
  }

  if (getApps().length === 0) {
    initializeApp({
      credential: cert(serviceAccount),
    });
  }

  return getMessaging();
}

export async function sendPushNotification(
  payload: PushNotificationPayload
): Promise<string[]> {
  const messaging = getMessagingClient();
  if (!messaging) {
    return [];
  }

  const tokens = [...new Set(payload.tokens.filter(token => token.trim().length > 0))];
  if (tokens.length === 0) {
    return [];
  }

  const message: MulticastMessage = {
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    android: {
      priority: 'high',
      notification: {
        sound: payload.sound || 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: payload.sound || 'default',
          contentAvailable: true,
        },
      },
    },
    ...(payload.data ? { data: payload.data } : {}),
  };

  const response = await messaging.sendEachForMulticast(message);

  const invalidTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }

    const errorCode = result.error?.code;
    if (
      errorCode === 'messaging/invalid-registration-token' ||
      errorCode === 'messaging/registration-token-not-registered'
    ) {
      const token = tokens[index];
      if (token) {
        invalidTokens.push(token);
      }
      return;
    }

    console.error('Failed to send FCM push notification:', result.error);
  });

  return invalidTokens;
}