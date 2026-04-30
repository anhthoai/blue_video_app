import { Prisma, PrismaClient } from '@prisma/client';

const CONTENT_PROTECTION_KEY = 'contentProtectionEnabled';
const FREE_COMMUNITY_POST_BONUS_COINS_KEY = 'freeCommunityPostBonusCoins';
const FREE_VIDEO_BONUS_COINS_KEY = 'freeVideoBonusCoins';
const TRUE_VALUES = new Set(['1', 'true', 'yes', 'on']);

export type PublicAppSettings = {
  contentProtectionEnabled: boolean;
  freeCommunityPostBonusCoins: number;
  freeVideoBonusCoins: number;
  updatedAt: string | null;
};

export type PublicAppSettingsUpdate = {
  contentProtectionEnabled?: boolean;
  freeCommunityPostBonusCoins?: number;
  freeVideoBonusCoins?: number;
};

export class AppSettingsStorageUnavailableError extends Error {
  constructor() {
    super(
      'App settings storage is not available on this database. Create the public.app_settings table or grant schema permissions.',
    );
    this.name = 'AppSettingsStorageUnavailableError';
  }
}

function parseBooleanSetting(
  value: string | null | undefined,
  fallback: boolean,
): boolean {
  if (value == null) {
    return fallback;
  }

  return TRUE_VALUES.has(value.trim().toLowerCase());
}

function parseIntegerSetting(
  value: string | null | undefined,
  fallback: number,
): number {
  if (value == null) {
    return fallback;
  }

  const parsedValue = Number.parseInt(value.trim(), 10);
  if (!Number.isFinite(parsedValue) || parsedValue < 0) {
    return fallback;
  }

  return parsedValue;
}

function isAppSettingsStorageUnavailable(error: unknown): boolean {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return error.code === 'P2021';
  }

  const message = error instanceof Error ? error.message.toLowerCase() : '';

  return (
    message.includes('permission denied for schema public') ||
    (message.includes('app_settings') && message.includes('does not exist')) ||
    (message.includes('relation') &&
      message.includes('app_settings') &&
      message.includes('does not exist'))
  );
}

export class AppSettingsService {
  constructor(private readonly prisma: PrismaClient) {}

  private get defaultContentProtectionEnabled(): boolean {
    return parseBooleanSetting(process.env['CONTENT_PROTECTION_ENABLED'], false);
  }

  private get defaultFreeCommunityPostBonusCoins(): number {
    return parseIntegerSetting(process.env['FREE_COMMUNITY_POST_BONUS_COINS'], 0);
  }

  private get defaultFreeVideoBonusCoins(): number {
    return parseIntegerSetting(process.env['FREE_VIDEO_BONUS_COINS'], 0);
  }

  private get defaultPublicSettings(): PublicAppSettings {
    return {
      contentProtectionEnabled: this.defaultContentProtectionEnabled,
      freeCommunityPostBonusCoins: this.defaultFreeCommunityPostBonusCoins,
      freeVideoBonusCoins: this.defaultFreeVideoBonusCoins,
      updatedAt: null,
    };
  }

  async getPublicSettings(): Promise<PublicAppSettings> {
    try {
      const settings = await this.prisma.appSetting.findMany({
        where: {
          key: {
            in: [
              CONTENT_PROTECTION_KEY,
              FREE_COMMUNITY_POST_BONUS_COINS_KEY,
              FREE_VIDEO_BONUS_COINS_KEY,
            ],
          },
        },
      });
      const settingsByKey = new Map(settings.map((setting) => [setting.key, setting]));
      const updatedAt = settings.reduce<Date | null>((latest, setting) => {
        if (latest == null || setting.updatedAt > latest) {
          return setting.updatedAt;
        }

        return latest;
      }, null);

      return {
        contentProtectionEnabled: parseBooleanSetting(
          settingsByKey.get(CONTENT_PROTECTION_KEY)?.value,
          this.defaultContentProtectionEnabled,
        ),
        freeCommunityPostBonusCoins: parseIntegerSetting(
          settingsByKey.get(FREE_COMMUNITY_POST_BONUS_COINS_KEY)?.value,
          this.defaultFreeCommunityPostBonusCoins,
        ),
        freeVideoBonusCoins: parseIntegerSetting(
          settingsByKey.get(FREE_VIDEO_BONUS_COINS_KEY)?.value,
          this.defaultFreeVideoBonusCoins,
        ),
        updatedAt: updatedAt?.toISOString() ?? null,
      };
    } catch (error) {
      if (!isAppSettingsStorageUnavailable(error)) {
        throw error;
      }

      console.warn(
        '⚠️ App settings storage unavailable, falling back to CONTENT_PROTECTION_ENABLED.',
      );

      return this.defaultPublicSettings;
    }
  }

  async updateContentProtectionEnabled(
    enabled: boolean,
  ): Promise<PublicAppSettings> {
    return this.updatePublicSettings({
      contentProtectionEnabled: enabled,
    });
  }

  async updatePublicSettings(
    updates: PublicAppSettingsUpdate,
  ): Promise<PublicAppSettings> {
    const operations: Prisma.PrismaPromise<unknown>[] = [];

    if (updates.contentProtectionEnabled !== undefined) {
      operations.push(
        this.prisma.appSetting.upsert({
          where: { key: CONTENT_PROTECTION_KEY },
          update: {
            value: String(updates.contentProtectionEnabled),
          },
          create: {
            key: CONTENT_PROTECTION_KEY,
            value: String(updates.contentProtectionEnabled),
          },
        }),
      );
    }

    if (updates.freeCommunityPostBonusCoins !== undefined) {
      operations.push(
        this.prisma.appSetting.upsert({
          where: { key: FREE_COMMUNITY_POST_BONUS_COINS_KEY },
          update: {
            value: String(updates.freeCommunityPostBonusCoins),
          },
          create: {
            key: FREE_COMMUNITY_POST_BONUS_COINS_KEY,
            value: String(updates.freeCommunityPostBonusCoins),
          },
        }),
      );
    }

    if (updates.freeVideoBonusCoins !== undefined) {
      operations.push(
        this.prisma.appSetting.upsert({
          where: { key: FREE_VIDEO_BONUS_COINS_KEY },
          update: {
            value: String(updates.freeVideoBonusCoins),
          },
          create: {
            key: FREE_VIDEO_BONUS_COINS_KEY,
            value: String(updates.freeVideoBonusCoins),
          },
        }),
      );
    }

    if (operations.length === 0) {
      return this.getPublicSettings();
    }

    try {
      await this.prisma.$transaction(operations);
      return this.getPublicSettings();
    } catch (error) {
      if (!isAppSettingsStorageUnavailable(error)) {
        throw error;
      }

      throw new AppSettingsStorageUnavailableError();
    }
  }
}