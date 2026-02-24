import { UlozService } from './ulozService';

export interface UlozStorageConfig {
  id: number;
  username: string;
  password: string;
  apiKey: string;
  baseUrl: string;
  proxyCdnUrl?: string;
  libraryFolders: Record<string, string>;
}

const ulozConfigCache = new Map<number, UlozStorageConfig>();
const ulozServiceCache = new Map<number, UlozService>();

function parseIntSafe(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const num = Number.parseInt(String(value), 10);
  return Number.isFinite(num) && num > 0 ? num : null;
}

function envKey(id: number, key: string): string {
  return `ULOZ_${id}_${key}`;
}

function readLibraryFolderMap(id: number, env: NodeJS.ProcessEnv): Record<string, string> {
  const map: Record<string, string> = {};
  const prefix = `ULOZ_${id}_LIBRARY_`;

  for (const [key, value] of Object.entries(env)) {
    if (!key || !value) continue;
    if (!key.toUpperCase().startsWith(prefix)) continue;
    const match = key.match(new RegExp(`^ULOZ_${id}_LIBRARY_(.+)_FOLDER$`, 'i'));
    if (!match?.[1]) continue;
    const rawSection = match[1];
    const section = rawSection
      .toLowerCase()
      .replace(/__+/g, '_')
      .replace(/_/g, '-');
    map[section] = String(value).trim();
  }

  // Backward compatible: ULOZ_LIBRARY_*_FOLDER belongs to id=1
  if (id === 1) {
    for (const [key, value] of Object.entries(env)) {
      if (!key || !value) continue;
      const match = key.match(/^ULOZ_LIBRARY_(.+)_FOLDER$/i);
      if (!match?.[1]) continue;
      const rawSection = match[1];
      const section = rawSection
        .toLowerCase()
        .replace(/__+/g, '_')
        .replace(/_/g, '-');
      if (!map[section]) {
        map[section] = String(value).trim();
      }
    }
  }

  return map;
}

function readEnvUlozConfig(id: number, env: NodeJS.ProcessEnv): UlozStorageConfig | null {
  const username = env[envKey(id, 'USERNAME')] || (id === 1 ? env['ULOZ_USERNAME'] : undefined);
  const password = env[envKey(id, 'PASSWORD')] || (id === 1 ? env['ULOZ_PASSWORD'] : undefined);
  const apiKey = env[envKey(id, 'API_KEY')] || (id === 1 ? env['ULOZ_API_KEY'] : undefined);
  const baseUrl = env[envKey(id, 'BASE_URL')] || (id === 1 ? env['ULOZ_BASE_URL'] : undefined) || 'https://apis.uloz.to';
  const proxyCdnUrlRaw =
    env[envKey(id, 'PROXY_CDN_URL')] ||
    env[envKey(id, 'CDN_URL')] ||
    (id === 1 ? env['ULOZ_PROXY_CDN_URL'] || env['ULOZ_CDN_URL'] : undefined);
  const proxyCdnUrl = proxyCdnUrlRaw ? String(proxyCdnUrlRaw).trim() : undefined;

  const hasAny = Boolean(username || password || apiKey || proxyCdnUrl);
  if (!hasAny) return null;

  return {
    id,
    username: username || '',
    password: password || '',
    apiKey: apiKey || '',
    baseUrl,
    ...(proxyCdnUrl ? { proxyCdnUrl } : {}),
    libraryFolders: readLibraryFolderMap(id, env),
  };
}

function discoverUlozStorageIds(env: NodeJS.ProcessEnv): number[] {
  const ids = new Set<number>();

  const explicit = env['ULOZ_STORAGE_IDS'];
  if (explicit) {
    for (const part of explicit.split(',')) {
      const id = parseIntSafe(part.trim());
      if (id) ids.add(id);
    }
  }

  for (const key of Object.keys(env)) {
    const match = key.match(/^ULOZ_(\d+)_/);
    if (match?.[1]) {
      const id = parseIntSafe(match[1]);
      if (id) ids.add(id);
    }
  }

  if (ids.size === 0) {
    ids.add(1);
  }

  return Array.from(ids).sort((a, b) => a - b);
}

export function getUlozStorageConfig(id: number, env: NodeJS.ProcessEnv = process.env): UlozStorageConfig {
  const cached = ulozConfigCache.get(id);
  if (cached) return cached;

  const config = readEnvUlozConfig(id, env);
  if (!config) {
    if (id !== 1) return getUlozStorageConfig(1, env);
    const proxyCdnUrlRaw = env['ULOZ_PROXY_CDN_URL'] || env['ULOZ_CDN_URL'];
    const proxyCdnUrl = proxyCdnUrlRaw ? String(proxyCdnUrlRaw).trim() : undefined;
    const fallback: UlozStorageConfig = {
      id: 1,
      username: env['ULOZ_USERNAME'] || '',
      password: env['ULOZ_PASSWORD'] || '',
      apiKey: env['ULOZ_API_KEY'] || '',
      baseUrl: env['ULOZ_BASE_URL'] || 'https://apis.uloz.to',
      ...(proxyCdnUrl ? { proxyCdnUrl } : {}),
      libraryFolders: readLibraryFolderMap(1, env),
    };
    ulozConfigCache.set(1, fallback);
    return fallback;
  }

  ulozConfigCache.set(id, config);
  return config;
}

export function listUlozStorageConfigs(env: NodeJS.ProcessEnv = process.env): UlozStorageConfig[] {
  const ids = discoverUlozStorageIds(env);
  return ids
    .map((id) => getUlozStorageConfig(id, env))
    .filter((cfg) => cfg.id === 1 || readEnvUlozConfig(cfg.id, env) !== null);
}

export function getUlozService(id: number, env: NodeJS.ProcessEnv = process.env): UlozService {
  const cached = ulozServiceCache.get(id);
  if (cached) return cached;

  const cfg = getUlozStorageConfig(id, env);
  const service = new UlozService({
    username: cfg.username,
    password: cfg.password,
    apiKey: cfg.apiKey,
    baseUrl: cfg.baseUrl,
  });
  ulozServiceCache.set(id, service);
  return service;
}

export function resolveUlozStorageId(req?: any, env: NodeJS.ProcessEnv = process.env): number {
  const headerId = req?.headers?.['x-uloz-storage-id'];
  const queryId = req?.query?.['ulozStorageId'] ?? req?.query?.['storageId'];
  const bodyId = req?.body?.['ulozStorageId'] ?? req?.body?.['storageId'];
  const parsed = parseIntSafe(headerId) ?? parseIntSafe(queryId) ?? parseIntSafe(bodyId);
  if (parsed) return parsed;

  const envDefault = parseIntSafe(env['ULOZ_DEFAULT_STORAGE_ID'] || env['ULOZ_STORAGE_ID']);
  return envDefault || 1;
}
