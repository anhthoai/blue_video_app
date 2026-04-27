import { PrismaClient } from '@prisma/client';

const CONTENT_PROTECTION_KEY = 'contentProtectionEnabled';
const TRUE_VALUES = new Set(['1', 'true', 'yes', 'on']);

export type PublicAppSettings = {
  contentProtectionEnabled: boolean;
  updatedAt: string | null;
};

function parseBooleanSetting(
  value: string | null | undefined,
  fallback: boolean,
): boolean {
  if (value == null) {
    return fallback;
  }

  return TRUE_VALUES.has(value.trim().toLowerCase());
}

export class AppSettingsService {
  constructor(private readonly prisma: PrismaClient) {}

  private get defaultContentProtectionEnabled(): boolean {
    return parseBooleanSetting(process.env['CONTENT_PROTECTION_ENABLED'], false);
  }

  async getPublicSettings(): Promise<PublicAppSettings> {
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
  }

  async updateContentProtectionEnabled(
    enabled: boolean,
  ): Promise<PublicAppSettings> {
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
  }
}