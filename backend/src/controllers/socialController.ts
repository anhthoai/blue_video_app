import { Request, Response } from 'express';
import { AuthRequest } from '../middleware/auth';

export class SocialController {
  /**
   * Like content (video, post, comment)
   */
  likeContent = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { contentId, contentType } = req.params;
      const { type = 'like' } = req.body;

      // Validate content type
      const validTypes = ['video', 'post', 'comment'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      // Validate like type
      if (!['like', 'dislike'].includes(type)) {
        res.status(400).json({
          success: false,
          message: 'Invalid like type',
        });
        return;
      }

      // Check if like already exists
      const existingLike = await pool.query(
        'SELECT id, type FROM likes WHERE user_id = $1 AND content_id = $2 AND content_type = $3',
        [req.user!.id, contentId, contentType]
      );

      if (existingLike.rows.length > 0) {
        const existingType = existingLike.rows[0].type;
        
        if (existingType === type) {
          // Remove like if same type
          await pool.query(
            'DELETE FROM likes WHERE user_id = $1 AND content_id = $2 AND content_type = $3',
            [req.user!.id, contentId, contentType]
          );
          
          // Update content like count
          await this.updateContentLikeCount(contentId, contentType, -1);
          
          res.json({
            success: true,
            message: 'Like removed successfully',
            data: { liked: false, type: null },
          });
          return;
        } else {
          // Update like type
          await pool.query(
            'UPDATE likes SET type = $1, created_at = CURRENT_TIMESTAMP WHERE user_id = $2 AND content_id = $3 AND content_type = $4',
            [type, req.user!.id, contentId, contentType]
          );
          
          res.json({
            success: true,
            message: 'Like updated successfully',
            data: { liked: true, type },
          });
          return;
        }
      }

      // Create new like
      await pool.query(
        'INSERT INTO likes (user_id, content_id, content_type, type) VALUES ($1, $2, $3, $4)',
        [req.user!.id, contentId, contentType, type]
      );

      // Update content like count
      await this.updateContentLikeCount(contentId, contentType, 1);

      res.json({
        success: true,
        message: 'Content liked successfully',
        data: { liked: true, type },
      });
    } catch (error) {
      console.error('Like content error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to like content',
      });
    }
  };

  /**
   * Get content likes
   */
  getContentLikes = async (req: Request, res: Response): Promise<void> => {
    try {
      const { contentId, contentType } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      // Validate content type
      const validTypes = ['video', 'post', 'comment'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      // Get likes
      const likesQuery = `
        SELECT 
          l.*,
          u.username,
          u.avatar_url
        FROM likes l
        INNER JOIN users u ON l.user_id = u.id
        WHERE l.content_id = $1 AND l.content_type = $2
        ORDER BY l.created_at DESC
        LIMIT $3 OFFSET $4
      `;
      const result = await pool.query(likesQuery, [contentId, contentType, Number(limit), offset]);
      const likes = result.rows;

      res.json({
        success: true,
        data: likes,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: likes.length,
        },
      });
    } catch (error) {
      console.error('Get content likes error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get content likes',
      });
    }
  };

  /**
   * Create comment
   */
  createComment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { contentId, contentType } = req.params;
      const { content, parentId } = req.body;

      if (!content) {
        res.status(400).json({
          success: false,
          message: 'Comment content is required',
        });
        return;
      }

      // Validate content type
      const validTypes = ['video', 'post'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      // Create comment
      const commentQuery = `
        INSERT INTO comments (user_id, content_id, content_type, parent_id, content)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `;
      const result = await pool.query(commentQuery, [
        req.user!.id,
        contentId,
        contentType,
        parentId || null,
        content,
      ]);
      const comment = result.rows[0];

      // Update content comment count
      await this.updateContentCommentCount(contentId, contentType, 1);

      res.status(201).json({
        success: true,
        message: 'Comment created successfully',
        data: comment,
      });
    } catch (error) {
      console.error('Create comment error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create comment',
      });
    }
  };

  /**
   * Get content comments
   */
  getContentComments = async (req: Request, res: Response): Promise<void> => {
    try {
      const { contentId, contentType } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      // Validate content type
      const validTypes = ['video', 'post'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      // Get comments
      const commentsQuery = `
        SELECT 
          c.*,
          u.username,
          u.avatar_url,
          CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked,
          COALESCE(replies.count, 0) as replies_count
        FROM comments c
        INNER JOIN users u ON c.user_id = u.id
        LEFT JOIN likes l ON l.content_id = c.id AND l.content_type = 'comment' AND l.user_id = $3
        LEFT JOIN (
          SELECT parent_id, COUNT(*) as count
          FROM comments
          GROUP BY parent_id
        ) replies ON c.id = replies.parent_id
        WHERE c.content_id = $1 AND c.content_type = $2 AND c.parent_id IS NULL
        ORDER BY c.created_at DESC
        LIMIT $4 OFFSET $5
      `;
      const result = await pool.query(commentsQuery, [
        contentId,
        contentType,
        req.headers['x-user-id'] || null,
        Number(limit),
        offset,
      ]);
      const comments = result.rows;

      res.json({
        success: true,
        data: comments,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: comments.length,
        },
      });
    } catch (error) {
      console.error('Get content comments error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get content comments',
      });
    }
  };

  /**
   * Get comment replies
   */
  getCommentReplies = async (req: Request, res: Response): Promise<void> => {
    try {
      const { commentId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      // Get replies
      const repliesQuery = `
        SELECT 
          c.*,
          u.username,
          u.avatar_url,
          CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
        FROM comments c
        INNER JOIN users u ON c.user_id = u.id
        LEFT JOIN likes l ON l.content_id = c.id AND l.content_type = 'comment' AND l.user_id = $2
        WHERE c.parent_id = $1
        ORDER BY c.created_at ASC
        LIMIT $3 OFFSET $4
      `;
      const result = await pool.query(repliesQuery, [
        commentId,
        req.headers['x-user-id'] || null,
        Number(limit),
        offset,
      ]);
      const replies = result.rows;

      res.json({
        success: true,
        data: replies,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: replies.length,
        },
      });
    } catch (error) {
      console.error('Get comment replies error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get comment replies',
      });
    }
  };

  /**
   * Update comment
   */
  updateComment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { commentId } = req.params;
      const { content } = req.body;

      if (!content) {
        res.status(400).json({
          success: false,
          message: 'Comment content is required',
        });
        return;
      }

      // Check if comment exists and belongs to user
      const commentCheck = await pool.query(
        'SELECT id FROM comments WHERE id = $1 AND user_id = $2',
        [commentId, req.user!.id]
      );

      if (commentCheck.rows.length === 0) {
        res.status(404).json({
          success: false,
          message: 'Comment not found or you do not have permission to edit it',
        });
        return;
      }

      // Update comment
      const updateQuery = `
        UPDATE comments 
        SET content = $1, is_edited = true, updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
        RETURNING *
      `;
      const result = await pool.query(updateQuery, [content, commentId]);
      const comment = result.rows[0];

      res.json({
        success: true,
        message: 'Comment updated successfully',
        data: comment,
      });
    } catch (error) {
      console.error('Update comment error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update comment',
      });
    }
  };

  /**
   * Delete comment
   */
  deleteComment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { commentId } = req.params;

      // Check if comment exists and belongs to user
      const commentCheck = await pool.query(
        'SELECT id, content_id, content_type FROM comments WHERE id = $1 AND user_id = $2',
        [commentId, req.user!.id]
      );

      if (commentCheck.rows.length === 0) {
        res.status(404).json({
          success: false,
          message: 'Comment not found or you do not have permission to delete it',
        });
        return;
      }

      const comment = commentCheck.rows[0];

      // Delete comment
      await pool.query('DELETE FROM comments WHERE id = $1', [commentId]);

      // Update content comment count
      await this.updateContentCommentCount(comment.content_id, comment.content_type, -1);

      res.json({
        success: true,
        message: 'Comment deleted successfully',
      });
    } catch (error) {
      console.error('Delete comment error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete comment',
      });
    }
  };

  /**
   * Share content
   */
  shareContent = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { contentId, contentType } = req.params;

      // Validate content type
      const validTypes = ['video', 'post'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      // Update content share count
      await this.updateContentShareCount(contentId, contentType, 1);

      res.json({
        success: true,
        message: 'Content shared successfully',
      });
    } catch (error) {
      console.error('Share content error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to share content',
      });
    }
  };

  /**
   * Get user's liked content
   */
  getUserLikedContent = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { contentType } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const offset = (Number(page) - 1) * Number(limit);

      // Validate content type
      const validTypes = ['video', 'post', 'comment'];
      if (!validTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          message: 'Invalid content type',
        });
        return;
      }

      let contentQuery = '';
      if (contentType === 'video') {
        contentQuery = `
          SELECT 
            v.*,
            u.username,
            u.avatar_url as user_avatar,
            l.created_at as liked_at
          FROM likes l
          INNER JOIN videos v ON l.content_id = v.id
          INNER JOIN users u ON v.user_id = u.id
          WHERE l.user_id = $1 AND l.content_type = 'video' AND l.type = 'like'
          ORDER BY l.created_at DESC
          LIMIT $2 OFFSET $3
        `;
      } else if (contentType === 'post') {
        contentQuery = `
          SELECT 
            p.*,
            u.username,
            u.avatar_url as user_avatar,
            l.created_at as liked_at
          FROM likes l
          INNER JOIN community_posts p ON l.content_id = p.id
          INNER JOIN users u ON p.user_id = u.id
          WHERE l.user_id = $1 AND l.content_type = 'post' AND l.type = 'like'
          ORDER BY l.created_at DESC
          LIMIT $2 OFFSET $3
        `;
      } else {
        contentQuery = `
          SELECT 
            c.*,
            u.username,
            u.avatar_url as user_avatar,
            l.created_at as liked_at
          FROM likes l
          INNER JOIN comments c ON l.content_id = c.id
          INNER JOIN users u ON c.user_id = u.id
          WHERE l.user_id = $1 AND l.content_type = 'comment' AND l.type = 'like'
          ORDER BY l.created_at DESC
          LIMIT $2 OFFSET $3
        `;
      }

      const result = await pool.query(contentQuery, [req.user!.id, Number(limit), offset]);
      const content = result.rows;

      res.json({
        success: true,
        data: content,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: content.length,
        },
      });
    } catch (error) {
      console.error('Get user liked content error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get liked content',
      });
    }
  };

  /**
   * Update content like count
   */
  private async updateContentLikeCount(contentId: string, contentType: string, delta: number): Promise<void> {
    if (contentType === 'video') {
      await pool.query('UPDATE videos SET likes = GREATEST(0, likes + $1) WHERE id = $2', [delta, contentId]);
    } else if (contentType === 'post') {
      await pool.query('UPDATE community_posts SET likes = GREATEST(0, likes + $1) WHERE id = $2', [delta, contentId]);
    } else if (contentType === 'comment') {
      await pool.query('UPDATE comments SET likes = GREATEST(0, likes + $1) WHERE id = $2', [delta, contentId]);
    }
  }

  /**
   * Update content comment count
   */
  private async updateContentCommentCount(contentId: string, contentType: string, delta: number): Promise<void> {
    if (contentType === 'video') {
      await pool.query('UPDATE videos SET comments = GREATEST(0, comments + $1) WHERE id = $2', [delta, contentId]);
    } else if (contentType === 'post') {
      await pool.query('UPDATE community_posts SET comments = GREATEST(0, comments + $1) WHERE id = $2', [delta, contentId]);
    }
  }

  /**
   * Update content share count
   */
  private async updateContentShareCount(contentId: string, contentType: string, delta: number): Promise<void> {
    if (contentType === 'video') {
      await pool.query('UPDATE videos SET shares = GREATEST(0, shares + $1) WHERE id = $2', [delta, contentId]);
    } else if (contentType === 'post') {
      await pool.query('UPDATE community_posts SET shares = GREATEST(0, shares + $1) WHERE id = $2', [delta, contentId]);
    }
  }
}
