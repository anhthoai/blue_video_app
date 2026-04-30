const DEFAULT_DEVELOPMENT_API_ORIGIN = 'http://localhost:8000';
const DEFAULT_PRODUCTION_API_ORIGIN = 'https://api.onlybl.com';

const LOCAL_HOSTNAMES = new Set([
  'localhost',
  '127.0.0.1',
  '0.0.0.0',
  '::1',
  '[::1]',
]);

function normalizeOrigin(value?: string): string | null {
  const trimmedValue = value?.trim();
  if (!trimmedValue) {
    return null;
  }

  try {
    return new URL(trimmedValue).origin;
  } catch {
    return trimmedValue.replace(/\/+$/, '');
  }
}

function isLocalOrigin(value: string): boolean {
  try {
    return LOCAL_HOSTNAMES.has(new URL(value).hostname);
  } catch {
    return /(localhost|127\.0\.0\.1|0\.0\.0\.0|::1)/i.test(value);
  }
}

export function getPublicApiOrigin(): string {
  const isProduction = process.env['NODE_ENV'] === 'production';
  const candidates = [
    process.env['PUBLIC_API_URL'],
    process.env['API_URL'],
    process.env['BASE_URL'],
  ]
    .map((value) => normalizeOrigin(value))
    .filter((value): value is string => Boolean(value));

  const resolvedOrigin = candidates.find(
    (value) => !isProduction || !isLocalOrigin(value)
  );

  if (resolvedOrigin) {
    return resolvedOrigin;
  }

  return isProduction
    ? DEFAULT_PRODUCTION_API_ORIGIN
    : DEFAULT_DEVELOPMENT_API_ORIGIN;
}

export function buildVerificationUrl(token: string): string {
  return `${getPublicApiOrigin()}/api/v1/auth/verify-email?token=${token}`;
}

export function buildPasswordResetUrl(token: string): string {
  return `${getPublicApiOrigin()}/auth/reset-password?token=${encodeURIComponent(token)}`;
}