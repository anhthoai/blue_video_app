import { Router } from 'express';

import * as libraryController from '../controllers/libraryController';

const router = Router();

router.get('/sections', libraryController.listLibrarySections);
router.get('/item/:id', libraryController.getLibraryItem);
router.get('/:section', libraryController.listLibraryItems);

export default router;

