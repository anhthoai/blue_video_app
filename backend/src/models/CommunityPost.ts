import { Pool } from 'pg';

export type PostType = 'text' | 'link' | 'poll' | 'media';

export type ReplyRestriction = 'FOLLOWERS' | 'PAID_VIEWERS' | 'FOLLOWING' | 'VERIFIED_FOLLOWING' | 'NO_ONE';

export interface CommunityPost {
  id: string;
  user_id: string;
  title?: string;
  content?: string;
  type: PostType;
  images?: string[];
  videos?: string[];
  videoThumbnails?: string[];
  link_url?: string;
  link_title?: string;
  link_description?: string;
  poll_options?: any;
  poll_votes?: any;
  tags?: string[];
  category?: string;
  likes: number;
  comments: number;
  shares: number;
  views: number;
  is_public: boolean;

  // New fields for enhanced community posts
  cost: number;
  requires_vip: boolean;
  allow_comments: boolean;
  allow_comment_links: boolean;
  is_pinned: boolean;
  is_nsfw: boolean;
  reply_restriction: ReplyRestriction;
  duration?: string[];

  created_at: Date;
  updated_at: Date;
}

export interface CreatePostData {
  user_id: string;
  title?: string;
  content?: string;
  type: PostType;
  images?: string[];
  videos?: string[];
  videoThumbnails?: string[];
  link_url?: string;
  link_title?: string;
  link_description?: string;
  poll_options?: any;
  tags?: string[];
  category?: string;

  // New fields for enhanced community posts
  cost?: number;
  requires_vip?: boolean;
  allow_comments?: boolean;
  allow_comment_links?: boolean;
  is_pinned?: boolean;
  is_nsfw?: boolean;
  reply_restriction?: ReplyRestriction;
  duration?: string[];
}

export interface UpdatePostData {
  title?: string;
  content?: string;
  images?: string[];
  videos?: string[];
  link_url?: string;
  link_title?: string;
  link_description?: string;
  poll_options?: any;
  poll_votes?: any;
  tags?: string[];
  category?: string;
  is_public?: boolean;
}

export interface PostWithUser extends CommunityPost {
  username: string;
  user_avatar?: string;
  is_liked?: boolean;
}

export interface PostStats {
  total_posts: number;
  total_likes: number;
  total_comments: number;
  total_shares: number;
  total_views: number;
}

export class CommunityPostModel {
  constructor(private pool: Pool) {}

  /**
   * Create a new community post
   */
  async create(postData: CreatePostData): Promise<CommunityPost> {
    const query = `
      INSERT INTO community_posts (
        user_id, title, content, type, images, videos,
        link_url, link_title, link_description, poll_options,
        tags, category, cost, requires_vip, allow_comments,
        allow_comment_links, is_pinned, is_nsfw, reply_restriction
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
      RETURNING *
    `;

    const values = [
      postData.user_id,
      postData.title || null,
      postData.content || null,
      postData.type,
      postData.images || null,
      postData.videos || null,
      postData.link_url || null,
      postData.link_title || null,
      postData.link_description || null,
      postData.poll_options ? JSON.stringify(postData.poll_options) : null,
      postData.tags || null,
      postData.category || null,
      postData.cost || 0,
      postData.requires_vip || false,
      postData.allow_comments !== false, // Default to true if not specified
      postData.allow_comment_links || false,
      postData.is_pinned || false,
      postData.is_nsfw || false,
      postData.reply_restriction || 'FOLLOWERS',
    ];

    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Find post by ID
   */
  async findById(id: string): Promise<CommunityPost | null> {
    const query = 'SELECT * FROM community_posts WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rows[0] || null;
  }

  /**
   * Get post with user info and like status
   */
  async findByIdWithUser(id: string, currentUserId?: string): Promise<PostWithUser | null> {
    const query = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $2
      WHERE p.id = $1
    `;

    const result = await this.pool.query(query, [id, currentUserId || null]);
    return result.rows[0] || null;
  }

  /**
   * Get posts feed
   */
  async getFeed(
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<PostWithUser[]> {
    const query = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $3
      WHERE p.is_public = true
      ORDER BY p.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await this.pool.query(query, [limit, offset, currentUserId || null]);
    return result.rows;
  }

  /**
   * Get trending posts
   */
  async getTrending(
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<PostWithUser[]> {
    const query = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked,
        (p.views * 0.1 + p.likes * 0.5 + p.comments * 0.3 + p.shares * 0.1) as trending_score
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $3
      WHERE p.is_public = true AND p.created_at >= NOW() - INTERVAL '7 days'
      ORDER BY trending_score DESC, p.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await this.pool.query(query, [limit, offset, currentUserId || null]);
    return result.rows;
  }

  /**
   * Get posts by user
   */
  async findByUserId(
    userId: string, 
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<PostWithUser[]> {
    const query = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $3
      WHERE p.user_id = $1 AND p.is_public = true
      ORDER BY p.created_at DESC
      LIMIT $2 OFFSET $4
    `;

    const result = await this.pool.query(query, [userId, limit, currentUserId || null, offset]);
    return result.rows;
  }

  /**
   * Search posts
   */
  async search(
    query: string, 
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<PostWithUser[]> {
    const searchQuery = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $3
      WHERE p.is_public = true 
        AND (
          p.title ILIKE $1 
          OR p.content ILIKE $1
          OR $1 = ANY(p.tags)
        )
      ORDER BY p.created_at DESC
      LIMIT $2 OFFSET $4
    `;

    const result = await this.pool.query(searchQuery, [`%${query}%`, limit, currentUserId || null, offset]);
    return result.rows;
  }

  /**
   * Get posts by category
   */
  async getByCategory(
    category: string,
    currentUserId?: string,
    limit: number = 20, 
    offset: number = 0
  ): Promise<PostWithUser[]> {
    const query = `
      SELECT 
        p.*,
        u.username,
        u.avatar_url as user_avatar,
        CASE WHEN l.id IS NOT NULL THEN true ELSE false END as is_liked
      FROM community_posts p
      INNER JOIN users u ON p.user_id = u.id
      LEFT JOIN likes l ON l.content_id = p.id AND l.content_type = 'post' AND l.user_id = $3
      WHERE p.category = $1 AND p.is_public = true
      ORDER BY p.created_at DESC
      LIMIT $2 OFFSET $4
    `;

    const result = await this.pool.query(query, [category, limit, currentUserId || null, offset]);
    return result.rows;
  }

  /**
   * Update post
   */
  async update(id: string, postData: UpdatePostData): Promise<CommunityPost | null> {
    const fields = [];
    const values = [];
    let paramCount = 1;

    if (postData.title !== undefined) {
      fields.push(`title = $${paramCount++}`);
      values.push(postData.title);
    }
    if (postData.content !== undefined) {
      fields.push(`content = $${paramCount++}`);
      values.push(postData.content);
    }
    if (postData.images !== undefined) {
      fields.push(`images = $${paramCount++}`);
      values.push(postData.images);
    }
    if (postData.videos !== undefined) {
      fields.push(`videos = $${paramCount++}`);
      values.push(postData.videos);
    }
    if (postData.link_url !== undefined) {
      fields.push(`link_url = $${paramCount++}`);
      values.push(postData.link_url);
    }
    if (postData.link_title !== undefined) {
      fields.push(`link_title = $${paramCount++}`);
      values.push(postData.link_title);
    }
    if (postData.link_description !== undefined) {
      fields.push(`link_description = $${paramCount++}`);
      values.push(postData.link_description);
    }
    if (postData.poll_options !== undefined) {
      fields.push(`poll_options = $${paramCount++}`);
      values.push(JSON.stringify(postData.poll_options));
    }
    if (postData.poll_votes !== undefined) {
      fields.push(`poll_votes = $${paramCount++}`);
      values.push(JSON.stringify(postData.poll_votes));
    }
    if (postData.tags !== undefined) {
      fields.push(`tags = $${paramCount++}`);
      values.push(postData.tags);
    }
    if (postData.category !== undefined) {
      fields.push(`category = $${paramCount++}`);
      values.push(postData.category);
    }
    if (postData.is_public !== undefined) {
      fields.push(`is_public = $${paramCount++}`);
      values.push(postData.is_public);
    }

    if (fields.length === 0) {
      return this.findById(id);
    }

    fields.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id);

    const query = `
      UPDATE community_posts 
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
    const query = 'UPDATE community_posts SET views = views + 1 WHERE id = $1';
    await this.pool.query(query, [id]);
  }

  /**
   * Update like count
   */
  async updateLikeCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE community_posts SET likes = GREATEST(0, likes + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Update comment count
   */
  async updateCommentCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE community_posts SET comments = GREATEST(0, comments + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Update share count
   */
  async updateShareCount(id: string, delta: number): Promise<void> {
    const query = 'UPDATE community_posts SET shares = GREATEST(0, shares + $1) WHERE id = $2';
    await this.pool.query(query, [delta, id]);
  }

  /**
   * Get post stats
   */
  async getStats(userId?: string): Promise<PostStats> {
    let query = `
      SELECT 
        COUNT(*) as total_posts,
        COALESCE(SUM(likes), 0) as total_likes,
        COALESCE(SUM(comments), 0) as total_comments,
        COALESCE(SUM(shares), 0) as total_shares,
        COALESCE(SUM(views), 0) as total_views
      FROM community_posts
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
   * Delete post
   */
  async delete(id: string): Promise<boolean> {
    const query = 'DELETE FROM community_posts WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return (result.rowCount ?? 0) > 0;
  }

  /**
   * Get categories
   */
  async getCategories(): Promise<{ category: string; count: number }[]> {
    const query = `
      SELECT category, COUNT(*) as count
      FROM community_posts
      WHERE is_public = true AND category IS NOT NULL
      GROUP BY category
      ORDER BY count DESC
    `;

    const result = await this.pool.query(query);
    return result.rows;
  }
}
