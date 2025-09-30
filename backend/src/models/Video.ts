import { Pool } from 'pg';

export interface Video {
  id: string;
  user_id: string;
  title: string;
  description?: string;
  video_url: string;
  thumbnail_url?: string;
  duration?: number;
  file_size?: number;
  quality?: string;
  views: number;
  likes: number;
  comments: number;
  shares: number;
  is_public: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface CreateVideoData {
  user_id: string;
  title: string;
  description?: string;
  video_url: string;
  thumbnail_url?: string;
  duration?: number;
  file_size?: number;
  quality?: string;
}

export interface UpdateVideoData {
  title?: string;
  description?: string;
  thumbnail_url?: string;
  is_public?: boolean;
}

export interface VideoWithUser extends Video {
  username: string;
  user_avatar?: string;
  is_liked?: boolean;
}

export interface VideoStats {
  total_videos: number;
  total_views: number;
  total_likes: number;
  total_comments: number;
  total_shares: number;
}

export class VideoModel {
  constructor(private pool: Pool) {}

  /**
   * Create a new video
   */
  async create(videoData: CreateVideoData): Promise<Video> {
    const query = `
      INSERT INTO videos (user_id, title, description, video_url, thumbnail_url, duration, file_size, quality)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `;
    
    const values = [
      videoData.user_id,
      videoData.title,
      videoData.description || null,
      videoData.video_url,
      videoData.thumbnail_url || null,
      videoData.duration || null,
      videoData.file_size || null,
      videoData.quality || null,
    ];

    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Find video by ID
   */
  async findById(id: string): Promise<Video | null> {
    const query = 'SELECT * FROM videos WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rows[0] || null;
  }

  /**
   * Get video with user info and like status
   */
  async findByIdWithUser(id: string, currentUserId?: string): Promise<VideoWithUser | null> {
    const query = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $2
      WHERE v.id = $1
    `;

    const result = await this.pool.query(query, [id, currentUserId || null]);
    return result.rows[0] || null;
  }

  /**
   * Get videos by user
   */
  async findByUserId(
    userId: string, 
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<VideoWithUser[]> {
    const query = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $3
      WHERE v.user_id = $1 AND v.is_public = true
      ORDER BY v.created_at DESC
      LIMIT $2 OFFSET $4
    `;

    const result = await this.pool.query(query, [userId, limit, currentUserId || null, offset]);
    return result.rows;
  }

  /**
   * Get public videos feed
   */
  async getFeed(
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<VideoWithUser[]> {
    const query = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $3
      WHERE v.is_public = true
      ORDER BY v.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await this.pool.query(query, [limit, offset, currentUserId || null]);
    return result.rows;
  }

  /**
   * Get trending videos
   */
  async getTrending(
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<VideoWithUser[]> {
    const query = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked,
        (v.views * 0.1 + v.likes * 0.5 + v.comments * 0.3 + v.shares * 0.1) as trending_score
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $3
      WHERE v.is_public = true AND v.created_at >= NOW() - INTERVAL '7 days'
      ORDER BY trending_score DESC, v.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await this.pool.query(query, [limit, offset, currentUserId || null]);
    return result.rows;
  }

  /**
   * Search videos
   */
  async search(
    query: string, 
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<VideoWithUser[]> {
    const searchQuery = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $3
      WHERE v.is_public = true 
        AND (
          v.title ILIKE $1 
          OR v.description ILIKE $1
        )
      ORDER BY v.created_at DESC
      LIMIT $2 OFFSET $4
    `;

    const result = await this.pool.query(searchQuery, [`%${query}%`, limit, currentUserId || null, offset]);
    return result.rows;
  }

  /**
   * Update video
   */
  async update(id: string, videoData: UpdateVideoData): Promise<Video | null> {
    const fields = [];
    const values = [];
    let paramCount = 1;

    if (videoData.title !== undefined) {
      fields.push(`title = $${paramCount++}`);
      values.push(videoData.title);
    }
    if (videoData.description !== undefined) {
      fields.push(`description = $${paramCount++}`);
      values.push(videoData.description);
    }
    if (videoData.thumbnail_url !== undefined) {
      fields.push(`thumbnail_url = $${paramCount++}`);
      values.push(videoData.thumbnail_url);
    }
    if (videoData.is_public !== undefined) {
      fields.push(`is_public = $${paramCount++}`);
      values.push(videoData.is_public);
    }

    if (fields.length === 0) {
      return this.findById(id);
    }

    fields.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id);

    const query = `
      UPDATE videos 
      SET ${fields.join(', ')}
      WHERE id = $${paramCount}
      RETURNING *
    `;

    const result = await this.pool.query(query, values);
    return result.rows[0] || null;
  }

  /**
   * Increment views
   */
  async incrementViews(id: string): Promise<void> {
    const query = 'UPDATE videos SET views = views + 1 WHERE id = $1';
    await this.pool.query(query, [id]);
  }

  /**
   * Update like count
   */
  async updateLikeCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE videos SET likes = GREATEST(0, likes + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Update comment count
   */
  async updateCommentCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE videos SET comments = GREATEST(0, comments + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Update share count
   */
  async updateShareCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE videos SET shares = GREATEST(0, shares + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Get video stats
   */
  async getStats(userId?: string): Promise<VideoStats> {
    let query = `
      SELECT 
        COUNT(*) as total_videos,
        COALESCE(SUM(views), 0) as total_views,
        COALESCE(SUM(likes), 0) as total_likes,
        COALESCE(SUM(comments), 0) as total_comments,
        COALESCE(SUM(shares), 0) as total_shares
      FROM videos
      WHERE is_public = true
    `;
    
    const values = [];
    if (userId) {
      query += ' AND user_id = $1';
      values.push(userId);
    }

    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Delete video
   */
  async delete(id: string): Promise<boolean> {
    const query = 'DELETE FROM videos WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rowCount > 0;
  }

  /**
   * Get recommended videos
   */
  async getRecommended(
    userId: string,
    currentUserId?: string,
    limit: number = 10
  ): Promise<VideoWithUser[]> {
    const query = `
      SELECT 
        v.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM videos v
      INNER JOIN users u ON v.user_id = u.id
      LEFT JOIN likes l ON l.content_id = v.id AND l.content_type = 'video' AND l.user_id = $3
      WHERE v.is_public = true 
        AND v.user_id != $1
        AND v.id NOT IN (
          SELECT content_id FROM likes WHERE user_id = $3 AND content_type = 'video'
        )
      ORDER BY (v.views * 0.1 + v.likes * 0.5 + v.comments * 0.3 + v.shares * 0.1) DESC
      LIMIT $2
    `;

    const result = await this.pool.query(query, [userId, limit, currentUserId || null]);
    return result.rows;
  }
}
