import crypto from 'crypto';
import { ContentSource } from '@prisma/client';
import prisma from '../lib/prisma';
import {
  getUlozService,
  getUlozStorageConfig,
  listUlozStorageConfigs,
} from './ulozRegistry';

// ---------------------------------------------------------------------------
// Content-type helpers
// ---------------------------------------------------------------------------

const VIDEO_EXTENSIONS = new Set([
  'mp4', 'm4v', 'mkv', 'mov', 'webm', 'avi', 'flv', 'wmv', 'm2ts', 'ts',
]);
const AUDIO_EXTENSIONS = new Set([
  'mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus', 'wma',
]);
const EBOOK_EXTENSIONS = new Set([
  'pdf', 'epub', 'mobi', 'azw3', 'djvu', 'fb2',
]);
const IMAGE_EXTENSIONS = new Set([
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'svg',
]);

function detectContentType(ext: string): string {
  const e = ext.toLowerCase().replace(/^\./, '');
  if (VIDEO_EXTENSIONS.has(e)) return 'video';
  if (AUDIO_EXTENSIONS.has(e)) return 'audio';
  if (EBOOK_EXTENSIONS.has(e)) return 'ebook';
  if (IMAGE_EXTENSIONS.has(e)) return 'image';
  return 'file';
}

const MIME_MAP: Record<string, string> = {
  mp4: 'video/mp4',
  m4v: 'video/x-m4v',
  mov: 'video/quicktime',
  mkv: 'video/x-matroska',
  webm: 'video/webm',
  avi: 'video/x-msvideo',
  flv: 'video/x-flv',
  wmv: 'video/x-ms-wmv',
  mp3: 'audio/mpeg',
  aac: 'audio/aac',
  m4a: 'audio/mp4',
  wav: 'audio/wav',
  flac: 'audio/flac',
  ogg: 'audio/ogg',
  opus: 'audio/ogg',
  pdf: 'application/pdf',
  epub: 'application/epub+zip',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
};

function detectMimeType(ext: string): string | null {
  return MIME_MAP[ext.toLowerCase().replace(/^\./, '')] ?? null;
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

function sectionToDisplayName(section: string): string {
  return section
    .split(/[-_]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function buildSlugPath(pathSegments: string[]): string {
  return pathSegments
    .map((s) =>
      s
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, ''),
    )
    .filter(Boolean)
    .join('/');
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

export interface SyncStatusEntry {
  id: string;
  storageId: number;
  section: string;
  status: string;
  lastSyncAt: Date | null;
  startedAt: Date | null;
  finishedAt: Date | null;
  lastTickAt: Date | null;
  totalIndexed: number;
  errorMessage: string | null;
}

export class LibrarySyncService {
  /** Keys of section syncs currently running in-process. */
  private readonly activeSyncs = new Set<string>();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /**
   * Returns true when the section has no sync record, or its last successful
   * sync finished more than `maxAgeMs` milliseconds ago.
   * Returns false when a sync is currently running (no point triggering another).
   */
  async isSectionStale(
    storageId: number,
    section: string,
    maxAgeMs = 30 * 60 * 1000,
  ): Promise<boolean> {
    const key = `${storageId}:${section}`;
    const state = await prisma.librarySyncState
      .findUnique({ where: { id: key } })
      .catch(() => null);
    if (!state) return true;
    if (state.status === 'scanning') return false; // already running
    if (!state.lastSyncAt) return true;
    return Date.now() - state.lastSyncAt.getTime() > maxAgeMs;
  }

  /** True while the section is being crawled (in-process lock). */
  isActivelySyncing(storageId: number, section: string): boolean {
    return this.activeSyncs.has(`${storageId}:${section}`);
  }

  /** Returns the sync state for every configured section. */
  async getAllSyncStates(): Promise<SyncStatusEntry[]> {
    const rows = await prisma.librarySyncState
      .findMany({ orderBy: [{ storageId: 'asc' }, { section: 'asc' }] })
      .catch(() => [] as any[]);

    return rows.map((r: any) => ({
      id: r.id,
      storageId: r.storageId,
      section: r.section,
      status: r.status,
      lastSyncAt: r.lastSyncAt,
      startedAt: r.startedAt,
      finishedAt: r.finishedAt,
      lastTickAt: r.lastTickAt,
      totalIndexed: r.totalIndexed,
      errorMessage: r.errorMessage,
    }));
  }

  /** Fire-and-forget wrapper — safe to call from request handlers. */
  triggerBackgroundSync(storageId: number, section: string): void {
    const key = `${storageId}:${section}`;
    if (this.activeSyncs.has(key)) return;
    this.syncSection(storageId, section).catch((err) =>
      console.error(
        `[LibrarySync] Unhandled error in background sync for "${section}" (storage ${storageId}):`,
        err?.message ?? err,
      ),
    );
  }

  /** Stagger-trigger all configured sections across all uloz storages. */
  async triggerAllSections(): Promise<void> {
    const configs = listUlozStorageConfigs();
    for (const cfg of configs) {
      for (const section of Object.keys(cfg.libraryFolders)) {
        this.triggerBackgroundSync(cfg.id, section);
        await sleep(300); // stagger so we don't hammer uloz on startup
      }
    }
  }

  // -----------------------------------------------------------------------
  // Core sync logic
  // -----------------------------------------------------------------------

  async syncSection(storageId: number, section: string): Promise<void> {
    const key = `${storageId}:${section}`;
    if (this.activeSyncs.has(key)) {
      console.log(
        `[LibrarySync] "${section}" (storage ${storageId}) already syncing — skipped`,
      );
      return;
    }

    const cfg = getUlozStorageConfig(storageId);
    const folderSlug = cfg.libraryFolders[section];
    if (!folderSlug) {
      console.log(
        `[LibrarySync] No folder slug for section "${section}" on storage ${storageId}`,
      );
      return;
    }

    const displayName = sectionToDisplayName(section);
    this.activeSyncs.add(key);
    const syncGeneration = crypto.randomUUID();

    try {
      // Persist "scanning" state
      await prisma.librarySyncState.upsert({
        where: { id: key },
        create: {
          id: key,
          storageId,
          section,
          folderSlug,
          status: 'scanning',
          syncGeneration,
          startedAt: new Date(),
          lastTickAt: new Date(),
          totalIndexed: 0,
        },
        update: {
          folderSlug,
          status: 'scanning',
          syncGeneration,
          startedAt: new Date(),
          lastTickAt: new Date(),
          finishedAt: null,
          totalIndexed: 0,
          errorMessage: null,
        },
      });

      const uloz = getUlozService(storageId);
      let totalIndexed = 0;

      console.log(
        `[LibrarySync] ▶ section="${section}" storage=${storageId} folder=${folderSlug}`,
      );

      await this.crawlFolder({
        uloz,
        storageId,
        section,
        folderSlug,
        pathSegments: [displayName],
        parentId: null,
        parentFolderSlug: null,
        syncGeneration,
        syncStateId: key,
        onIndexed: (n) => {
          totalIndexed += n;
        },
      });

      // Prune stale entries (from previous sync generations)
      const pruned = await prisma.libraryContent.updateMany({
        where: {
          section,
          source: ContentSource.ULOZ,
          ulozStorageId: storageId,
          OR: [
            { syncGeneration: null },
            { syncGeneration: { not: syncGeneration } },
          ],
        },
        data: { isAvailable: false },
      });

      if (pruned.count > 0) {
        console.log(
          `[LibrarySync] Pruned ${pruned.count} stale entries for section "${section}"`,
        );
      }

      await prisma.librarySyncState.update({
        where: { id: key },
        data: {
          status: 'idle',
          finishedAt: new Date(),
          lastSyncAt: new Date(),
          lastTickAt: new Date(),
          totalIndexed,
        },
      });

      console.log(
        `[LibrarySync] ✅ section="${section}" storage=${storageId} indexed=${totalIndexed}`,
      );
    } catch (error: any) {
      console.error(
        `[LibrarySync] ❌ section="${section}" storage=${storageId}:`,
        error?.message ?? error,
      );
      await prisma.librarySyncState
        .update({
          where: { id: key },
          data: {
            status: 'error',
            errorMessage: String(error?.message ?? error).substring(0, 2000),
            finishedAt: new Date(),
            lastTickAt: new Date(),
          },
        })
        .catch(() => {
          /* ignore DB errors during error handling */
        });
    } finally {
      this.activeSyncs.delete(key);
    }
  }

  // -----------------------------------------------------------------------
  // Private crawl helpers
  // -----------------------------------------------------------------------

  private async crawlFolder(params: {
    uloz: any;
    storageId: number;
    section: string;
    folderSlug: string;
    pathSegments: string[];
    parentId: string | null;
    parentFolderSlug: string | null;
    syncGeneration: string;
    syncStateId: string;
    onIndexed: (n: number) => void;
  }): Promise<void> {
    const {
      uloz,
      storageId,
      section,
      folderSlug,
      pathSegments,
      parentId,
      syncGeneration,
      syncStateId,
      onIndexed,
    } = params;

    // Heartbeat so external observers can detect a stalled sync
    await prisma.librarySyncState
      .update({ where: { id: syncStateId }, data: { lastTickAt: new Date() } })
      .catch(() => {});

    let entries: any[];
    try {
      entries = await uloz.getFolderContents(
        `https://uloz.to/folder/${folderSlug}`,
      );
    } catch (err: any) {
      console.warn(
        `[LibrarySync] Cannot fetch folder ${folderSlug}: ${err?.message}`,
      );
      return;
    }

    if (!Array.isArray(entries) || entries.length === 0) return;

    const subfolders: Array<{
      entry: any;
      childPathSegments: string[];
      folderRecord: { id: string };
    }> = [];

    for (const entry of entries) {
      if (!entry?.slug) continue;

      const childPathSegments = [...pathSegments, entry.name];
      const filePath = childPathSegments.join('/');
      const slugPath = buildSlugPath(childPathSegments);

      if (entry.isFolder) {
        const folderRecord = await this.upsertFolderItem({
          ulozSlug: entry.slug,
          name: entry.name,
          section,
          storageId,
          filePath,
          slugPath,
          parentId,
          parentFolderSlug: folderSlug,
          syncGeneration,
        });
        onIndexed(1);
        subfolders.push({ entry, childPathSegments, folderRecord });
      } else {
        const ext = (entry.extension ?? '')
          .toString()
          .toLowerCase()
          .replace(/^\./, '');
        await this.upsertFileItem({
          ulozSlug: entry.slug,
          name: entry.name,
          section,
          storageId,
          filePath,
          slugPath,
          fileSize: entry.size ?? 0,
          extension: ext,
          contentType: entry.contentType ?? null,
          parentId,
          parentFolderSlug: folderSlug,
          syncGeneration,
        });
        onIndexed(1);
      }
    }

    // Recurse into subfolders after processing all files at this level
    for (const { entry, childPathSegments, folderRecord } of subfolders) {
      await sleep(150); // be gentle with the uloz.to API
      await this.crawlFolder({
        uloz,
        storageId,
        section,
        folderSlug: entry.slug,
        pathSegments: childPathSegments,
        parentId: folderRecord.id,
        parentFolderSlug: entry.slug,
        syncGeneration,
        syncStateId,
        onIndexed,
      });
    }
  }

  private async upsertFolderItem(params: {
    ulozSlug: string;
    name: string;
    section: string;
    storageId: number;
    filePath: string;
    slugPath: string;
    parentId: string | null;
    parentFolderSlug: string | null;
    syncGeneration: string;
  }): Promise<{ id: string }> {
    const {
      ulozSlug,
      name,
      section,
      storageId,
      filePath,
      slugPath,
      parentId,
      parentFolderSlug,
      syncGeneration,
    } = params;

    const slug = ulozSlug; // uloz.to folder slugs are globally unique

    const commonData = {
      title: name,
      filePath,
      slugPath,
      section,
      parentId,
      parentFolderSlug: parentFolderSlug ?? null,
      ulozSlug,
      ulozFolderSlug: ulozSlug,
      isFolder: true,
      source: ContentSource.ULOZ,
      ulozStorageId: storageId,
      isAvailable: true,
      syncGeneration,
      thumbnailUrl: null,
    };

    const existing = await prisma.libraryContent
      .findUnique({ where: { slug }, select: { id: true } })
      .catch(() => null);

    if (existing) {
      await prisma.libraryContent
        .update({ where: { slug }, data: commonData })
        .catch(() => {});
      return existing;
    }

    return prisma.libraryContent.create({
      data: { slug, ...commonData },
      select: { id: true },
    });
  }

  private async upsertFileItem(params: {
    ulozSlug: string;
    name: string;
    section: string;
    storageId: number;
    filePath: string;
    slugPath: string;
    fileSize: number;
    extension: string;
    contentType: string | null;
    parentId: string | null;
    parentFolderSlug: string | null;
    syncGeneration: string;
  }): Promise<void> {
    const {
      ulozSlug,
      name,
      section,
      storageId,
      filePath,
      slugPath,
      fileSize,
      extension,
      contentType,
      parentId,
      parentFolderSlug,
      syncGeneration,
    } = params;

    const slug = ulozSlug; // uloz.to file slugs are globally unique
    const detectedContentType = contentType || detectContentType(extension);
    const mimeType = detectMimeType(extension);

    const commonData = {
      title: name,
      filePath,
      slugPath,
      section,
      parentId,
      parentFolderSlug: parentFolderSlug ?? null,
      ulozSlug,
      ulozFolderSlug: parentFolderSlug ?? null,
      isFolder: false,
      source: ContentSource.ULOZ,
      ulozStorageId: storageId,
      fileSize: fileSize > 0 ? BigInt(Math.round(fileSize)) : null,
      extension: extension || null,
      contentType: detectedContentType,
      mimeType: mimeType ?? null,
      isAvailable: true,
      syncGeneration,
      thumbnailUrl: null,
      videoPreviewUrl: null,
    };

    const existing = await prisma.libraryContent
      .findUnique({ where: { slug }, select: { id: true } })
      .catch(() => null);

    if (existing) {
      await prisma.libraryContent
        .update({ where: { slug }, data: commonData })
        .catch(() => {});
    } else {
      await prisma.libraryContent
        .create({ data: { slug, ...commonData } })
        .catch(() => {});
    }
  }
}

export const librarySyncService = new LibrarySyncService();
