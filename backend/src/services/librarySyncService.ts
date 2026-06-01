import crypto from 'crypto';
import { ContentSource, Prisma } from '@prisma/client';
import prisma from '../lib/prisma';
import {
  getUlozService,
  getUlozStorageConfig,
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

export function sectionToDisplayName(section: string): string {
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
  /** Keys of folder syncs currently running, keyed by `${storageId}:${folderSlug}`. */
  private readonly activeSyncs = new Set<string>();

  // -----------------------------------------------------------------------
  // Thumbnail CDN URL
  // -----------------------------------------------------------------------

  /**
   * Builds a thumbnail URL using the CDN proxy pattern from myindex:
   *   {proxyCdnUrl}__ulozthumb__/small/{fileSlug}
   * e.g. https://ulcdn.onlybl.com/0:/__ulozthumb__/small/6qbjqxwVTNHf
   * The /small/ route always returns a static JPEG (works for all file types
   * including webm). Returns null if no CDN URL is configured for the storage.
   */
  buildThumbnailUrl(storageId: number, fileSlug: string): string | null {
    const cfg = getUlozStorageConfig(storageId);
    if (!cfg.proxyCdnUrl) return null;
    const base = cfg.proxyCdnUrl.endsWith('/')
      ? cfg.proxyCdnUrl
      : `${cfg.proxyCdnUrl}/`;
    return `${base}__ulozthumb__/small/${fileSlug}`;
  }

  /**
   * Returns true if a sync is currently running for `${storageId}:${folderSlug}`.
   * Used by the library controller to include a `syncInProgress` flag in
   * responses so Flutter can show a loading indicator and poll for new items.
   */
  isSyncActive(storageId: number, folderSlug: string): boolean {
    return this.activeSyncs.has(`${storageId}:${folderSlug}`);
  }

  // -----------------------------------------------------------------------
  // Browse-triggered sync (main public entry point)
  // -----------------------------------------------------------------------

  /**
   * Called on every browse request for a folder. Behaviour:
   *
   *  - First visit (no sync record for this folderSlug): blocks until the
   *    folder's immediate children are upserted to the DB.
   *  - Stale (last sync > ttlMs ago): returns immediately (SWR), re-syncs in
   *    the background so the next browse gets fresher data.
   *  - Fresh (last sync < ttlMs ago): no-op.
   *
   * @param parentId  DB id of the folder whose children we are showing, or null
   *                  when showing the section root level.
   */
  async syncFolderLevelIfNeeded(
    storageId: number,
    section: string,
    folderSlug: string,
    parentId: string | null,
    pathSegments: string[],
    ttlMs = 60 * 60 * 1000, // 1 hour default TTL
  ): Promise<void> {
    const key = `${storageId}:${folderSlug}`;
    // Already syncing this exact folder — skip to avoid duplicate work
    if (this.activeSyncs.has(key)) return;

    const syncState = await prisma.librarySyncState
      .findUnique({ where: { id: key } })
      .catch(() => null);

    const lastSyncAt = syncState?.lastSyncAt ?? null;
    const isFresh =
      lastSyncAt !== null && Date.now() - lastSyncAt.getTime() < ttlMs;

    if (isFresh) return; // cached data is fresh enough

    if (lastSyncAt === null) {
      // First visit — block only until the FIRST PAGE is committed to DB.
      // Large folders (10 000+ files) should not block the HTTP request for
      // their entire sync duration; remaining pages continue in background.
      await new Promise<void>((resolve, reject) => {
        let firstPageSignaled = false;
        this.syncFolderLevel(
          storageId,
          section,
          folderSlug,
          parentId,
          pathSegments,
          () => {
            firstPageSignaled = true;
            resolve();
          },
        ).catch((err) => {
          if (!firstPageSignaled) {
            reject(err); // error before any data was ready
          } else {
            console.error(
              `[LibrarySync] Background pages error for "${folderSlug}":`,
              err?.message ?? err,
            );
          }
        });
      });
    } else {
      // Stale-while-revalidate: serve cached data now, refresh in background
      this.syncFolderLevel(storageId, section, folderSlug, parentId, pathSegments).catch(
        (err) =>
          console.error(
            `[LibrarySync] Background re-sync error for folder "${folderSlug}":`,
            err?.message ?? err,
          ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Status API (kept for the optional admin/debug endpoint)
  // -----------------------------------------------------------------------

  /** Returns sync state for every folder slug that has been visited. */
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

  // -----------------------------------------------------------------------
  // Core single-level sync (private)
  // -----------------------------------------------------------------------

  /**
   * Fetches ONE level of a uloz.to folder page-by-page and upserts to DB.
   * Never recurses — deeper levels are synced lazily when the user navigates.
   *
   * @param onFirstPageReady  Optional callback fired after the first page
   *   (subfolders + first 100 files) has been committed to the DB.  Used by
   *   `syncFolderLevelIfNeeded` to unblock the HTTP request early so the user
   *   sees initial data immediately while remaining pages load in background.
   */
  private async syncFolderLevel(
    storageId: number,
    section: string,
    folderSlug: string,
    parentId: string | null,
    pathSegments: string[],
    onFirstPageReady?: () => void,
  ): Promise<void> {
    const key = `${storageId}:${folderSlug}`;
    if (this.activeSyncs.has(key)) {
      onFirstPageReady?.(); // already running — unblock caller immediately
      return;
    }
    this.activeSyncs.add(key);
    const syncGeneration = crypto.randomUUID();

    // Safety: always call onFirstPageReady exactly once so the Promise in
    // syncFolderLevelIfNeeded never hangs.
    let firstPageSignaled = false;
    const signalFirstPage = () => {
      if (!firstPageSignaled) {
        firstPageSignaled = true;
        onFirstPageReady?.();
      }
    };

    console.log(
      `[LibrarySync] ▶ section="${section}" slug="${folderSlug}" parentId=${parentId ?? 'root'}`,
    );

    try {
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
      const folderUrl = `https://uloz.to/folder/${folderSlug}`;
      const FILE_PER_PAGE = 100;
      let totalIndexed = 0;
      let filePage = 1;
      const childFoldersToSync: Array<{
        slug: string;
        parentId: string;
        pathSegments: string[];
      }> = [];
      const enqueuedChildSlugs = new Set<string>();
      // Track all file slugs seen across pages to detect when the API starts
      // repeating items (malformed declared total + capped page size causes loops).
      const allSeenFileSlugs = new Set<string>();

      // eslint-disable-next-line no-constant-condition
      while (true) {
        let page: { entries: any[]; hasMore: boolean };
        try {
          page = await uloz.getFolderContentsPage(folderUrl, filePage, FILE_PER_PAGE);
        } catch (err: any) {
          console.warn(
            `[LibrarySync] Cannot fetch page ${filePage} of "${folderSlug}": ${err?.message}`,
          );
          signalFirstPage(); // unblock caller even when no data could be fetched
          break;
        }

        // Separate folders (sequential, few items) from files (batched, many items)
        const folderEntries = page.entries.filter((e) => e?.slug && e.isFolder);
        const fileEntries = page.entries.filter((e) => e?.slug && !e.isFolder);

        // --- Folders: sequential upsert (maintains parentId chain) ---
        for (const entry of folderEntries) {
          const childPathSegments = [...pathSegments, entry.name];
          const childFolder = await this.upsertFolderItem({
            ulozSlug: entry.slug,
            name: entry.name,
            section,
            storageId,
            filePath: childPathSegments.join('/'),
            slugPath: buildSlugPath(childPathSegments),
            parentId,
            parentFolderSlug: folderSlug,
            syncGeneration,
          });
          if (!enqueuedChildSlugs.has(entry.slug)) {
            enqueuedChildSlugs.add(entry.slug);
            childFoldersToSync.push({
              slug: entry.slug,
              parentId: childFolder.id,
              pathSegments: childPathSegments,
            });
          }
          totalIndexed++;
        }

        // --- Files: batch upsert (2 DB calls instead of N×2) ---
        if (fileEntries.length > 0) {
          const fileRecords: Prisma.LibraryContentCreateManyInput[] = fileEntries.map(
            (entry) => {
              const ext = (entry.extension ?? '')
                .toString()
                .toLowerCase()
                .replace(/^\./, '');
              const childSegments = [...pathSegments, entry.name];
              const thumbnailUrl =
                this.buildThumbnailUrl(storageId, entry.slug) ||
                (entry.previewSmallImage?.trim()) ||
                null;
              return {
                slug: entry.slug,
                title: entry.name,
                filePath: childSegments.join('/'),
                slugPath: buildSlugPath(childSegments),
                section,
                parentId: parentId ?? null,
                parentFolderSlug: folderSlug,
                ulozSlug: entry.slug,
                ulozFolderSlug: folderSlug,
                isFolder: false,
                source: ContentSource.ULOZ,
                ulozStorageId: storageId,
                fileSize:
                  (entry.size ?? 0) > 0
                    ? BigInt(Math.round(Number(entry.size ?? 0)))
                    : null,
                extension: ext || null,
                contentType: entry.contentType || detectContentType(ext),
                mimeType: detectMimeType(ext) ?? null,
                isAvailable: true,
                syncGeneration,
                thumbnailUrl,
                videoPreviewUrl: null,
              };
            },
          );

          const seenSlugs = fileRecords.map((r) => r.slug as string);

          // Detect API loop: if every slug on this page was already seen on a
          // previous page, the API is repeating items. Stop to prevent infinite
          // fetching (happens with wrong `declared` + per-page API caps).
          const newSlugCount = seenSlugs.filter((s) => !allSeenFileSlugs.has(s)).length;
          if (newSlugCount === 0) {
            console.log(
              `[LibrarySync] Page ${filePage}: all ${seenSlugs.length} file slugs already seen on previous pages — stopping loop`,
            );
            signalFirstPage();
            break;
          }
          seenSlugs.forEach((s) => allSeenFileSlugs.add(s));

          // 1. Stamp syncGeneration on items already in DB (needed for pruning)
          await prisma.libraryContent
            .updateMany({
              where: { slug: { in: seenSlugs } },
              data: { syncGeneration, isAvailable: true },
            })
            .catch(() => {});

          // 2. Insert items not yet in DB (skip those updated above)
          await prisma.libraryContent
            .createMany({ data: fileRecords, skipDuplicates: true })
            .catch(() => {});

          totalIndexed += fileEntries.length;
        }

        // After the first page is committed, unblock the caller so the user
        // sees initial data immediately while remaining pages load in background.
        signalFirstPage();

        if (!page.hasMore) break;

        filePage++;
        // Periodic progress update so the sync-state record stays fresh
        await prisma.librarySyncState
          .update({ where: { id: key }, data: { lastTickAt: new Date(), totalIndexed } })
          .catch(() => { /* non-critical */ });
      }

      // Prune direct children that were removed from this folder since the last sync
      const pruned = await prisma.libraryContent.updateMany({
        where: {
          section,
          source: ContentSource.ULOZ,
          ulozStorageId: storageId,
          parentId, // scope to direct children only
          OR: [
            { syncGeneration: null },
            { syncGeneration: { not: syncGeneration } },
          ],
        },
        data: { isAvailable: false },
      });

      if (pruned.count > 0) {
        console.log(
          `[LibrarySync] Pruned ${pruned.count} removed items from folder "${folderSlug}"`,
        );
      }

      await prisma.librarySyncState.update({
        where: { id: key },
        data: {
          status: 'idle',
          lastSyncAt: new Date(),
          finishedAt: new Date(),
          lastTickAt: new Date(),
          totalIndexed,
        },
      });

      console.log(
        `[LibrarySync] ✅ section="${section}" slug="${folderSlug}" pages=${filePage} indexed=${totalIndexed}`,
      );

      // Recursive background sync: after this folder level is done, continue
      // syncing all discovered child folders in the background. Keep this
      // detached so first-page browse responses remain fast.
      if (childFoldersToSync.length > 0) {
        void (async () => {
          for (const child of childFoldersToSync) {
            try {
              await this.syncFolderLevel(
                storageId,
                section,
                child.slug,
                child.parentId,
                child.pathSegments,
              );
            } catch (childError: any) {
              console.error(
                `[LibrarySync] Child recursive sync failed for "${child.slug}":`,
                childError?.message ?? childError,
              );
            }
          }
        })();
      }
    } catch (error: any) {
      signalFirstPage(); // ensure caller is always unblocked even on error
      console.error(
        `[LibrarySync] ❌ folder "${folderSlug}":`,
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
  // Upsert helpers
  // -----------------------------------------------------------------------

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

  // -----------------------------------------------------------------------
  // On-demand real-time folder fetch
  // -----------------------------------------------------------------------

  /**
   * Ensures the DB contains at least `neededFolderCount` subfolder rows for
   * the given parent folder. When the user scrolls to a page of subfolders
   * that the background sync hasn't committed yet, this fetches the missing
   * uloz.to folder pages so the DB query returns real data.
   */
  async onDemandEnsureFolders(
    storageId: number,
    section: string,
    folderSlug: string,
    parentId: string | null,
    pathSegments: string[],
    neededFolderCount: number,
  ): Promise<void> {
    let currentCount = await prisma.libraryContent.count({
      where: { parentId, section, isAvailable: true, isFolder: true },
    });
    if (currentCount >= neededFolderCount) return;

    const ULOZ_PAGE_SIZE = 100;
    let folderPage = Math.max(1, Math.floor(currentCount / ULOZ_PAGE_SIZE) + 1);

    const uloz = getUlozService(storageId);
    const folderUrl = `https://uloz.to/folder/${folderSlug}`;
    const syncGeneration = Date.now().toString();

    const MAX_PAGES = 20;
    let pagesScanned = 0;
    const seenSlugsThisSession = new Set<string>();

    while (currentCount < neededFolderCount && pagesScanned < MAX_PAGES) {
      const { items: rawFolders, hasMore } = await uloz.getFolderFoldersPage(
        folderUrl,
        folderPage,
        ULOZ_PAGE_SIZE,
      );
      pagesScanned++;

      if (rawFolders.length === 0) break;

      const pageSlugs = rawFolders.map((f) => f.slug);
      const genuinelyNew = pageSlugs.filter((s) => !seenSlugsThisSession.has(s));
      if (genuinelyNew.length === 0) break;
      pageSlugs.forEach((s) => seenSlugsThisSession.add(s));

      // Batch insert — createMany with skipDuplicates is one DB round-trip and
      // only increments currentCount for records that were actually inserted.
      const records: Prisma.LibraryContentCreateManyInput[] = rawFolders.map((folder) => {
        const childSegs = [...pathSegments, folder.name];
        return {
          slug: folder.slug,
          title: folder.name,
          filePath: childSegs.join('/'),
          slugPath: buildSlugPath(childSegs),
          section,
          parentId: parentId ?? null,
          parentFolderSlug: folderSlug,
          ulozSlug: folder.slug,
          ulozFolderSlug: folder.slug,
          isFolder: true,
          source: ContentSource.ULOZ,
          ulozStorageId: storageId,
          isAvailable: true,
          syncGeneration,
          thumbnailUrl: null,
        };
      });

      if (records.length > 0) {
        const result = await prisma.libraryContent.createMany({
          data: records,
          skipDuplicates: true,
        });
        currentCount += result.count; // Only newly inserted records
      }

      if (!hasMore) break;
      folderPage++;
    }
  }

  // -----------------------------------------------------------------------
  // On-demand real-time file fetch
  // -----------------------------------------------------------------------

  /**
   * Ensures the DB contains at least `neededFileCount` file rows for the given
   * parent folder. When the user scrolls to a page the background sync hasn't
   * reached yet, this method fetches the missing uloz.to pages directly from
   * uloz.to and writes them to DB in a single bulk insert per page.
   *
   * Uses createMany + skipDuplicates (one DB round-trip per uloz page) instead
   * of sequential per-item upserts, keeping latency under ~500 ms even for
   * folders with 100+ files.
   */
  async onDemandEnsureFiles(
    storageId: number,
    section: string,
    folderSlug: string,
    parentId: string | null,
    pathSegments: string[],
    neededFileCount: number,
  ): Promise<void> {
    let currentCount = await prisma.libraryContent.count({
      where: { parentId, section, isAvailable: true, isFolder: false },
    });
    if (currentCount >= neededFileCount) return;

    // uloz file-list API caps at 50 items per request; use offset-based pagination.
    const ULOZ_PAGE_SIZE = 50;
    let filePage = Math.max(1, Math.floor(currentCount / ULOZ_PAGE_SIZE) + 1);

    const uloz = getUlozService(storageId);
    const folderUrl = `https://uloz.to/folder/${folderSlug}`;
    const syncGeneration = Date.now().toString();

    const MAX_PAGES = 30;
    let pagesScanned = 0;
    // Detect when the API repeats the same items across pages.
    const seenSlugsThisSession = new Set<string>();

    console.log(`[onDemandEnsureFiles] folderSlug=${folderSlug} currentCount=${currentCount} neededFileCount=${neededFileCount} startFilePage=${filePage}`);

    while (currentCount < neededFileCount && pagesScanned < MAX_PAGES) {
      const page = await uloz.getFilesPage(folderUrl, filePage);
      pagesScanned++;

      console.log(`[onDemandEnsureFiles] page ${filePage}: entries=${page.entries.length} hasMore=${page.hasMore} currentCount=${currentCount}`);

      // Empty page = no more items on uloz.to, stop.
      if (page.entries.length === 0) { console.log(`[onDemandEnsureFiles] STOP: empty page`); break; }

      // Detect API loop: if ALL slugs on this page were already fetched in this
      // on-demand session, the API is repeating items — no new data possible.
      const pageSlugs = page.entries.map((e) => e.slug as string);
      const genuinelyNew = pageSlugs.filter((s) => !seenSlugsThisSession.has(s));
      if (genuinelyNew.length === 0) { console.log(`[onDemandEnsureFiles] STOP: all slugs repeated`); break; }
      pageSlugs.forEach((s) => seenSlugsThisSession.add(s));

      const records: Prisma.LibraryContentCreateManyInput[] = page.entries.map((entry) => {
          const ext = (entry.extension ?? '').toString().toLowerCase().replace(/^\./, '');
          const childSegments = [...pathSegments, entry.name];
          const thumbnailUrl =
            this.buildThumbnailUrl(storageId, entry.slug) ||
            (entry.previewSmallImage?.trim()) ||
            null;
          return {
            slug: entry.slug,
            title: entry.name,
            filePath: childSegments.join('/'),
            slugPath: buildSlugPath(childSegments),
            section,
            parentId: parentId ?? null,
            parentFolderSlug: folderSlug,
            ulozSlug: entry.slug,
            ulozFolderSlug: folderSlug,
            isFolder: false,
            source: ContentSource.ULOZ,
            ulozStorageId: storageId,
            fileSize:
              (entry.size ?? 0) > 0
                ? BigInt(Math.round(Number(entry.size ?? 0)))
                : null,
            extension: ext || null,
            contentType: entry.contentType || detectContentType(ext),
            mimeType: detectMimeType(ext) ?? null,
            isAvailable: true,
            syncGeneration,
            thumbnailUrl,
            videoPreviewUrl: null,
          };
        });

      if (records.length > 0) {
        const result = await prisma.libraryContent.createMany({
          data: records,
          skipDuplicates: true,
        });
        currentCount += result.count;
      }

      // No more pages from uloz.to API (empty-page check above handles the
      // real stop; this is a secondary guard for edge cases).
      if (!page.hasMore) break;
      filePage++;
    }
  }
}

export const librarySyncService = new LibrarySyncService();
