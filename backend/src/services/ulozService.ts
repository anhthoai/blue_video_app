import axios, { AxiosInstance } from 'axios';

interface UlozConfig {
  username: string;
  password: string;
  apiKey: string;
  baseUrl: string;
}

interface UlozFile {
  slug: string;
  name: string;
  extension: string;
  size: number;
  contentType: string;
  description?: string;
  duration?: number;
  thumbnail?: string;
  url: string;
}

interface UlozFolderFile {
  slug: string;
  name: string;
  size: number;
  type: string;
  url: string;
  description?: string;
}

interface UlozStreamLinks {
  slowDirectLink?: string;
  quickDirectLink?: string;
}

export class UlozService {
  private client: AxiosInstance;
  private config: UlozConfig;

  constructor() {
    this.config = {
      username: process.env['ULOZ_USERNAME'] || '',
      password: process.env['ULOZ_PASSWORD'] || '',
      apiKey: process.env['ULOZ_API_KEY'] || '',
      baseUrl: process.env['ULOZ_BASE_URL'] || 'https://api.uloz.to',
    };

    const auth = Buffer.from(`${this.config.username}:${this.config.password}`).toString('base64');

    this.client = axios.create({
      baseURL: this.config.baseUrl,
      headers: {
        'Authorization': `Basic ${auth}`,
        'X-Auth-Token': this.config.apiKey,
      },
    });
  }

  /**
   * Extract slug from uloz.to URL
   */
  private extractSlug(url: string): string {
    // Example URLs:
    // https://uloz.to/file/abc123xyz
    // https://uloz.to/folder/abc123xyz
    const match = url.match(/uloz\.to\/(file|folder)\/([^/?]+)/);
    if (!match || !match[2]) {
      throw new Error('Invalid uloz.to URL');
    }
    return match[2];
  }

  /**
   * Extract folder slug and user login from folder URL
   */
  private extractFolderInfo(url: string): { userLogin: string; folderSlug: string } {
    // Example: https://uloz.to/folder/abc123xyz or with user info
    const slug = this.extractSlug(url);
    
    // For now, we'll use the username from config
    // In production, you might need to extract this from the URL or have it configured
    return {
      userLogin: this.config.username,
      folderSlug: slug,
    };
  }

  /**
   * Get folder contents
   */
  async getFolderContents(folderUrl: string): Promise<UlozFolderFile[]> {
    try {
      const { userLogin, folderSlug } = this.extractFolderInfo(folderUrl);

      const response = await this.client.get(
        `/v8/user/${userLogin}/folder/${folderSlug}/file-list`
      );

      if (!response.data || !response.data.items) {
        return [];
      }

      return response.data.items.map((item: any) => ({
        slug: item.slug || item.id,
        name: item.name || item.filename,
        size: item.size || 0,
        type: item.type || item.contentType || 'video',
        url: item.url || `https://uloz.to/file/${item.slug}`,
        description: item.description,
      }));
    } catch (error: any) {
      console.error('Error getting folder contents:', error.response?.data || error.message);
      throw new Error(`Failed to get folder contents: ${error.message}`);
    }
  }

  /**
   * Get file information
   */
  async getFileInfo(fileUrl: string): Promise<UlozFile> {
    try {
      const fileSlug = this.extractSlug(fileUrl);

      const response = await this.client.get(`/v7/file/${fileSlug}/private`);

      const fileData = response.data;

      return {
        slug: fileSlug,
        name: fileData.name || fileData.filename || 'unknown',
        extension: fileData.extension || this.extractExtension(fileData.name),
        size: fileData.size || 0,
        contentType: fileData.contentType || fileData.type || 'video/mp4',
        description: fileData.description,
        duration: fileData.duration,
        thumbnail: fileData.thumbnail || fileData.thumbnailUrl,
        url: fileUrl,
      };
    } catch (error: any) {
      console.error('Error getting file info:', error.response?.data || error.message);
      throw new Error(`Failed to get file info: ${error.message}`);
    }
  }

  /**
   * Get download/stream links for a file
   */
  async getStreamLinks(fileSlug: string): Promise<UlozStreamLinks> {
    try {
      const response = await this.client.get(`/v5/file/download-link/vipdata`, {
        params: {
          slug: fileSlug,
        },
      });

      const data = response.data;

      return {
        slowDirectLink: data.slowDirectLink || data.downloadLink,
        quickDirectLink: data.quickDirectLink || data.streamLink,
      };
    } catch (error: any) {
      console.error('Error getting stream links:', error.response?.data || error.message);
      throw new Error(`Failed to get stream links: ${error.message}`);
    }
  }

  /**
   * Get stream URL for a file (public method)
   */
  async getStreamUrl(fileUrl: string): Promise<string | null> {
    try {
      const fileSlug = this.extractSlug(fileUrl);
      const links = await this.getStreamLinks(fileSlug);
      
      // Prefer quick direct link (faster streaming)
      return links.quickDirectLink || links.slowDirectLink || null;
    } catch (error) {
      console.error('Error getting stream URL:', error);
      return null;
    }
  }

  /**
   * Import folder as episodes
   * Returns array of file information that can be used to create episodes
   */
  async importFolderAsEpisodes(folderUrl: string): Promise<Array<UlozFile & { suggestedEpisodeNumber?: number }>> {
    try {
      const files = await this.getFolderContents(folderUrl);

      // Filter video files
      const videoFiles = files.filter(file => 
        file.type.includes('video') || 
        this.isVideoExtension(this.extractExtension(file.name))
      );

      // Get detailed info for each file and try to extract episode numbers
      const episodePromises = videoFiles.map(async (file, index) => {
        try {
          const fileInfo = await this.getFileInfo(file.url);
          const episodeNumber = this.extractEpisodeNumber(file.name) || index + 1;

          return {
            ...fileInfo,
            suggestedEpisodeNumber: episodeNumber,
          };
        } catch (error) {
          console.error(`Error getting info for file ${file.name}:`, error);
          return null;
        }
      });

      const episodes = await Promise.all(episodePromises);
      return episodes.filter(ep => ep !== null) as Array<UlozFile & { suggestedEpisodeNumber?: number }>;
    } catch (error) {
      console.error('Error importing folder as episodes:', error);
      throw error;
    }
  }

  /**
   * Extract extension from filename
   */
  private extractExtension(filename: string): string {
    const parts = filename.split('.');
    if (parts.length > 1) {
      const ext = parts[parts.length - 1];
      return ext ? ext.toLowerCase() : '';
    }
    return '';
  }

  /**
   * Check if extension is a video format
   */
  private isVideoExtension(ext: string): boolean {
    const videoExtensions = ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v'];
    return videoExtensions.includes(ext.toLowerCase());
  }

  /**
   * Try to extract episode number from filename
   * Supports formats like: E01, e01, Episode 01, ep01, 01, etc.
   */
  private extractEpisodeNumber(filename: string): number | null {
    const patterns = [
      /[Ee]pisode[\s_-]?(\d+)/i,  // Episode 01, episode_01
      /[Ee]p[\s_-]?(\d+)/i,         // Ep01, ep_01
      /[Ee](\d+)/,                  // E01, e01
      /[\s_-](\d{1,3})[\s_-]/,      // _01_, -01-
      /^(\d{1,3})[._-]/,            // 01., 01_
    ];

    for (const pattern of patterns) {
      const match = filename.match(pattern);
      if (match && match[1]) {
        const num = parseInt(match[1], 10);
        if (num > 0 && num < 1000) {
          return num;
        }
      }
    }

    return null;
  }

  /**
   * Validate uloz.to URL
   */
  isValidUrl(url: string): boolean {
    return /uloz\.to\/(file|folder)\/[^/?]+/.test(url);
  }
}

export default new UlozService();

