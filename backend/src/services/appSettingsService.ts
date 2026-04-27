import { Prisma, PrismaClient } from '@prisma/client';

const CONTENT_PROTECTION_KEY = 'contentProtectionEnabled';
const TRUE_VALUES = new Set(['1', 'true', 'yes', 'on']);

export type PublicAppSettings = {
  contentProtectionEnabled: boolean;
  updatedAt: string | null;
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

  private get defaultPublicSettings(): PublicAppSettings {
    return {
      contentProtectionEnabled: this.defaultContentProtectionEnabled,
      updatedAt: null,
    };
  }

  async getPublicSettings(): Promise<PublicAppSettings> {
    try {
      const contentProtectionSetting = await this.prisma.appSetting.findUnique({
        where: { key: CONTENT_PROTECTION_KEY },
      });

      return {
        contentProtectionEnabled: parseBooleanSetting(
          contentProtectionSetting?.value,
          this.defaultContentProtectionEnabled,
        ),
        updatedAt: contentProtectionSetting?.updatedAt.toISOString() ?? null,
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
    try {
      const contentProtectionSetting = await this.prisma.appSetting.upsert({
        where: { key: CONTENT_PROTECTION_KEY },
        update: {
          value: String(enabled),
        },
        create: {
          key: CONTENT_PROTECTION_KEY,
          value: String(enabled),
        },
      });

      return {
        contentProtectionEnabled: parseBooleanSetting(
          contentProtectionSetting.value,
          this.defaultContentProtectionEnabled,
        ),
        updatedAt: contentProtectionSetting.updatedAt.toISOString(),
      };
    } catch (error) {
      if (!isAppSettingsStorageUnavailable(error)) {
        throw error;
      }

      throw new AppSettingsStorageUnavailableError();
    };
  }
}