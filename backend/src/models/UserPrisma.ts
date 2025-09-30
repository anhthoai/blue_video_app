import prisma from '../lib/prisma';
import bcrypt from 'bcryptjs';

export interface CreateUserData {
  username: string;
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
  bio?: string;
}

export interface UpdateUserData {
  firstName?: string;
  lastName?: string;
  bio?: string;
  avatarUrl?: string;
}

export interface UserProfile {
  id: string;
  username: string;
  firstName?: string;
  lastName?: string;
  bio?: string;
  avatarUrl?: string;
  isVerified: boolean;
  createdAt: Date;
  followersCount: number;
  followingCount: number;
  videosCount: number;
  postsCount: number;
  isFollowing?: boolean;
}

export class UserModel {
  /**
   * Create a new user
   */
  async create(userData: CreateUserData) {
    const passwordHash = await bcrypt.hash(userData.password, 12);
    
    return await prisma.user.create({
      data: {
        username: userData.username,
        email: userData.email,
        passwordHash,
        firstName: userData.firstName,
        lastName: userData.lastName,
        bio: userData.bio,
      },
    });
  }

  /**
   * Find user by ID
   */
  async findById(id: string) {
    return await prisma.user.findUnique({
      where: { id },
    });
  }

  /**
   * Find user by email
   */
  async findByEmail(email: string) {
    return await prisma.user.findUnique({
      where: { email },
    });
  }

  /**
   * Find user by username
   */
  async findByUsername(username: string) {
    return await prisma.user.findUnique({
      where: { username },
    });
  }

  /**
   * Update user
   */
  async update(id: string, userData: UpdateUserData) {
    return await prisma.user.update({
      where: { id },
      data: userData,
    });
  }

  /**
   * Get user profile with stats
   */
  async getProfile(userId: string, currentUserId?: string): Promise<UserProfile | null> {
    const user = await prisma.user.findUnique({
      where: { id: userId, isActive: true },
      include: {
        followers: true,
        following: true,
        videos: {
          where: { isPublic: true },
        },
        posts: {
          where: { isPublic: true },
        },
      },
    });

    if (!user) return null;

    // Check if current user is following this user
    let isFollowing = false;
    if (currentUserId && currentUserId !== userId) {
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId,
            followingId: userId,
          },
        },
      });
      isFollowing = !!follow;
    }

    return {
      id: user.id,
      username: user.username,
      firstName: user.firstName,
      lastName: user.lastName,
      bio: user.bio,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      followersCount: user.followers.length,
      followingCount: user.following.length,
      videosCount: user.videos.length,
      postsCount: user.posts.length,
      isFollowing,
    };
  }

  /**
   * Search users
   */
  async search(query: string, limit: number = 20, offset: number = 0) {
    const users = await prisma.user.findMany({
      where: {
        isActive: true,
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { firstName: { contains: query, mode: 'insensitive' } },
          { lastName: { contains: query, mode: 'insensitive' } },
        ],
      },
      include: {
        _count: {
          select: {
            followers: true,
            following: true,
            videos: { where: { isPublic: true } },
            posts: { where: { isPublic: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return users.map(user => ({
      id: user.id,
      username: user.username,
      firstName: user.firstName,
      lastName: user.lastName,
      bio: user.bio,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      followersCount: user._count.followers,
      followingCount: user._count.following,
      videosCount: user._count.videos,
      postsCount: user._count.posts,
    }));
  }

  /**
   * Get user's followers
   */
  async getFollowers(userId: string, limit: number = 20, offset: number = 0) {
    const followers = await prisma.follow.findMany({
      where: { followingId: userId },
      include: {
        follower: {
          include: {
            _count: {
              select: {
                followers: true,
                following: true,
                videos: { where: { isPublic: true } },
                posts: { where: { isPublic: true } },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return followers.map(follow => ({
      id: follow.follower.id,
      username: follow.follower.username,
      firstName: follow.follower.firstName,
      lastName: follow.follower.lastName,
      bio: follow.follower.bio,
      avatarUrl: follow.follower.avatarUrl,
      isVerified: follow.follower.isVerified,
      createdAt: follow.follower.createdAt,
      followersCount: follow.follower._count.followers,
      followingCount: follow.follower._count.following,
      videosCount: follow.follower._count.videos,
      postsCount: follow.follower._count.posts,
    }));
  }

  /**
   * Get user's following
   */
  async getFollowing(userId: string, limit: number = 20, offset: number = 0) {
    const following = await prisma.follow.findMany({
      where: { followerId: userId },
      include: {
        following: {
          include: {
            _count: {
              select: {
                followers: true,
                following: true,
                videos: { where: { isPublic: true } },
                posts: { where: { isPublic: true } },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return following.map(follow => ({
      id: follow.following.id,
      username: follow.following.username,
      firstName: follow.following.firstName,
      lastName: follow.following.lastName,
      bio: follow.following.bio,
      avatarUrl: follow.following.avatarUrl,
      isVerified: follow.following.isVerified,
      createdAt: follow.following.createdAt,
      followersCount: follow.following._count.followers,
      followingCount: follow.following._count.following,
      videosCount: follow.following._count.videos,
      postsCount: follow.following._count.posts,
    }));
  }

  /**
   * Delete user (soft delete)
   */
  async delete(id: string) {
    return await prisma.user.update({
      where: { id },
      data: { isActive: false },
    });
  }

  /**
   * Check if username exists
   */
  async usernameExists(username: string, excludeId?: string) {
    const user = await prisma.user.findFirst({
      where: {
        username,
        ...(excludeId && { id: { not: excludeId } }),
      },
    });
    return !!user;
  }

  /**
   * Check if email exists
   */
  async emailExists(email: string, excludeId?: string) {
    const user = await prisma.user.findFirst({
      where: {
        email,
        ...(excludeId && { id: { not: excludeId } }),
      },
    });
    return !!user;
  }
}
