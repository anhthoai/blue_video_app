import { Request, Response } from 'express';
import { librarySyncService } from '../services/librarySyncService';

/**
 * GET /api/v1/library/sync/status
 * Returns the sync state for every folder that has been visited (admin/debug).
 */
export async function getSyncStatus(_req: Request, res: Response): Promise<void> {
  try {
    const states = await librarySyncService.getAllSyncStates();
    res.json({
      success: true,
      data: states,
    });
  } catch (error: any) {
    console.error('[LibrarySync] getSyncStatus error:', error);
    res.status(500).json({ success: false, message: 'Failed to get sync status' });
  }
}
