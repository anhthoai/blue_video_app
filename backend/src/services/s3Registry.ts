import { S3Client } from '@aws-sdk/client-s3';

export interface S3StorageConfig {
  id: number;
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
  bucketName: string;
  cdnUrl?: string;
  forcePathStyle?: boolean;
}

const s3ConfigCache = new Map<number, S3StorageConfig>();
const s3ClientCache = new Map<number, S3Client>();

function parseIntSafe(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const num = Number.parseInt(String(value), 10);
  return Number.isFinite(num) && num > 0 ? num : null;
}

function envKey(id: number, key: string): string {
  return `S3_${id}_${key}`;
}

function readEnvS3Config(id: number, env: NodeJS.ProcessEnv): S3StorageConfig | null {
  const endpoint = env[envKey(id, 'ENDPOINT')] || (id === 1 ? env['S3_ENDPOINT'] : undefined);
  const accessKeyId = env[envKey(id, 'ACCESS_KEY_ID')] || (id === 1 ? env['S3_ACCESS_KEY_ID'] : undefined);
  const secretAccessKey = env[envKey(id, 'SECRET_ACCESS_KEY')] || (id === 1 ? env['S3_SECRET_ACCESS_KEY'] : undefined);
  const region = env[envKey(id, 'REGION')] || (id === 1 ? env['S3_REGION'] : undefined) || 'auto';
  const bucketName = env[envKey(id, 'BUCKET_NAME')] || (id === 1 ? env['S3_BUCKET_NAME'] : undefined);
  const cdnUrl = env[envKey(id, 'CDN_URL')] || (id === 1 ? env['CDN_URL'] : undefined) || '';

  const hasAny = Boolean(endpoint || accessKeyId || secretAccessKey || bucketName || cdnUrl);
  if (!hasAny) {
    return null;
  }

  return {
    id,
    endpoint: endpoint || 'https://s3.amazonaws.com',
    accessKeyId: accessKeyId || '',
    secretAccessKey: secretAccessKey || '',
    region,
    bucketName: bucketName || 'blue-video-storage',
    cdnUrl: cdnUrl || '',
    forcePathStyle: true,
  };
}

function discoverS3StorageIds(env: NodeJS.ProcessEnv): number[] {
  const ids = new Set<number>();

  // Explicit list e.g. S3_STORAGE_IDS=1,2,3
  const explicit = env['S3_STORAGE_IDS'];
  if (explicit) {
    for (const part of explicit.split(',')) {
      const id = parseIntSafe(part.trim());
      if (id) ids.add(id);
    }
  }

  // Discover by scanning env keys S3_<id>_...
  for (const key of Object.keys(env)) {
    const match = key.match(/^S3_(\d+)_/);
    if (match?.[1]) {
      const id = parseIntSafe(match[1]);
      if (id) ids.add(id);
    }
  }

  // Backward compatible single storage
  if (ids.size === 0) {
    ids.add(1);
  }

  return Array.from(ids).sort((a, b) => a - b);
}

export function getS3StorageConfig(id: number, env: NodeJS.ProcessEnv = process.env): S3StorageConfig {
  const cached = s3ConfigCache.get(id);
  if (cached) return cached;

  const config = readEnvS3Config(id, env);
  if (!config) {
    // If not configured, fall back to storage 1 (keeps app working)
    if (id !== 1) {
      return getS3StorageConfig(1, env);
    }
    // Storage 1 default even if env missing
    const fallback: S3StorageConfig = {
      id: 1,
      endpoint: env['S3_ENDPOINT'] || 'https://s3.amazonaws.com',
      accessKeyId: env['S3_ACCESS_KEY_ID'] || '',
      secretAccessKey: env['S3_SECRET_ACCESS_KEY'] || '',
      region: env['S3_REGION'] || 'auto',
      bucketName: env['S3_BUCKET_NAME'] || 'blue-video-storage',
      cdnUrl: env['CDN_URL'] || '',
      forcePathStyle: true,
    };
    s3ConfigCache.set(1, fallback);
    return fallback;
  }

  s3ConfigCache.set(id, config);
  return config;
}

export function listS3StorageConfigs(env: NodeJS.ProcessEnv = process.env): S3StorageConfig[] {
  const ids = discoverS3StorageIds(env);
  return ids
    .map((id) => getS3StorageConfig(id, env))
    // Only include configs that are explicitly present OR the default 1
    .filter((cfg) => cfg.id === 1 || readEnvS3Config(cfg.id, env) !== null);
}

export function getS3Client(id: number, env: NodeJS.ProcessEnv = process.env): S3Client {
  const cached = s3ClientCache.get(id);
  if (cached) return cached;

  const cfg = getS3StorageConfig(id, env);

  const client = new S3Client({
    endpoint: cfg.endpoint,
    credentials: {
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
    },
    region: cfg.region,
    forcePathStyle: cfg.forcePathStyle ?? true,
  });

  s3ClientCache.set(id, client);
  return client;
}

export function getS3PublicBaseUrl(id: number, env: NodeJS.ProcessEnv = process.env): string {
  const cfg = getS3StorageConfig(id, env);
  const cdn = (cfg.cdnUrl || '').trim().replace(/\/$/, '');
  if (cdn) return cdn;
  return cfg.endpoint.trim().replace(/\/$/, '');
}

export function resolveS3WriteStorageId(req?: any, env: NodeJS.ProcessEnv = process.env): number {
  const headerId = req?.headers?.['x-s3-storage-id'] ?? req?.headers?.['x-storage-id'];
  const queryId = req?.query?.['s3StorageId'] ?? req?.query?.['storageId'];
  const bodyId = req?.body?.['s3StorageId'] ?? req?.body?.['storageId'];
  const parsed = parseIntSafe(headerId) ?? parseIntSafe(queryId) ?? parseIntSafe(bodyId);
  if (parsed) return parsed;

  const envDefault = parseIntSafe(env['S3_WRITE_STORAGE_ID'] || env['S3_DEFAULT_STORAGE_ID']);
  return envDefault || 1;
}

export function makeS3Ref(storageId: number, key: string): string {
  const cleanKey = key.replace(/^\/+/, '');
  return `s3://${storageId}/${cleanKey}`;
}

export function parseS3Ref(input: string): { storageId: number; key: string } {
  const trimmed = (input || '').trim();
  // New format: s3://<storageId>/<key>
  const match = trimmed.match(/^s3:\/\/(\d+)\/(.+)$/);
  if (match?.[1] && match?.[2]) {
    return {
      storageId: Number.parseInt(match[1], 10) || 1,
      key: match[2].replace(/^\/+/, ''),
    };
  }

  // Legacy format used in existing code: s3://<key>
  if (trimmed.startsWith('s3://')) {
    return {
      storageId: 1,
      key: trimmed.slice('s3://'.length).replace(/^\/+/, ''),
    };
  }

  // Backward compatibility: plain object key
  return {
    storageId: 1,
    key: trimmed.replace(/^\/+/, ''),
  };
}
