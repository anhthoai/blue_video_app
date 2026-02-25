import { Router } from 'express';

import * as libraryController from '../controllers/libraryController';

const router = Router();

router.get('/sections', libraryController.listLibrarySections);
router.get('/item/:id', libraryController.getLibraryItem);
router.get('/item/:id/stream', libraryController.streamLibraryItem);
router.head('/item/:id/stream', libraryController.streamLibraryItem);
router.get('/:section', libraryController.listLibraryItems);

export default router;

