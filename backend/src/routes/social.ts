import { Router } from 'express';
import { SocialController } from '../controllers/socialController';
import { authenticateToken, optionalAuth } from '../middleware/auth';

const router = Router();
const socialController = new SocialController();

/**
 * @route POST /api/v1/social/:contentType/:contentId/like
 * @desc Like content (video, post, comment)
 * @access Private
 */
router.post('/:contentType/:contentId/like', authenticateToken, socialController.likeContent);

/**
 * @route GET /api/v1/social/:contentType/:contentId/likes
 * @desc Get content likes
 * @access Public
 */
router.get('/:contentType/:contentId/likes', socialController.getContentLikes);

/**
 * @route POST /api/v1/social/:contentType/:contentId/comments
 * @desc Create comment
 * @access Private
 */
router.post('/:contentType/:contentId/comments', authenticateToken, socialController.createComment);

/**
 * @route GET /api/v1/social/:contentType/:contentId/comments
 * @desc Get content comments
 * @access Public
 */
router.get('/:contentType/:contentId/comments', optionalAuth, socialController.getContentComments);

/**
 * @route GET /api/v1/social/comments/:commentId/replies
 * @desc Get comment replies
 * @access Public
 */
router.get('/comments/:commentId/replies', optionalAuth, socialController.getCommentReplies);

/**
 * @route PUT /api/v1/social/comments/:commentId
 * @desc Update comment
 * @access Private
 */
router.put('/comments/:commentId', authenticateToken, socialController.updateComment);

/**
 * @route DELETE /api/v1/social/comments/:commentId
 * @desc Delete comment
 * @access Private
 */
router.delete('/comments/:commentId', authenticateToken, socialController.deleteComment);

/**
 * @route POST /api/v1/social/:contentType/:contentId/share
 * @desc Share content
 * @access Private
 */
router.post('/:contentType/:contentId/share', authenticateToken, socialController.shareContent);

/**
 * @route GET /api/v1/social/liked/:contentType
 * @desc Get user's liked content
 * @access Private
 */
router.get('/liked/:contentType', authenticateToken, socialController.getUserLikedContent);

export default router;
