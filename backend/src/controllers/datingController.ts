import { Response } from 'express';
import { CoinTransactionType, DatingMatchAction, DatingTier, PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { buildAvatarUrl } from '../utils/fileUrl';
import { StorageService } from '../config/storage';

const prisma = new PrismaClient();

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Great-circle distance in km using Haversine formula. */
function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function ageFromDob(dob: Date | null | undefined): number | null {
  if (!dob) return null;
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
  return age;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

const DATING_PLAN_COINS: Record<'VIP' | 'UNLIMITED', Record<'1W' | '1M' | '3M' | '12M', number>> = {
  VIP: {
    '1W': 120,
    '1M': 400,
    '3M': 1050,
    '12M': 3600,
  },
  UNLIMITED: {
    '1W': 220,
    '1M': 700,
    '3M': 1900,
    '12M': 6800,
  },
};

const DATING_DURATION_DAYS: Record<'1W' | '1M' | '3M' | '12M', number> = {
  '1W': 7,
  '1M': 30,
  '3M': 90,
  '12M': 365,
};

function resolveActiveDatingTier(profile: { datingTier: DatingTier; datingTierExpiresAt: Date | null } | null): DatingTier {
  if (!profile) {
    return 'FREE';
  }
  if (profile.datingTier === 'FREE') {
    return 'FREE';
  }
  if (profile.datingTierExpiresAt && profile.datingTierExpiresAt.getTime() < Date.now()) {
    return 'FREE';
  }
  return profile.datingTier;
}

function isStorageObjectKey(value: string | null | undefined): value is string {
  if (!value) return false;
  const raw = value.trim();
  if (raw.length === 0) return false;
  return !raw.startsWith('http://') && !raw.startsWith('https://');
}

function startOfTodayUtc(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

type SuggestionCandidate = {
  userId: string;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  avatarUrl: string | null;
  updatedAt: string;
  age: number | null;
  distanceKm: number | null;
  isOnline: boolean | null;
  role: string | null;
  bodyType: string | null;
  score: number;
  reasons: string[];
};

function overlapScore(a: string[] | null | undefined, b: string[] | null | undefined): number {
  if (!a || !b || a.length === 0 || b.length === 0) return 0;
  const setA = new Set(a);
  let hits = 0;
  for (const item of b) {
    if (setA.has(item)) hits += 1;
  }
  return Math.min(1, hits / Math.max(1, Math.min(a.length, b.length)));
}

function calcSuggestionScore(input: {
  requester: {
    role: string | null;
    bodyType: string | null;
    lookingFor: string[];
    preferredTribes: string[];
    latitude: number | null;
    longitude: number | null;
  };
  candidate: {
    role: string | null;
    bodyType: string | null;
    lookingFor: string[];
    preferredTribes: string[];
    latitude: number | null;
    longitude: number | null;
  };
}): { score: number; reasons: string[]; distanceKm: number | null } {
  const reasons: string[] = [];
  let score = 0;

  const requesterRole = input.requester.role;
  const candidateRole = input.candidate.role;
  if (requesterRole && candidateRole && requesterRole === candidateRole) {
    score += 22;
    reasons.push('Similar role preference');
  }

  const interestOverlap = overlapScore(input.requester.lookingFor, input.candidate.lookingFor);
  if (interestOverlap > 0) {
    score += Math.round(interestOverlap * 28);
    reasons.push('Shared dating goals');
  }

  const tribeOverlap = overlapScore(input.requester.preferredTribes, input.candidate.preferredTribes);
  if (tribeOverlap > 0) {
    score += Math.round(tribeOverlap * 24);
    reasons.push('Similar tribe interests');
  }

  if (
    input.requester.bodyType &&
    input.candidate.bodyType &&
    input.requester.bodyType === input.candidate.bodyType
  ) {
    score += 12;
    reasons.push('Compatible body type preference');
  }

  let distanceKm: number | null = null;
  if (
    input.requester.latitude != null &&
    input.requester.longitude != null &&
    input.candidate.latitude != null &&
    input.candidate.longitude != null
  ) {
    distanceKm = Math.round(
      haversineKm(
        input.requester.latitude,
        input.requester.longitude,
        input.candidate.latitude,
        input.candidate.longitude,
      ),
    );
    if (distanceKm <= 5) {
      score += 22;
      reasons.push('Very close distance');
    } else if (distanceKm <= 15) {
      score += 15;
      reasons.push('Nearby location');
    } else if (distanceKm <= 30) {
      score += 8;
      reasons.push('Reasonable distance');
    }
  }

  if (reasons.length === 0) {
    reasons.push('Trending in your area');
  }

  return {
    score: Math.max(1, Math.min(99, score)),
    reasons: reasons.slice(0, 3),
    distanceKm,
  };
}

// ─── Controller ──────────────────────────────────────────────────────────────

export class DatingController {

  // ── Explore: get nearby / online users ────────────────────────────────────

  getExploreUsers = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const {
        tab = 'nearby',          // 'nearby' | 'online'
        lat,
        lon,
        radiusKm = '3',
        page = '1',
        limit = '30',
        q,
        // Filters
        minAge,
        maxAge,
        roles,
        tribes,
        lookingFor,
      } = req.query as Record<string, string>;

      const pageNum = Math.max(1, parseInt(page, 10));
      const pageSize = Math.min(1000, Math.max(1, parseInt(limit, 10)));
      const requestedOffset = (pageNum - 1) * pageSize;

      const requester = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          role: true,
          isVip: true,
          datingProfile: {
            select: {
              datingTier: true,
              datingTierExpiresAt: true,
            },
          },
        },
      });

      const activeTier = resolveActiveDatingTier(requester?.datingProfile ?? null);
      const planViewLimit = requester?.role === 'ADMIN'
        ? null
        : activeTier === 'UNLIMITED'
            ? null
            : activeTier === 'VIP' || requester?.isVip
                ? 600
                : 60;

      if (planViewLimit != null && requestedOffset >= planViewLimit) {
        res.json({
          success: true,
          data: pageNum === 1 ? [] : [],
          page: pageNum,
          planTier: activeTier,
          planViewLimit,
          totalAvailable: planViewLimit,
        });
        return;
      }

      // Update the requester's last-seen and location if provided
      const locationUpdate: Record<string, unknown> = { lastSeenAt: new Date(), isOnline: true };
      if (lat && lon) {
        locationUpdate['latitude'] = parseFloat(lat);
        locationUpdate['longitude'] = parseFloat(lon);
      }
      await prisma.datingProfile.upsert({
        where: { userId },
        update: locationUpdate,
        create: { userId, ...locationUpdate },
      });

      const where: Record<string, unknown> = {
        userId: { not: userId },
        user: { isActive: true },
      };

      if (tab === 'online') {
        const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
        where['lastSeenAt'] = { gte: fiveMinAgo };
      }

      if (roles) {
        where['role'] = { in: (roles as string).split(',') };
      }

      if (tribes) {
        where['preferredTribes'] = { hasSome: (tribes as string).split(',') };
      }

      if (lookingFor) {
        where['lookingFor'] = { hasSome: (lookingFor as string).split(',') };
      }

      if (q && q.trim().length > 0) {
        const keyword = q.trim();
        where['OR'] = [
          { user: { username: { contains: keyword, mode: 'insensitive' } } },
          { user: { firstName: { contains: keyword, mode: 'insensitive' } } },
          { user: { lastName: { contains: keyword, mode: 'insensitive' } } },
          { whereILive: { contains: keyword, mode: 'insensitive' } },
          { nationality: { contains: keyword, mode: 'insensitive' } },
        ];
      }

      // Age filter requires dateOfBirth calculation in application layer
      const minAgeNum = minAge ? parseInt(minAge, 10) : null;
      const maxAgeNum = maxAge ? parseInt(maxAge, 10) : null;

      const profiles = await prisma.datingProfile.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              avatar: true,
              fileDirectory: true,
              s3StorageId: true,
              updatedAt: true,
            },
          },
        },
        orderBy: { lastSeenAt: 'desc' },
        // Fetch enough for app-layer age/distance filters before final paging.
        take: planViewLimit == null
          ? 1000
          : Math.min(1000, Math.max(planViewLimit + 100, pageSize * 6)),
      });

      const userLat = lat ? parseFloat(lat) : null;
      const userLon = lon ? parseFloat(lon) : null;
      const parsedRadius = parseFloat(radiusKm);
      const radius = Number.isFinite(parsedRadius) && parsedRadius > 0 ? parsedRadius : 3;

      const filteredWithDistance = profiles
        .filter((p) => {
          // Distance filter (only if caller provided location and profile has location)
          if (tab === 'nearby' && userLat != null && userLon != null) {
            if (p.latitude == null || p.longitude == null) return false;
            if (!p.showDistance) return true; // include but no distance
            const dist = haversineKm(userLat, userLon, p.latitude, p.longitude);
            if (dist > radius) return false;
          }
          // Age filter
          if (minAgeNum != null || maxAgeNum != null) {
            const age = ageFromDob(p.dateOfBirth);
            if (age == null) return true; // include if age unknown
            if (minAgeNum != null && age < minAgeNum) return false;
            if (maxAgeNum != null && age > maxAgeNum) return false;
          }
          return true;
        })
        .map((p) => {
          const distKm =
            userLat != null &&
            userLon != null &&
            p.latitude != null &&
            p.longitude != null &&
            p.showDistance
              ? Math.round(haversineKm(userLat, userLon, p.latitude, p.longitude))
              : null;
          return {
            userId: p.userId,
            username: p.user.username,
            firstName: p.user.firstName,
            lastName: p.user.lastName,
            avatarUrl: buildAvatarUrl(p.user),
            updatedAt: p.user.updatedAt.toISOString(),
            age: ageFromDob(p.dateOfBirth),
            distanceKm: distKm,
            isOnline: p.showOnline ? p.isOnline : null,
            isSelf: false,
            role: p.role,
            bodyType: p.bodyType,
            lookingFor: p.lookingFor,
            preferredTribes: p.preferredTribes,
          };
        });

      const filtered =
        userLat != null && userLon != null
          ? [...filteredWithDistance].sort((a, b) => {
                const ad = a.distanceKm ?? Number.MAX_SAFE_INTEGER;
                const bd = b.distanceKm ?? Number.MAX_SAFE_INTEGER;
                return ad - bd;
              })
          : filteredWithDistance;

      const paged = filtered.slice(requestedOffset, requestedOffset + pageSize);

      const selfUser = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          username: true,
          firstName: true,
          lastName: true,
          avatarUrl: true,
          updatedAt: true,
        },
      });

      const selfDistanceKm =
        userLat != null && userLon != null ? 0 : null;

      const selfCard = {
        userId,
        username: selfUser?.username ?? null,
        firstName: selfUser?.firstName ?? null,
        lastName: selfUser?.lastName ?? null,
        avatarUrl: selfUser ? buildAvatarUrl(selfUser) : null,
        updatedAt: selfUser?.updatedAt?.toISOString() ?? null,
        age: null,
        distanceKm: selfDistanceKm,
        isOnline: true,
        isSelf: true,
        role: null,
        bodyType: null,
        lookingFor: [] as string[],
        preferredTribes: [] as string[],
      };

      const responseData = pageNum === 1 ? [selfCard, ...paged] : paged;
      res.json({
        success: true,
        data: responseData,
        page: pageNum,
        planTier: activeTier,
        planViewLimit,
        totalAvailable: filtered.length,
      });
    } catch (error) {
      console.error('Dating explore error:', error);
      res.status(500).json({ success: false, message: 'Failed to load users' });
    }
  };

  // ── Get dating profile (own or other user) ─────────────────────────────────

  getDatingProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const requesterId = req.user!.id;
      const { userId } = req.params as { userId: string };
      const targetId: string = userId === 'me' ? requesterId : userId;

      const requesterProfile = await prisma.datingProfile.findUnique({
        where: { userId: requesterId },
        select: {
          latitude: true,
          longitude: true,
        },
      });

      const profile = await prisma.datingProfile.findUnique({
        where: { userId: targetId },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              bio: true,
              avatarUrl: true,
              avatar: true,
              fileDirectory: true,
              s3StorageId: true,
              isVip: true,
            },
          },
        },
      });

      if (!profile) {
        res.status(404).json({ success: false, message: 'Dating profile not found' });
        return;
      }

      // Check private album access
      let privateAlbumAccessStatus: string | null = null;
      let privateAlbumPhotoCount = 0;
      let privateAlbumPhotos: string[] = [];

      if (targetId !== requesterId) {
        const album = await prisma.privateAlbum.findFirst({ where: { userId: targetId } });
        privateAlbumPhotoCount = album?.photos.length ?? 0;

        const accessReq = await prisma.privateAlbumAccessRequest.findFirst({
          where: { albumId: album?.id ?? '', requesterId },
        });
        privateAlbumAccessStatus = accessReq?.status ?? null;

        if (accessReq?.status === 'ACCEPTED' && album) {
          privateAlbumPhotos = album.photos;
        }
      } else {
        const album = await prisma.privateAlbum.findFirst({ where: { userId: targetId } });
        privateAlbumPhotos = album?.photos ?? [];
        privateAlbumPhotoCount = privateAlbumPhotos.length;
      }

      const distanceKm =
        requesterProfile?.latitude != null &&
        requesterProfile.longitude != null &&
        profile.latitude != null &&
        profile.longitude != null &&
        profile.showDistance
          ? Math.round(
              haversineKm(
                requesterProfile.latitude,
                requesterProfile.longitude,
                profile.latitude,
                profile.longitude,
              ),
            )
          : requesterId === targetId &&
                  requesterProfile?.latitude != null &&
                  requesterProfile.longitude != null
              ? 0
              : null;

      res.json({
        success: true,
        data: {
          ...profile,
          user: {
            ...profile.user,
            avatarUrl: buildAvatarUrl(profile.user),
          },
          age: ageFromDob(profile.dateOfBirth),
          distanceKm,
          publicPhotos: profile.publicPhotos,
          datingTier: resolveActiveDatingTier(profile),
          datingTierExpiresAt: profile.datingTierExpiresAt,
          privateAlbumPhotoCount,
          privateAlbumPhotos,
          privateAlbumAccessStatus,
        },
      });
    } catch (error) {
      console.error('Get dating profile error:', error);
      res.status(500).json({ success: false, message: 'Failed to get dating profile' });
    }
  };

  // ── Update own dating profile ──────────────────────────────────────────────

  updateDatingProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const {
        dateOfBirth,
        role,
        heightCm,
        weightKg,
        bodyType,
        bodyHair,
        languages,
        whereILive,
        nationality,
        ethnicity,
        relationshipStatus,
        latitude,
        longitude,
        showDistance,
        showOnline,
        maxDistanceKm,
        lookingFor,
        whereToMeet,
        preferredTribes,
        aiMatchingEnabled,
      } = req.body as Record<string, unknown>;

      // Clamp preferredTribes to max 3
      const tribes = Array.isArray(preferredTribes)
        ? (preferredTribes as string[]).slice(0, 3)
        : undefined;

      const data: Record<string, unknown> = {};
      if (dateOfBirth !== undefined) data['dateOfBirth'] = new Date(dateOfBirth as string);
      if (role !== undefined) data['role'] = role;
      if (heightCm !== undefined) data['heightCm'] = Number(heightCm);
      if (weightKg !== undefined) data['weightKg'] = Number(weightKg);
      if (bodyType !== undefined) data['bodyType'] = bodyType;
      if (bodyHair !== undefined) data['bodyHair'] = bodyHair;
      if (languages !== undefined) data['languages'] = languages;
      if (whereILive !== undefined) data['whereILive'] = whereILive;
      if (nationality !== undefined) data['nationality'] = nationality;
      if (ethnicity !== undefined) data['ethnicity'] = ethnicity;
      if (relationshipStatus !== undefined) data['relationshipStatus'] = relationshipStatus;
      if (latitude !== undefined) data['latitude'] = Number(latitude);
      if (longitude !== undefined) data['longitude'] = Number(longitude);
      if (showDistance !== undefined) data['showDistance'] = Boolean(showDistance);
      if (showOnline !== undefined) data['showOnline'] = Boolean(showOnline);
      let currentUser: { isVip: boolean; role: 'ADMIN' | 'USER' } | null = null;
      if (maxDistanceKm !== undefined || aiMatchingEnabled !== undefined) {
        currentUser = await prisma.user.findUnique({
          where: { id: userId },
          select: { isVip: true, role: true },
        }) as { isVip: boolean; role: 'ADMIN' | 'USER' } | null;
      }

      if (maxDistanceKm !== undefined) {
        const requestedDistanceKm = Math.max(1, Number(maxDistanceKm));
        const canChangeDistance = currentUser?.isVip === true || currentUser?.role === 'ADMIN';
        data['maxDistanceKm'] = canChangeDistance ? requestedDistanceKm : 3;
      }
      if (lookingFor !== undefined) data['lookingFor'] = lookingFor;
      if (whereToMeet !== undefined) data['whereToMeet'] = whereToMeet;
      if (tribes !== undefined) data['preferredTribes'] = tribes;
      if (aiMatchingEnabled !== undefined) {
        // Only VIP users can enable AI matching
        if (aiMatchingEnabled && !currentUser?.isVip) {
          res.status(403).json({ success: false, message: 'AI matching is a VIP feature' });
          return;
        }
        data['aiMatchingEnabled'] = Boolean(aiMatchingEnabled);
      }

      const profile = await prisma.datingProfile.upsert({
        where: { userId },
        update: data,
        create: { userId, ...data },
      });

      res.json({ success: true, data: profile });
    } catch (error) {
      console.error('Update dating profile error:', error);
      res.status(500).json({ success: false, message: 'Failed to update dating profile' });
    }
  };

  // ── Like / dislike ─────────────────────────────────────────────────────────

  matchAction = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const fromUserId = req.user!.id;
      const { userId: toUserId } = req.params as { userId: string };
      const { action } = req.body as { action: 'LIKE' | 'DISLIKE' | 'SUPERLIKE' };

      if (!['LIKE', 'DISLIKE', 'SUPERLIKE'].includes(action)) {
        res.status(400).json({ success: false, message: 'Invalid action' });
        return;
      }

      if (fromUserId === toUserId) {
        res.status(400).json({ success: false, message: 'Cannot match with yourself' });
        return;
      }

      // Upsert match record
      await prisma.datingMatch.upsert({
        where: { fromUserId_toUserId: { fromUserId, toUserId } },
        update: { action, isMutual: false },
        create: { fromUserId, toUserId, action },
      });

      let isMutual = false;

      if (action === 'LIKE' || action === 'SUPERLIKE') {
        // Check if the other user already liked back
        const reverse = await prisma.datingMatch.findUnique({
          where: { fromUserId_toUserId: { fromUserId: toUserId, toUserId: fromUserId } },
        });
        if (reverse && (reverse.action === 'LIKE' || reverse.action === 'SUPERLIKE')) {
          // Mark both as mutual
          await prisma.$transaction([
            prisma.datingMatch.update({
              where: { fromUserId_toUserId: { fromUserId, toUserId } },
              data: { isMutual: true },
            }),
            prisma.datingMatch.update({
              where: { fromUserId_toUserId: { fromUserId: toUserId, toUserId: fromUserId } },
              data: { isMutual: true },
            }),
          ]);
          isMutual = true;
        }
      }

      res.json({ success: true, isMutual });
    } catch (error) {
      console.error('Match action error:', error);
      res.status(500).json({ success: false, message: 'Failed to process match action' });
    }
  };

  // ── Get mutual matches (Meet tab) ──────────────────────────────────────────

  getMutualMatches = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { page = '1', limit = '20' } = req.query as Record<string, string>;
      const pageNum = Math.max(1, parseInt(page, 10));
      const pageSize = Math.min(50, parseInt(limit, 10));
      const skip = (pageNum - 1) * pageSize;

      const matches = await prisma.datingMatch.findMany({
        where: { fromUserId: userId, isMutual: true, action: { in: ['LIKE', 'SUPERLIKE'] } },
        include: {
          toUser: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              avatar: true,
              fileDirectory: true,
              s3StorageId: true,
              updatedAt: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: pageSize,
      });

      // Attach dating profile info
      const toUserIds = matches.map((m) => m.toUserId);
      const profiles = await prisma.datingProfile.findMany({
        where: { userId: { in: toUserIds } },
        select: { userId: true, dateOfBirth: true, role: true, isOnline: true, showOnline: true },
      });
      const profileMap = new Map(profiles.map((p) => [p.userId, p]));

      const data = matches.map((m) => {
        const dp = profileMap.get(m.toUserId);
        return {
          matchId: m.id,
          matchedAt: m.createdAt,
          user: {
            ...m.toUser,
            avatarUrl: buildAvatarUrl(m.toUser),
            updatedAt: m.toUser.updatedAt.toISOString(),
            age: ageFromDob(dp?.dateOfBirth ?? null),
            isOnline: dp?.showOnline ? dp.isOnline : null,
            role: dp?.role ?? null,
          },
        };
      });

      res.json({ success: true, data, page: pageNum });
    } catch (error) {
      console.error('Get mutual matches error:', error);
      res.status(500).json({ success: false, message: 'Failed to get matches' });
    }
  };

  getSuggestedMatches = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;

      const requester = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          role: true,
          isVip: true,
          datingProfile: {
            select: {
              datingTier: true,
              datingTierExpiresAt: true,
              role: true,
              bodyType: true,
              lookingFor: true,
              preferredTribes: true,
              latitude: true,
              longitude: true,
            },
          },
        },
      });

      const tier = resolveActiveDatingTier(requester?.datingProfile ?? null);
      const isVip = requester?.role === 'ADMIN' || tier === 'VIP' || tier === 'UNLIMITED' || requester?.isVip === true;
      const aiEnabled = isVip;
  const maxPerDay = requester?.role === 'ADMIN' || tier === 'UNLIMITED'
    ? 1000000
    : isVip
    ? 30
    : 3;
  const candidateFetchLimit = requester?.role === 'ADMIN' || tier === 'UNLIMITED'
    ? 1000
    : isVip
    ? 240
    : 120;

      const startToday = startOfTodayUtc();
      const actedToday = await prisma.datingMatch.count({
        where: {
          fromUserId: userId,
          createdAt: { gte: startToday },
          action: { in: [DatingMatchAction.LIKE, DatingMatchAction.DISLIKE, DatingMatchAction.SUPERLIKE] },
        },
      });

      const remainingToday = Math.max(0, maxPerDay - actedToday);
      if (remainingToday <= 0) {
        res.json({
          success: true,
          data: [],
          meta: {
            maxPerDay,
            remainingToday,
            aiEnabled,
            tier,
          },
        });
        return;
      }

      const previousActions = await prisma.datingMatch.findMany({
        where: { fromUserId: userId },
        select: { toUserId: true },
      });
      const excludedIds = new Set(previousActions.map((item) => item.toUserId));

      const requesterProfile = requester?.datingProfile;
      const candidates = await prisma.datingProfile.findMany({
        where: {
          userId: {
            notIn: [userId, ...excludedIds],
          },
          user: { isActive: true },
        },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              avatar: true,
              fileDirectory: true,
              s3StorageId: true,
              updatedAt: true,
            },
          },
        },
        take: candidateFetchLimit,
      });

      const scored: SuggestionCandidate[] = candidates.map((candidate) => {
        const scoring = calcSuggestionScore({
          requester: {
            role: requesterProfile?.role ?? null,
            bodyType: requesterProfile?.bodyType ?? null,
            lookingFor: requesterProfile?.lookingFor ?? [],
            preferredTribes: requesterProfile?.preferredTribes ?? [],
            latitude: requesterProfile?.latitude ?? null,
            longitude: requesterProfile?.longitude ?? null,
          },
          candidate: {
            role: candidate.role ?? null,
            bodyType: candidate.bodyType ?? null,
            lookingFor: candidate.lookingFor,
            preferredTribes: candidate.preferredTribes,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
          },
        });

        return {
          userId: candidate.userId,
          username: candidate.user.username,
          firstName: candidate.user.firstName,
          lastName: candidate.user.lastName,
          avatarUrl: buildAvatarUrl(candidate.user),
          updatedAt: candidate.user.updatedAt.toISOString(),
          age: ageFromDob(candidate.dateOfBirth),
          distanceKm: scoring.distanceKm,
          isOnline: candidate.showOnline ? candidate.isOnline : null,
          role: candidate.role ?? null,
          bodyType: candidate.bodyType ?? null,
          score: scoring.score,
          reasons: scoring.reasons,
        };
      });

      scored.sort((a, b) => b.score - a.score);
      const data = scored.slice(0, remainingToday);

      res.json({
        success: true,
        data,
        meta: {
          maxPerDay,
          remainingToday,
          aiEnabled,
          tier,
        },
      });
    } catch (error) {
      console.error('Get suggested matches error:', error);
      res.status(500).json({ success: false, message: 'Failed to get suggested matches' });
    }
  };

  // ── Private Album ──────────────────────────────────────────────────────────

  getUpgradeStatus = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          role: true,
          isVip: true,
          coinBalance: true,
          datingProfile: {
            select: {
              datingTier: true,
              datingTierExpiresAt: true,
            },
          },
        },
      });

      const baseTier = resolveActiveDatingTier(user?.datingProfile ?? null);
      const tier = user?.role === 'ADMIN'
        ? 'UNLIMITED'
        : baseTier === 'FREE' && user?.isVip
            ? 'VIP'
            : baseTier;
      const viewLimit = tier === 'UNLIMITED' ? null : tier === 'VIP' ? 600 : 60;

      res.json({
        success: true,
        data: {
          tier,
          expiresAt: user?.datingProfile?.datingTierExpiresAt ?? null,
          viewLimit,
          coinBalance: user?.coinBalance ?? 0,
        },
      });
    } catch (error) {
      console.error('Get dating upgrade status error:', error);
      res.status(500).json({ success: false, message: 'Failed to get upgrade status' });
    }
  };

  getUpgradePlans = async (_req: AuthRequest, res: Response): Promise<void> => {
    res.json({
      success: true,
      data: {
        plans: [
          {
            tier: 'VIP',
            maxProfiles: 600,
            durations: [
              { key: '1W', label: '1 week', coins: DATING_PLAN_COINS.VIP['1W'] },
              { key: '1M', label: '1 month', coins: DATING_PLAN_COINS.VIP['1M'] },
              { key: '3M', label: '3 months', coins: DATING_PLAN_COINS.VIP['3M'] },
              { key: '12M', label: '12 months', coins: DATING_PLAN_COINS.VIP['12M'] },
            ],
          },
          {
            tier: 'UNLIMITED',
            maxProfiles: null,
            durations: [
              { key: '1W', label: '1 week', coins: DATING_PLAN_COINS.UNLIMITED['1W'] },
              { key: '1M', label: '1 month', coins: DATING_PLAN_COINS.UNLIMITED['1M'] },
              { key: '3M', label: '3 months', coins: DATING_PLAN_COINS.UNLIMITED['3M'] },
              { key: '12M', label: '12 months', coins: DATING_PLAN_COINS.UNLIMITED['12M'] },
            ],
          },
        ],
      },
    });
  };

  purchaseUpgrade = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { tier, duration } = req.body as { tier?: 'VIP' | 'UNLIMITED'; duration?: '1W' | '1M' | '3M' | '12M' };

      if (!tier || !duration || !DATING_PLAN_COINS[tier]?.[duration] || !DATING_DURATION_DAYS[duration]) {
        res.status(400).json({ success: false, message: 'Invalid tier or duration' });
        return;
      }

      const coinCost = DATING_PLAN_COINS[tier][duration];
      const durationDays = DATING_DURATION_DAYS[duration];

      const result = await prisma.$transaction(async (tx) => {
        const user = await tx.user.findUnique({
          where: { id: userId },
          select: {
            id: true,
            coinBalance: true,
            datingProfile: {
              select: {
                datingTier: true,
                datingTierExpiresAt: true,
              },
            },
          },
        });

        if (!user) {
          throw new Error('User not found');
        }

        if (user.coinBalance < coinCost) {
          return { insufficientCoins: true, coinBalance: user.coinBalance };
        }

        const now = new Date();
        const currentExpiry = user.datingProfile?.datingTierExpiresAt;
        const activeStart = currentExpiry && currentExpiry > now ? currentExpiry : now;
        const nextExpiry = addDays(activeStart, durationDays);

        const updatedUser = await tx.user.update({
          where: { id: userId },
          data: {
            coinBalance: user.coinBalance - coinCost,
            isVip: tier === 'VIP' || tier === 'UNLIMITED',
          },
          select: { coinBalance: true },
        });

        const profile = await tx.datingProfile.upsert({
          where: { userId },
          update: {
            datingTier: tier,
            datingTierExpiresAt: nextExpiry,
          },
          create: {
            userId,
            datingTier: tier,
            datingTierExpiresAt: nextExpiry,
          },
        });

        await tx.coinTransaction.create({
          data: {
            userId,
            type: CoinTransactionType.USED,
            amount: -coinCost,
            description: `Dating ${tier} upgrade (${duration})`,
            status: 'COMPLETED',
            metadata: {
              scope: 'dating-upgrade',
              tier,
              duration,
              coinCost,
              expiresAt: nextExpiry.toISOString(),
            },
          },
        });

        return {
          insufficientCoins: false,
          coinBalance: updatedUser.coinBalance,
          tier: profile.datingTier,
          expiresAt: profile.datingTierExpiresAt,
        };
      });

      if (result.insufficientCoins) {
        res.status(400).json({
          success: false,
          message: 'Insufficient coins',
          data: {
            requiredCoins: coinCost,
            currentCoins: result.coinBalance,
          },
        });
        return;
      }

      res.json({
        success: true,
        message: 'Dating plan upgraded successfully',
        data: {
          tier: result.tier,
          expiresAt: result.expiresAt,
          coinBalance: result.coinBalance,
        },
      });
    } catch (error) {
      console.error('Purchase dating upgrade error:', error);
      res.status(500).json({ success: false, message: 'Failed to purchase upgrade' });
    }
  };

  uploadPublicPhoto = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;

      if (!req.file) {
        res.status(400).json({ success: false, message: 'No file uploaded' });
        return;
      }

      const profile = await prisma.datingProfile.findUnique({ where: { userId } });
      const currentPhotos = profile?.publicPhotos ?? [];

      if (currentPhotos.length >= 5) {
        res.status(400).json({ success: false, message: 'Maximum 6 avatars total (1 main + 5 additional)' });
        return;
      }

      const filePath: string = (req.file as unknown as { key?: string; path?: string }).key
        ?? req.file.filename
        ?? req.file.path;

      const updated = await prisma.datingProfile.upsert({
        where: { userId },
        update: { publicPhotos: { push: filePath } },
        create: { userId, publicPhotos: [filePath] },
      });

      res.json({ success: true, data: { publicPhotos: updated.publicPhotos } });
    } catch (error) {
      console.error('Upload public photo error:', error);
      res.status(500).json({ success: false, message: 'Failed to upload public photo' });
    }
  };

  deletePublicPhoto = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { index } = req.params as { index: string };
      const idx = parseInt(index, 10);

      const profile = await prisma.datingProfile.findUnique({ where: { userId } });
      if (!profile) {
        res.status(404).json({ success: false, message: 'Dating profile not found' });
        return;
      }

      const photos = [...profile.publicPhotos];
      if (idx < 0 || idx >= photos.length) {
        res.status(400).json({ success: false, message: 'Invalid photo index' });
        return;
      }

      const photoToDelete = photos[idx];
      if (isStorageObjectKey(photoToDelete)) {
        await StorageService.deleteFile(photoToDelete);
      }

      photos.splice(idx, 1);
      const updated = await prisma.datingProfile.update({
        where: { userId },
        data: { publicPhotos: photos },
      });

      res.json({ success: true, data: { publicPhotos: updated.publicPhotos } });
    } catch (error) {
      console.error('Delete public photo error:', error);
      res.status(500).json({ success: false, message: 'Failed to delete public photo' });
    }
  };

  uploadPrivatePhoto = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;

      if (!req.file) {
        res.status(400).json({ success: false, message: 'No file uploaded' });
        return;
      }

      const album = await prisma.privateAlbum.findUnique({ where: { userId } });
      const currentPhotos = album?.photos ?? [];

      if (currentPhotos.length >= 9) {
        res.status(400).json({ success: false, message: 'Maximum 9 private photos allowed' });
        return;
      }

      // Use original file path from multer / S3 upload
      const filePath: string = (req.file as unknown as { key?: string; path?: string }).key
        ?? req.file.filename
        ?? req.file.path;

      const updated = await prisma.privateAlbum.upsert({
        where: { userId },
        update: { photos: { push: filePath } },
        create: { userId, photos: [filePath] },
      });

      res.json({ success: true, data: updated });
    } catch (error) {
      console.error('Upload private photo error:', error);
      res.status(500).json({ success: false, message: 'Failed to upload photo' });
    }
  };

  deletePrivatePhoto = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { index } = req.params as { index: string };
      const idx = parseInt(index, 10);

      const album = await prisma.privateAlbum.findUnique({ where: { userId } });
      if (!album) {
        res.status(404).json({ success: false, message: 'Private album not found' });
        return;
      }

      const photos = [...album.photos];
      if (idx < 0 || idx >= photos.length) {
        res.status(400).json({ success: false, message: 'Invalid photo index' });
        return;
      }

      const photoToDelete = photos[idx];
      if (isStorageObjectKey(photoToDelete)) {
        await StorageService.deleteFile(photoToDelete);
      }

      photos.splice(idx, 1);
      const updated = await prisma.privateAlbum.update({
        where: { userId },
        data: { photos },
      });

      res.json({ success: true, data: updated });
    } catch (error) {
      console.error('Delete private photo error:', error);
      res.status(500).json({ success: false, message: 'Failed to delete photo' });
    }
  };

  requestPrivateAlbumAccess = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const requesterId = req.user!.id;
      const { userId: ownerId } = req.params as { userId: string };
      const { message } = req.body as { message?: string };

      if (requesterId === ownerId) {
        res.status(400).json({ success: false, message: 'Cannot request own album' });
        return;
      }

      const album = await prisma.privateAlbum.findFirst({ where: { userId: ownerId } });
      if (!album) {
        res.status(404).json({ success: false, message: 'This user has no private album' });
        return;
      }

      const existing = await prisma.privateAlbumAccessRequest.findUnique({
        where: { albumId_requesterId: { albumId: album.id, requesterId } },
      });

      if (existing) {
        res.status(409).json({ success: false, message: 'Request already exists', data: existing });
        return;
      }

      const accessRequest = await prisma.privateAlbumAccessRequest.create({
        data: {
          albumId: album.id,
          requesterId,
          ownerId,
          ...(message !== undefined ? { message } : {}),
        },
      });

      res.json({ success: true, data: accessRequest });
    } catch (error) {
      console.error('Request album access error:', error);
      res.status(500).json({ success: false, message: 'Failed to request album access' });
    }
  };

  respondPrivateAlbumAccess = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { requestId } = req.params as { requestId: string };
      const { action } = req.body as { action: 'ACCEPTED' | 'DENIED' };

      if (!['ACCEPTED', 'DENIED'].includes(action)) {
        res.status(400).json({ success: false, message: 'Action must be ACCEPTED or DENIED' });
        return;
      }

      const accessRequest = await prisma.privateAlbumAccessRequest.findFirst({
        where: { id: requestId },
      });

      if (!accessRequest || accessRequest.ownerId !== userId) {
        res.status(404).json({ success: false, message: 'Request not found' });
        return;
      }

      const updated = await prisma.privateAlbumAccessRequest.update({
        where: { id: accessRequest.id },
        data: { status: action, respondedAt: new Date() },
      });

      res.json({ success: true, data: updated });
    } catch (error) {
      console.error('Respond album access error:', error);
      res.status(500).json({ success: false, message: 'Failed to respond to album access request' });
    }
  };

  getPrivateAlbumAccessRequests = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { type = 'received' } = req.query as { type?: string };

      const where =
        type === 'sent'
          ? { requesterId: userId }
          : { ownerId: userId, status: 'PENDING' as const };

      const requests = await prisma.privateAlbumAccessRequest.findMany({
        where,
        include: {
          requester: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      res.json({ success: true, data: requests });
    } catch (error) {
      console.error('Get album access requests error:', error);
      res.status(500).json({ success: false, message: 'Failed to get access requests' });
    }
  };
}
