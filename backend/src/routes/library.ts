import { Router } from 'express';

import * as libraryController from '../controllers/libraryController';
import * as librarySyncController from '../controllers/librarySyncController';

const router = Router();

// Sync management
router.get('/sync/status', librarySyncController.getSyncStatus);
router.post('/sync', librarySyncController.triggerFullSync);
router.post('/sync/:section', librarySyncController.triggerSectionSync);

// Library browsing
router.get('/sections', libraryController.listLibrarySections);
router.get('/feed/videos', libraryController.listLibraryVideoFeed);
router.get('/item/:id', libraryController.getLibraryItem);
router.get('/item/:id/stream', libraryController.streamLibraryItem);
router.head('/item/:id/stream', libraryController.streamLibraryItem);
router.get('/:section', libraryController.listLibraryItems);

export default router;

