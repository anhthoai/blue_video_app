import { Request, Response } from 'express';
import { librarySyncService } from '../services/librarySyncService';
import { listUlozStorageConfigs } from '../services/ulozRegistry';

/**
 * GET /api/v1/library/sync/status
 * Returns the sync state for every configured section.
 */
export async function getSyncStatus(_req: Request, res: Response): Promise<void> {
  try {
    const states = await librarySyncService.getAllSyncStates();

    // Also include configured sections that have no state record yet
    const configs = listUlozStorageConfigs();
    const knownKeys = new Set(states.map((s) => s.id));

    const pending: typeof states = [];
    for (const cfg of configs) {
      for (const section of Object.keys(cfg.libraryFolders)) {
        const key = `${cfg.id}:${section}`;
        if (!knownKeys.has(key)) {
          pending.push({
            id: key,
            storageId: cfg.id,
            section,
            status: 'idle',
            lastSyncAt: null,
            startedAt: null,
            finishedAt: null,
            lastTickAt: null,
            totalIndexed: 0,
            errorMessage: null,
          });
        }
      }
    }

    res.json({
      success: true,
      data: [...states, ...pending],
    });
  } catch (error: any) {
    console.error('[LibrarySync] getSyncStatus error:', error);
    res.status(500).json({ success: false, message: 'Failed to get sync status' });
  }
}

/**
 * POST /api/v1/library/sync
 * Triggers a background re-sync for every configured section.
 */
export async function triggerFullSync(_req: Request, res: Response): Promise<void> {
  try {
    librarySyncService.triggerAllSections().catch((err) =>
      console.error('[LibrarySync] triggerAllSections error:', err),
    );
    res.json({ success: true, message: 'Full sync triggered' });
  } catch (error: any) {
    console.error('[LibrarySync] triggerFullSync error:', error);
    res.status(500).json({ success: false, message: 'Failed to trigger sync' });
  }
}

/**
 * POST /api/v1/library/sync/:section
 * Triggers a background re-sync for a single section.
 * Accepts optional `?storageId=N` query param (defaults to 1).
 */
export async function triggerSectionSync(req: Request, res: Response): Promise<void> {
  try {
    const rawSection = (req.params['section'] || '').trim().toLowerCase();
    if (!rawSection) {
      res.status(400).json({ success: false, message: 'Section is required' });
      return;
    }

    const storageId = Math.max(
      1,
      parseInt(String(req.query['storageId'] ?? '1'), 10) || 1,
    );

    const cfg = listUlozStorageConfigs().find((c) => c.id === storageId);
    if (!cfg) {
      res.status(404).json({ success: false, message: `Storage ${storageId} not configured` });
      return;
    }

    if (!cfg.libraryFolders[rawSection]) {
      res.status(404).json({
        success: false,
        message: `Section "${rawSection}" is not configured for storage ${storageId}`,
      });
      return;
    }

    librarySyncService.triggerBackgroundSync(storageId, rawSection);

    res.json({
      success: true,
      message: `Sync triggered for section "${rawSection}" (storage ${storageId})`,
    });
  } catch (error: any) {
    console.error('[LibrarySync] triggerSectionSync error:', error);
    res.status(500).json({ success: false, message: 'Failed to trigger section sync' });
  }
}
