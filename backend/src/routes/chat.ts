import { Router } from 'express';
import { ChatController } from '../controllers/chatController';
import { authenticateToken } from '../middleware/auth';

const router = Router();
const chatController = new ChatController();

/**
 * @route POST /api/v1/chat/rooms
 * @desc Create a new chat room
 * @access Private
 */
router.post('/rooms', authenticateToken, chatController.createRoom);

/**
 * @route GET /api/v1/chat/rooms
 * @desc Get user's chat rooms
 * @access Private
 */
router.get('/rooms', authenticateToken, chatController.getRooms);

/**
 * @route GET /api/v1/chat/rooms/:roomId
 * @desc Get room by ID
 * @access Private
 */
router.get('/rooms/:roomId', authenticateToken, chatController.getRoom);

/**
 * @route GET /api/v1/chat/rooms/:roomId/messages
 * @desc Get room messages
 * @access Private
 */
router.get('/rooms/:roomId/messages', authenticateToken, chatController.getMessages);

/**
 * @route POST /api/v1/chat/rooms/:roomId/messages
 * @desc Send message
 * @access Private
 */
router.post('/rooms/:roomId/messages', authenticateToken, chatController.sendMessage);

/**
 * @route PUT /api/v1/chat/messages/:messageId
 * @desc Edit message
 * @access Private
 */
router.put('/messages/:messageId', authenticateToken, chatController.editMessage);

/**
 * @route DELETE /api/v1/chat/messages/:messageId
 * @desc Delete message
 * @access Private
 */
router.delete('/messages/:messageId', authenticateToken, chatController.deleteMessage);

/**
 * @route POST /api/v1/chat/rooms/:roomId/participants
 * @desc Add participant to room
 * @access Private
 */
router.post('/rooms/:roomId/participants', authenticateToken, chatController.addParticipant);

/**
 * @route DELETE /api/v1/chat/rooms/:roomId/participants/:userId
 * @desc Remove participant from room
 * @access Private
 */
router.delete('/rooms/:roomId/participants/:userId', authenticateToken, chatController.removeParticipant);

/**
 * @route DELETE /api/v1/chat/rooms/:roomId/leave
 * @desc Leave room
 * @access Private
 */
router.delete('/rooms/:roomId/leave', authenticateToken, chatController.leaveRoom);

export default router;
