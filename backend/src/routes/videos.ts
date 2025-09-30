import { Router } from 'express';
import { VideoController } from '../controllers/videoController';
import { authenticateToken, optionalAuth } from '../middleware/auth';
import { uploadMiddleware, handleUploadError } from '../config/storage';

const router = Router();
const videoController = new VideoController();

/**
 * @route POST /api/v1/videos/upload
 * @desc Upload a new video
 * @access Private
 */
router.post(
  '/upload',
  authenticateToken,
  uploadMiddleware.single('video'),
  handleUploadError,
  videoController.uploadVideo
);

/**
 * @route GET /api/v1/videos/:id
 * @desc Get video by ID
 * @access Public
 */
router.get('/:id', optionalAuth, videoController.getVideo);

/**
 * @route GET /api/v1/videos
 * @desc Get videos feed
 * @access Public
 */
router.get('/', optionalAuth, videoController.getFeed);

/**
 * @route GET /api/v1/videos/trending
 * @desc Get trending videos
 * @access Public
 */
router.get('/trending', optionalAuth, videoController.getTrending);

/**
 * @route GET /api/v1/videos/search
 * @desc Search videos
 * @access Public
 */
router.get('/search', optionalAuth, videoController.searchVideos);

/**
 * @route GET /api/v1/videos/user/:userId
 * @desc Get user's videos
 * @access Public
 */
router.get('/user/:userId', optionalAuth, videoController.getUserVideos);

/**
 * @route PUT /api/v1/videos/:id
 * @desc Update video
 * @access Private
 */
router.put('/:id', authenticateToken, videoController.updateVideo);

/**
 * @route DELETE /api/v1/videos/:id
 * @desc Delete video
 * @access Private
 */
router.delete('/:id', authenticateToken, videoController.deleteVideo);

/**
 * @route GET /api/v1/videos/stats
 * @desc Get video statistics
 * @access Public
 */
router.get('/stats', videoController.getVideoStats);

export default router;
