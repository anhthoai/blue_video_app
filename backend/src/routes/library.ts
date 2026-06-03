import { Router } from 'express';

import * as libraryController from '../controllers/libraryController';
import * as librarySyncController from '../controllers/librarySyncController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Admin/debug: read-only sync state per visited folder
router.get('/sync/status', librarySyncController.getSyncStatus);

// Library browsing
router.get('/sections', libraryController.listLibrarySections);
router.get('/feed/videos', libraryController.listLibraryVideoFeed);
router.get('/item/:id', libraryController.getLibraryItem);
router.post('/item/:id/download', authenticateToken, libraryController.authorizeLibraryItemDownload);
router.get('/item/:id/stream', libraryController.streamLibraryItem);
router.head('/item/:id/stream', libraryController.streamLibraryItem);
router.get('/:section', libraryController.listLibraryItems);

export default router;

