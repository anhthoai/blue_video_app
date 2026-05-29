import { Router } from 'express';
import { authenticateToken } from '../middleware/auth';
import { uploadMiddleware } from '../config/storage';
import { DatingController } from '../controllers/datingController';

const router = Router();
const dating = new DatingController();

// All dating routes require authentication
router.use(authenticateToken);

/** GET /api/v1/dating/explore – Nearby / Online users grid */
router.get('/explore', dating.getExploreUsers);

/** GET /api/v1/dating/upgrade/status – Current dating plan status */
router.get('/upgrade/status', dating.getUpgradeStatus);

/** GET /api/v1/dating/upgrade/plans – Dating VIP/Unlimited plan catalog */
router.get('/upgrade/plans', dating.getUpgradePlans);

/** POST /api/v1/dating/upgrade/purchase – Purchase dating upgrade with coins */
router.post('/upgrade/purchase', dating.purchaseUpgrade);

/** GET /api/v1/dating/profile/me – Own dating profile */
/** GET /api/v1/dating/profile/:userId – Another user's dating profile */
router.get('/profile/:userId', dating.getDatingProfile);

/** PUT /api/v1/dating/profile – Update own dating profile */
router.put('/profile', dating.updateDatingProfile);

/** POST /api/v1/dating/match/:userId – Like / dislike a user */
router.post('/match/:userId', dating.matchAction);

/** GET /api/v1/dating/matches – Mutual matches (Meet tab) */
router.get('/matches', dating.getMutualMatches);

/** GET /api/v1/dating/matches/suggestions – Daily smart suggestions for Meet tab */
router.get('/matches/suggestions', dating.getSuggestedMatches);

/** POST /api/v1/dating/public-photos/upload – Upload additional public dating avatar */
router.post('/public-photos/upload', uploadMiddleware.single('photo'), dating.uploadPublicPhoto);

/** DELETE /api/v1/dating/public-photos/:index – Delete additional public dating avatar */
router.delete('/public-photos/:index', dating.deletePublicPhoto);

/** POST /api/v1/dating/private-album/upload – Upload a private photo */
router.post(
  '/private-album/upload',
  uploadMiddleware.single('photo'),
  dating.uploadPrivatePhoto,
);

/** DELETE /api/v1/dating/private-album/:index – Delete private photo by array index */
router.delete('/private-album/:index', dating.deletePrivatePhoto);

/** POST /api/v1/dating/private-album/request/:userId – Request access to a user's album */
router.post('/private-album/request/:userId', dating.requestPrivateAlbumAccess);

/** PUT /api/v1/dating/private-album/respond/:requestId – Accept / deny an album access request */
router.put('/private-album/respond/:requestId', dating.respondPrivateAlbumAccess);

/** GET /api/v1/dating/private-album/requests – Pending access requests (received / sent) */
router.get('/private-album/requests', dating.getPrivateAlbumAccessRequests);

export default router;
