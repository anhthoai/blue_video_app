import { Request, Response } from 'express';
import { pool } from '../config/database';
import { AuthRequest } from '../middleware/auth';

export interface ChatRoom {
  id: string;
  name?: string;
  type: 'private' | 'group';
  created_by: string;
  created_at: Date;
  updated_at: Date;
}

export interface ChatMessage {
  id: string;
  room_id: string;
  user_id: string;
  content: string;
  message_type: 'text' | 'image' | 'video' | 'file';
  file_url?: string;
  is_edited: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface ChatRoomWithParticipants extends ChatRoom {
  participants: Array<{
    id: string;
    username: string;
    avatar_url?: string;
    joined_at: Date;
  }>;
  last_message?: ChatMessage;
  unread_count: number;
}

export class ChatController {
  /**
   * Create a new chat room
   */
  createRoom = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { name, type = 'private', participantIds } = req.body;

      if (type === 'group' && !name) {
        res.status(400).json({
          success: false,
          message: 'Room name is required for group chats',
        });
        return;
      }

      if (type === 'private' && (!participantIds || participantIds.length !== 1)) {
        res.status(400).json({
          success: false,
          message: 'Private chat requires exactly one participant',
        });
        return;
      }

      if (type === 'group' && (!participantIds || participantIds.length < 1)) {
        res.status(400).json({
          success: false,
          message: 'Group chat requires at least one participant',
        });
        return;
      }

      // Check if private chat already exists
      if (type === 'private') {
        const existingRoom = await pool.query(`
          SELECT cr.id FROM chat_rooms cr
          INNER JOIN chat_room_participants crp1 ON cr.id = crp1.room_id
          INNER JOIN chat_room_participants crp2 ON cr.id = crp2.room_id
          WHERE cr.type = 'private'
            AND crp1.user_id = $1 AND crp2.user_id = $2
            AND crp1.user_id != crp2.user_id
        `, [req.user!.id, participantIds[0]]);

        if (existingRoom.rows.length > 0) {
          res.status(409).json({
            success: false,
            message: 'Private chat already exists',
            data: { roomId: existingRoom.rows[0].id },
          });
          return;
        }
      }

      // Create chat room
      const roomQuery = `
        INSERT INTO chat_rooms (name, type, created_by)
        VALUES ($1, $2, $3)
        RETURNING *
      `;
      const roomResult = await pool.query(roomQuery, [name, type, req.user!.id]);
      const room = roomResult.rows[0];

      // Add participants
      const participants = [req.user!.id, ...participantIds];
      for (const participantId of participants) {
        await pool.query(
          'INSERT INTO chat_room_participants (room_id, user_id) VALUES ($1, $2)',
          [room.id, participantId]
        );
      }

      res.status(201).json({
        success: true,
        message: 'Chat room created successfully',
        data: room,
      });
    } catch (error) {
      console.error('Create room error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create chat room',
      });
    }
  };

  /**
   * Get user's chat rooms
   */
  getRooms = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      const query = `
        SELECT 
          cr.*,
          u.username,
          u.avatar_url,
          crp.joined_at,
          cm.content as last_message_content,
          cm.created_at as last_message_time,
          cm.message_type as last_message_type,
          cm.user_id as last_message_user_id,
          u2.username as last_message_username,
          COALESCE(unread.count, 0) as unread_count
        FROM chat_rooms cr
        INNER JOIN chat_room_participants crp ON cr.id = crp.room_id
        INNER JOIN users u ON crp.user_id = u.id
        LEFT JOIN (
          SELECT DISTINCT ON (room_id) room_id, content, created_at, message_type, user_id
          FROM chat_messages
          ORDER BY room_id, created_at DESC
        ) cm ON cr.id = cm.room_id
        LEFT JOIN users u2 ON cm.user_id = u2.id
        LEFT JOIN (
          SELECT room_id, COUNT(*) as count
          FROM chat_messages
          WHERE user_id != $1 AND created_at > (
            SELECT COALESCE(MAX(last_read_at), '1970-01-01'::timestamp)
            FROM chat_room_participants
            WHERE room_id = chat_messages.room_id AND user_id = $1
          )
          GROUP BY room_id
        ) unread ON cr.id = unread.room_id
        WHERE crp.user_id = $1
        ORDER BY COALESCE(cm.created_at, cr.updated_at) DESC
        LIMIT $2 OFFSET $3
      `;

      const result = await pool.query(query, [req.user!.id, Number(limit), offset]);
      const rooms = result.rows;

      res.json({
        success: true,
        data: rooms,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: rooms.length,
        },
      });
    } catch (error) {
      console.error('Get rooms error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get chat rooms',
      });
    }
  };

  /**
   * Get room by ID
   */
  getRoom = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId } = req.params;

      // Check if user is participant
      const participantCheck = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (participantCheck.rows.length === 0) {
        res.status(403).json({
          success: false,
          message: 'Access denied. You are not a participant in this room.',
        });
        return;
      }

      // Get room details
      const roomQuery = `
        SELECT 
          cr.*,
          u.username as created_by_username,
          u.avatar_url as created_by_avatar
        FROM chat_rooms cr
        INNER JOIN users u ON cr.created_by = u.id
        WHERE cr.id = $1
      `;
      const roomResult = await pool.query(roomQuery, [roomId]);
      const room = roomResult.rows[0];

      if (!room) {
        res.status(404).json({
          success: false,
          message: 'Chat room not found',
        });
        return;
      }

      // Get participants
      const participantsQuery = `
        SELECT 
          u.id,
          u.username,
          u.avatar_url,
          crp.joined_at
        FROM chat_room_participants crp
        INNER JOIN users u ON crp.user_id = u.id
        WHERE crp.room_id = $1
        ORDER BY crp.joined_at ASC
      `;
      const participantsResult = await pool.query(participantsQuery, [roomId]);
      const participants = participantsResult.rows;

      res.json({
        success: true,
        data: {
          ...room,
          participants,
        },
      });
    } catch (error) {
      console.error('Get room error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get chat room',
      });
    }
  };

  /**
   * Get room messages
   */
  getMessages = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId } = req.params;
      const { page = 1, limit = 50 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      // Check if user is participant
      const participantCheck = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (participantCheck.rows.length === 0) {
        res.status(403).json({
          success: false,
          message: 'Access denied. You are not a participant in this room.',
        });
        return;
      }

      // Get messages
      const messagesQuery = `
        SELECT 
          cm.*,
          u.username,
          u.avatar_url
        FROM chat_messages cm
        INNER JOIN users u ON cm.user_id = u.id
        WHERE cm.room_id = $1
        ORDER BY cm.created_at DESC
        LIMIT $2 OFFSET $3
      `;
      const result = await pool.query(messagesQuery, [roomId, Number(limit), offset]);
      const messages = result.rows.reverse(); // Reverse to get chronological order

      // Mark messages as read
      await pool.query(
        'UPDATE chat_room_participants SET last_read_at = CURRENT_TIMESTAMP WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      res.json({
        success: true,
        data: messages,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: messages.length,
        },
      });
    } catch (error) {
      console.error('Get messages error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get messages',
      });
    }
  };

  /**
   * Send message
   */
  sendMessage = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId } = req.params;
      const { content, message_type = 'text', file_url } = req.body;

      if (!content && !file_url) {
        res.status(400).json({
          success: false,
          message: 'Message content or file is required',
        });
        return;
      }

      // Check if user is participant
      const participantCheck = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (participantCheck.rows.length === 0) {
        res.status(403).json({
          success: false,
          message: 'Access denied. You are not a participant in this room.',
        });
        return;
      }

      // Create message
      const messageQuery = `
        INSERT INTO chat_messages (room_id, user_id, content, message_type, file_url)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `;
      const result = await pool.query(messageQuery, [
        roomId,
        req.user!.id,
        content,
        message_type,
        file_url,
      ]);
      const message = result.rows[0];

      // Update room timestamp
      await pool.query(
        'UPDATE chat_rooms SET updated_at = CURRENT_TIMESTAMP WHERE id = $1',
        [roomId]
      );

      res.status(201).json({
        success: true,
        message: 'Message sent successfully',
        data: message,
      });
    } catch (error) {
      console.error('Send message error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to send message',
      });
    }
  };

  /**
   * Edit message
   */
  editMessage = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { messageId } = req.params;
      const { content } = req.body;

      if (!content) {
        res.status(400).json({
          success: false,
          message: 'Message content is required',
        });
        return;
      }

      // Check if message exists and belongs to user
      const messageCheck = await pool.query(
        'SELECT id FROM chat_messages WHERE id = $1 AND user_id = $2',
        [messageId, req.user!.id]
      );

      if (messageCheck.rows.length === 0) {
        res.status(404).json({
          success: false,
          message: 'Message not found or you do not have permission to edit it',
        });
        return;
      }

      // Update message
      const updateQuery = `
        UPDATE chat_messages 
        SET content = $1, is_edited = true, updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
        RETURNING *
      `;
      const result = await pool.query(updateQuery, [content, messageId]);
      const message = result.rows[0];

      res.json({
        success: true,
        message: 'Message updated successfully',
        data: message,
      });
    } catch (error) {
      console.error('Edit message error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to edit message',
      });
    }
  };

  /**
   * Delete message
   */
  deleteMessage = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { messageId } = req.params;

      // Check if message exists and belongs to user
      const messageCheck = await pool.query(
        'SELECT id FROM chat_messages WHERE id = $1 AND user_id = $2',
        [messageId, req.user!.id]
      );

      if (messageCheck.rows.length === 0) {
        res.status(404).json({
          success: false,
          message: 'Message not found or you do not have permission to delete it',
        });
        return;
      }

      // Delete message
      await pool.query('DELETE FROM chat_messages WHERE id = $1', [messageId]);

      res.json({
        success: true,
        message: 'Message deleted successfully',
      });
    } catch (error) {
      console.error('Delete message error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete message',
      });
    }
  };

  /**
   * Add participant to room
   */
  addParticipant = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId } = req.params;
      const { userId } = req.body;

      if (!userId) {
        res.status(400).json({
          success: false,
          message: 'User ID is required',
        });
        return;
      }

      // Check if user is participant and has permission
      const participantCheck = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (participantCheck.rows.length === 0) {
        res.status(403).json({
          success: false,
          message: 'Access denied. You are not a participant in this room.',
        });
        return;
      }

      // Check if user to add exists
      const userCheck = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
      if (userCheck.rows.length === 0) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Check if user is already a participant
      const existingParticipant = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, userId]
      );

      if (existingParticipant.rows.length > 0) {
        res.status(400).json({
          success: false,
          message: 'User is already a participant in this room',
        });
        return;
      }

      // Add participant
      await pool.query(
        'INSERT INTO chat_room_participants (room_id, user_id) VALUES ($1, $2)',
        [roomId, userId]
      );

      res.json({
        success: true,
        message: 'Participant added successfully',
      });
    } catch (error) {
      console.error('Add participant error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to add participant',
      });
    }
  };

  /**
   * Remove participant from room
   */
  removeParticipant = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId, userId } = req.params;

      // Check if user is participant and has permission
      const participantCheck = await pool.query(
        'SELECT id FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (participantCheck.rows.length === 0) {
        res.status(403).json({
          success: false,
          message: 'Access denied. You are not a participant in this room.',
        });
        return;
      }

      // Remove participant
      const result = await pool.query(
        'DELETE FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, userId]
      );

      if (result.rowCount === 0) {
        res.status(404).json({
          success: false,
          message: 'Participant not found in this room',
        });
        return;
      }

      res.json({
        success: true,
        message: 'Participant removed successfully',
      });
    } catch (error) {
      console.error('Remove participant error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to remove participant',
      });
    }
  };

  /**
   * Leave room
   */
  leaveRoom = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { roomId } = req.params;

      // Remove user from room
      const result = await pool.query(
        'DELETE FROM chat_room_participants WHERE room_id = $1 AND user_id = $2',
        [roomId, req.user!.id]
      );

      if (result.rowCount === 0) {
        res.status(404).json({
          success: false,
          message: 'You are not a participant in this room',
        });
        return;
      }

      res.json({
        success: true,
        message: 'Left room successfully',
      });
    } catch (error) {
      console.error('Leave room error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to leave room',
      });
    }
  };
}
