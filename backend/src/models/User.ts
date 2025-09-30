import { Pool } from 'pg';

export interface User {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  first_name?: string;
  last_name?: string;
  bio?: string;
  avatar_url?: string;
  is_verified: boolean;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface CreateUserData {
  username: string;
  email: string;
  password: string;
  first_name?: string;
  last_name?: string;
  bio?: string;
}

export interface UpdateUserData {
  first_name?: string;
  last_name?: string;
  bio?: string;
  avatar_url?: string;
}

export interface UserProfile {
  id: string;
  username: string;
  first_name?: string;
  last_name?: string;
  bio?: string;
  avatar_url?: string;
  is_verified: boolean;
  created_at: Date;
  followers_count: number;
  following_count: number;
  videos_count: number;
  posts_count: number;
  is_following?: boolean;
}

export class UserModel {
  constructor(private pool: Pool) {}

  /**
   * Create a new user
   */
  async create(userData: CreateUserData): Promise<User> {
    const query = `
      INSERT INTO users (username, email, password_hash, first_name, last_name, bio)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    
    const values = [
      userData.username,
      userData.email,
      userData.password, // This should be hashed before calling
      userData.first_name || null,
      userData.last_name || null,
      userData.bio || null,
    ];

    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  /**
   * Find user by ID
   */
  async findById(id: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rows[0] || null;
  }

  /**
   * Find user by email
   */
  async findByEmail(email: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await this.pool.query(query, [email]);
    return result.rows[0] || null;
  }

  /**
   * Find user by username
   */
  async findByUsername(username: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE username = $1';
    const result = await this.pool.query(query, [username]);
    return result.rows[0] || null;
  }

  /**
   * Update user
   */
  async update(id: string, userData: UpdateUserData): Promise<User | null> {
    const fields = [];
    const values = [];
    let paramCount = 1;

    if (userData.first_name !== undefined) {
      fields.push(`first_name = $${paramCount++}`);
      values.push(userData.first_name);
    }
    if (userData.last_name !== undefined) {
      fields.push(`last_name = $${paramCount++}`);
      values.push(userData.last_name);
    }
    if (userData.bio !== undefined) {
      fields.push(`bio = $${paramCount++}`);
      values.push(userData.bio);
    }
    if (userData.avatar_url !== undefined) {
      fields.push(`avatar_url = $${paramCount++}`);
      values.push(userData.avatar_url);
    }

    if (fields.length === 0) {
      return this.findById(id);
    }

    fields.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id);

    const query = `
      UPDATE users 
      SET ${fields.join(', ')}
      WHERE id = $${paramCount}
      RETURNING *
    `;

    const result = await this.pool.query(query, values);
    return result.rows[0] || null;
  }

  /**
   * Get user profile with stats
   */
  async getProfile(userId: string, currentUserId?: string): Promise<UserProfile | null> {
    const query = `
      SELECT 
        u.id,
        u.username,
        u.first_name,
        u.last_name,
        u.bio,
        u.avatar_url,
        u.is_verified,
        u.created_at,
        COALESCE(followers.count, 0) as followers_count,
        COALESCE(following.count, 0) as following_count,
        COALESCE(videos.count, 0) as videos_count,
        COALESCE(posts.count, 0) as posts_count,
        CASE WHEN f.id IS NOT NULL THEN true ELSE false END as is_following
      FROM users u
      LEFT JOIN (
        SELECT following_id, COUNT(*) as count
        FROM follows
        GROUP BY following_id
      ) followers ON u.id = followers.following_id
      LEFT JOIN (
        SELECT follower_id, COUNT(*) as count
        FROM follows
        GROUP BY follower_id
      ) following ON u.id = following.follower_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM videos
        WHERE is_public = true
        GROUP BY user_id
      ) videos ON u.id = videos.user_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM community_posts
        WHERE is_public = true
        GROUP BY user_id
      ) posts ON u.id = posts.user_id
      LEFT JOIN follows f ON f.follower_id = $2 AND f.following_id = u.id
      WHERE u.id = $1 AND u.is_active = true
    `;

    const result = await this.pool.query(query, [userId, currentUserId || null]);
    return result.rows[0] || null;
  }

  /**
   * Search users
   */
  async search(query: string, limit: number = 20, offset: number = 0): Promise<UserProfile[]> {
    const searchQuery = `
      SELECT 
        u.id,
        u.username,
        u.first_name,
        u.last_name,
        u.bio,
        u.avatar_url,
        u.is_verified,
        u.created_at,
        COALESCE(followers.count, 0) as followers_count,
        COALESCE(following.count, 0) as following_count,
        COALESCE(videos.count, 0) as videos_count,
        COALESCE(posts.count, 0) as posts_count
      FROM users u
      LEFT JOIN (
        SELECT following_id, COUNT(*) as count
        FROM follows
        GROUP BY following_id
      ) followers ON u.id = followers.following_id
      LEFT JOIN (
        SELECT follower_id, COUNT(*) as count
        FROM follows
        GROUP BY follower_id
      ) following ON u.id = following.follower_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM videos
        WHERE is_public = true
        GROUP BY user_id
      ) videos ON u.id = videos.user_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM community_posts
        WHERE is_public = true
        GROUP BY user_id
      ) posts ON u.id = posts.user_id
      WHERE u.is_active = true 
        AND (
          u.username ILIKE $1 
          OR u.first_name ILIKE $1 
          OR u.last_name ILIKE $1
        )
      ORDER BY u.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await this.pool.query(searchQuery, [`%${query}%`, limit, offset]);
    return result.rows;
  }

  /**
   * Get user's followers
   */
  async getFollowers(userId: string, limit: number = 20, offset: number = 0): Promise<UserProfile[]> {
    const query = `
      SELECT 
        u.id,
        u.username,
        u.first_name,
        u.last_name,
        u.bio,
        u.avatar_url,
        u.is_verified,
        u.created_at,
        COALESCE(followers.count, 0) as followers_count,
        COALESCE(following.count, 0) as following_count,
        COALESCE(videos.count, 0) as videos_count,
        COALESCE(posts.count, 0) as posts_count
      FROM users u
      INNER JOIN follows f ON f.follower_id = u.id
      LEFT JOIN (
        SELECT following_id, COUNT(*) as count
        FROM follows
        GROUP BY following_id
      ) followers ON u.id = followers.following_id
      LEFT JOIN (
        SELECT follower_id, COUNT(*) as count
        FROM follows
        GROUP BY follower_id
      ) following ON u.id = following.follower_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM videos
        WHERE is_public = true
        GROUP BY user_id
      ) videos ON u.id = videos.user_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM community_posts
        WHERE is_public = true
        GROUP BY user_id
      ) posts ON u.id = posts.user_id
      WHERE f.following_id = $1 AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await this.pool.query(query, [userId, limit, offset]);
    return result.rows;
  }

  /**
   * Get user's following
   */
  async getFollowing(userId: string, limit: number = 20, offset: number = 0): Promise<UserProfile[]> {
    const query = `
      SELECT 
        u.id,
        u.username,
        u.first_name,
        u.last_name,
        u.bio,
        u.avatar_url,
        u.is_verified,
        u.created_at,
        COALESCE(followers.count, 0) as followers_count,
        COALESCE(following.count, 0) as following_count,
        COALESCE(videos.count, 0) as videos_count,
        COALESCE(posts.count, 0) as posts_count
      FROM users u
      INNER JOIN follows f ON f.following_id = u.id
      LEFT JOIN (
        SELECT following_id, COUNT(*) as count
        FROM follows
        GROUP BY following_id
      ) followers ON u.id = followers.following_id
      LEFT JOIN (
        SELECT follower_id, COUNT(*) as count
        FROM follows
        GROUP BY follower_id
      ) following ON u.id = following.follower_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM videos
        WHERE is_public = true
        GROUP BY user_id
      ) videos ON u.id = videos.user_id
      LEFT JOIN (
        SELECT user_id, COUNT(*) as count
        FROM community_posts
        WHERE is_public = true
        GROUP BY user_id
      ) posts ON u.id = posts.user_id
      WHERE f.follower_id = $1 AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await this.pool.query(query, [userId, limit, offset]);
    return result.rows;
  }

  /**
   * Delete user (soft delete)
   */
  async delete(id: string): Promise<boolean> {
    const query = `
      UPDATE users 
      SET is_active = false, updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
    `;
    
    const result = await this.pool.query(query, [id]);
    return result.rowCount > 0;
  }

  /**
   * Check if username exists
   */
  async usernameExists(username: string, excludeId?: string): Promise<boolean> {
    let query = 'SELECT id FROM users WHERE username = $1';
    const values = [username];
    
    if (excludeId) {
      query += ' AND id != $2';
      values.push(excludeId);
    }
    
    const result = await this.pool.query(query, values);
    return result.rows.length > 0;
  }

  /**
   * Check if email exists
   */
  async emailExists(email: string, excludeId?: string): Promise<boolean> {
    let query = 'SELECT id FROM users WHERE email = $1';
    const values = [email];
    
    if (excludeId) {
      query += ' AND id != $2';
      values.push(excludeId);
    }
    
    const result = await this.pool.query(query, values);
    return result.rows.length > 0;
  }
}
