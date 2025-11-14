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
  videoPreview?: string;
  folderSlug?: string;
  url: string;
}

interface UlozFolderFile {
  slug: string;
  name: string;
  size: number;
  type: string;
  url: string;
  description?: string;
  isFolder: boolean;
  extension?: string;
  contentType?: string;
  childCount?: number;
}

interface UlozStreamLinks {
  slowDirectLink?: string;
  quickDirectLink?: string;
}

export class UlozService {
  private client: AxiosInstance;
  private config: UlozConfig;
  private baseUrl: string;
  private sessionToken: string | null = null;
  private rootFolderSlug: string | null = null;
  private streamCache: Map<string, { url: string; expiresAt: number }> = new Map();

  constructor() {
    this.config = {
      username: process.env['ULOZ_USERNAME'] || '',
      password: process.env['ULOZ_PASSWORD'] || '',
      apiKey: process.env['ULOZ_API_KEY'] || '',
      baseUrl: process.env['ULOZ_BASE_URL'] || 'https://apis.uloz.to',
    };
    
    this.baseUrl = this.config.baseUrl;

    console.log('🔧 UlozService initialized:');
    console.log('   Base URL:', this.config.baseUrl);
    console.log('   Username:', this.config.username ? '✓ set' : '✗ missing');
    console.log('   Password:', this.config.password ? '✓ set' : '✗ missing');
    console.log('   API Key:', this.config.apiKey ? '✓ set' : '✗ missing');

    this.client = axios.create({
      baseURL: this.config.baseUrl,
      headers: {
        'X-Auth-Token': this.config.apiKey, // App token
      },
    });
  }

  /**
   * Login to uloz.to and get session token
   */
  private async login(): Promise<string> {
    if (this.sessionToken) {
      return this.sessionToken;
    }

    try {
      console.log('🔐 Logging in to uloz.to...');
      console.log('   Using endpoint: PUT /v6/session');
      console.log('   Username:', this.config.username);
      
      const response = await this.client.put('/v6/session', {
        login: this.config.username,
        password: this.config.password,
      });

      console.log('📦 Login response:', JSON.stringify(response.data, null, 2));

      this.sessionToken = response.data.token_id;
      this.rootFolderSlug = response.data.session?.user?.root_folder_slug;
      
      if (!this.sessionToken) {
        throw new Error('No token received from login response');
      }
      
      console.log('✅ Login successful, user token obtained');
      console.log('   Root folder slug:', this.rootFolderSlug);
      
      // Update client with user session token (different from app token)
      this.client.defaults.headers.common['X-User-Token'] = this.sessionToken;
      
      return this.sessionToken;
    } catch (error: any) {
      console.error('❌ Login failed:', error.response?.data || error.message);
      throw new Error(`Failed to login to uloz.to: ${error.message}`);
    }
  }

  /**
   * Ensure we're logged in before making API calls
   */
  private async ensureLoggedIn(): Promise<void> {
    if (!this.sessionToken) {
      await this.login();
    }
  }

  /**
   * Get the root folder slug for the authenticated user
   */
  async getRootFolderSlug(): Promise<string | null> {
    await this.ensureLoggedIn();
    return this.rootFolderSlug;
  }

  private async fetchFolderFiles(userLogin: string, folderSlug: string): Promise<any[]> {
    const endpoint = `/v8/user/${userLogin}/folder/${folderSlug}/file-list`;
    console.log(`   > Fetching files via ${endpoint}`);

    const response = await this.client.get(endpoint, {
      params: {
        per_page: 200,
      },
    });

    if (!response?.data) {
      return [];
    }

    if (Array.isArray(response.data)) {
      return response.data;
    }
    if (Array.isArray(response.data?.subfolders)) {
      return response.data.subfolders;
    }
    if (Array.isArray(response.data?.items)) {
      return response.data.items;
    }
    if (Array.isArray(response.data?.files)) {
      return response.data.files;
    }
    if (response.data?.data && Array.isArray(response.data.data)) {
      return response.data.data;
    }

    return [];
  }

  private async fetchFolderFolders(userLogin: string, folderSlug: string): Promise<any[]> {
    const endpoint = `/v9/user/${userLogin}/folder/${folderSlug}/folder-list`;
    console.log(`   > Fetching subfolders via ${endpoint}`);

    const response = await this.client.get(endpoint, {
      params: {
        per_page: 200,
      },
    });

    if (!response?.data) {
      return [];
    }

    console.log(
      `     ↳ folder-list keys: ${Object.keys(response.data || {}).join(', ')}`
    );

    if (response.data?.subfolders && !Array.isArray(response.data.subfolders)) {
      console.log(
        `     ↳ subfolders type: ${typeof response.data.subfolders}, entries: ${Object.keys(response.data.subfolders || {}).length}`
      );
    } else if (Array.isArray(response.data?.subfolders)) {
      console.log(`     ↳ subfolders array length: ${response.data.subfolders.length}`);
      if (response.data.subfolders.length > 0) {
        console.log(
          `       Example subfolder: ${JSON.stringify(response.data.subfolders[0], null, 2)}`
        );
      }
      return response.data.subfolders;
    }

    if (Array.isArray(response.data)) {
      return response.data;
    }
    if (Array.isArray(response.data?.items)) {
      return response.data.items;
    }
    if (Array.isArray(response.data?.folders)) {
      return response.data.folders;
    }
    if (response.data?.data && Array.isArray(response.data.data)) {
      return response.data.data;
    }

    return [];
  }

  /**
   * Extract slug from uloz.to URL or return as-is if already a slug
   */
  private extractSlug(urlOrSlug: string): string {
    // If it starts with /file/ or /folder/, extract the slug part
    if (urlOrSlug.startsWith('/file/') || urlOrSlug.startsWith('/folder/')) {
      const parts = urlOrSlug.split('/');
      // parts[0] is empty, parts[1] is 'file' or 'folder', parts[2] is the slug
      const slugWithExtra = parts[2];
      if (parts.length >= 3 && slugWithExtra) {
        const withoutQuery = slugWithExtra.split('?')[0];
        if (withoutQuery) {
          const slugPart = withoutQuery.split('#')[0];
          if (slugPart) {
            return slugPart;
          }
        }
      }
    }
    
    // If it's already a slug (no URL pattern and no slashes), return as-is
    if (!urlOrSlug.includes('uloz.to') && !urlOrSlug.includes('http') && !urlOrSlug.includes('/')) {
      return urlOrSlug;
    }
    
    // Example URLs:
    // https://uloz.to/file/abc123xyz
    // https://uloz.to/folder/abc123xyz
    const match = urlOrSlug.match(/uloz\.to\/(file|folder)\/([^/?#]+)/);
    if (match && match[2]) {
      return match[2];
    }
    
    // Try to extract just the slug from the URL
    const parts = urlOrSlug.split('/');
    const fileOrFolder = parts.findIndex(p => p === 'file' || p === 'folder');
    if (fileOrFolder >= 0) {
      const slugPart = parts[fileOrFolder + 1];
      if (slugPart) {
        const withoutQuery = slugPart.split('?')[0];
        if (withoutQuery) {
          const withoutFragment = withoutQuery.split('#')[0];
          if (withoutFragment) {
            return withoutFragment;
          }
        }
      }
    }
    
    throw new Error('Invalid uloz.to URL or slug');
  }

  /**
   * Detect if a slug/URL is a file or folder
   */
  async detectType(urlOrSlug: string): Promise<'file' | 'folder'> {
    try {
      await this.ensureLoggedIn();
      
      const slug = this.extractSlug(urlOrSlug);
      
      console.log('🔍 Detecting type for slug:', slug);
      
      // Try to get as file first
      try {
        const fileResponse = await this.client.get(`/v7/file/${slug}/private`);
        if (fileResponse.data && fileResponse.data.slug) {
          console.log('   ✅ Detected as FILE');
          return 'file';
        }
      } catch (fileError: any) {
        // If file returns 404, try as folder
        if (fileError.response?.status === 404) {
          console.log('   File not found (404), trying as folder...');
          
          // Try different folder endpoints
          const folderEndpoints = [
            `/v8/user/${this.config.username}/folder/${slug}/file-list`,
            `/v8/folder/${slug}/file-list`,
            `/v8/user/${this.config.username}/folders/${slug}/files`,
          ];
          
          for (const endpoint of folderEndpoints) {
            try {
              console.log(`   Trying folder endpoint: ${endpoint}`);
              const folderResponse = await this.client.get(endpoint);
              
              if (folderResponse.data && (folderResponse.data.items || folderResponse.data.files || folderResponse.data)) {
                console.log(`   ✅ Detected as FOLDER (using ${endpoint})`);
                return 'folder';
              }
            } catch (folderError: any) {
              console.log(`   Folder endpoint ${endpoint} failed: ${folderError.response?.status || folderError.message}`);
              // Continue to next endpoint
            }
          }
          
          // If all folder endpoints fail, default to file (will throw error later)
          console.log('   All folder endpoints failed, defaulting to file');
          return 'file';
        } else {
          // If file error is not 404, it might be a different issue
          console.log(`   File endpoint returned ${fileError.response?.status}, defaulting to file`);
          return 'file';
        }
      }
      
      // Default to file if detection fails
      return 'file';
    } catch (error) {
      console.error('Error detecting type:', error);
      // Default to file
      return 'file';
    }
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
      await this.ensureLoggedIn();
      
      const { userLogin, folderSlug } = this.extractFolderInfo(folderUrl);
      
      console.log(`📁 Getting folder contents for: ${folderSlug} (user: ${userLogin})`);

      const [files, folders] = await Promise.all([
        this.fetchFolderFiles(userLogin, folderSlug),
        this.fetchFolderFolders(userLogin, folderSlug).catch(error => {
          if (error?.response?.status === 404) {
            return [];
          }
          throw error;
        }),
      ]);

      console.log(
        `   > files count: ${files.length}, folders count: ${Array.isArray(folders) ? folders.length : 'n/a'}`
      );

      const entries: UlozFolderFile[] = [];

      for (const file of files) {
        if (!file) continue;

        const slug = file.slug || file.id || file.file_slug;
        const rawName = file.name || file.filename || file.file_name || file.title || slug;
        const normalizedName = rawName?.trim() || slug;
        const size = Number(file.size || file.filesize || 0);
        const rawType = (file.type || file.kind || file.contentType || file.content_type || '').toString().toLowerCase();
        const extension = this.extractExtension(normalizedName);
        const url = file.url || file.file_url || `https://uloz.to/file/${slug}`;

        const entry: UlozFolderFile = {
          slug,
          name: normalizedName,
          size,
          type: rawType || 'file',
          url,
          description: file.description,
          isFolder: false,
          extension: extension || '',
          contentType: (file.content_type || file.mime_type || file.contentType || '').toString().toLowerCase() || undefined,
          childCount: 0,
        };

        if (!extension) {
          delete entry.extension;
        }

        entries.push(entry);
        console.log(`       ↳ added file entry ${slug}`);
      }

      for (const folder of folders) {
        if (!folder) continue;

        const slug = folder.slug || folder.id || folder.folder_slug;
        if (!slug) continue;

        const rawName = folder.name || folder.title || slug;
        const normalizedName = rawName?.trim() || slug;

        const entry: UlozFolderFile = {
          slug,
          name: normalizedName,
          size: Number(folder.size || folder.total_size || 0),
          type: 'folder',
          url: `https://uloz.to/folder/${slug}`,
          description: folder.description,
          isFolder: true,
          extension: '',
          contentType: (folder.content_type || folder.contentType || '').toString().toLowerCase() || undefined,
          childCount: folder.children_count || folder.folder_count || folder.subfolders_count || 0,
        };

        delete entry.extension;

        entries.push(entry);
        console.log(`       ↳ added folder entry ${slug}`);
      }

      console.log(`   ✅ Aggregated ${entries.length} item(s) from API`);

      return entries;
    } catch (error: any) {
      const status = error?.response?.status;
      const code = error?.response?.data?.error ?? error?.response?.data?.code;
      const messagePayload = error?.response?.data || error.message;

      console.error('❌ Error getting folder contents:', messagePayload);

      const wrappedError: any = new Error(`Failed to get folder contents: ${messagePayload}`);
      if (status) {
        wrappedError.status = status;
      }
      if (code !== undefined) {
        wrappedError.code = code;
      }
      throw wrappedError;
    }
  }

  /**
   * Get file information
   */
  async getFileInfo(fileUrlOrSlug: string): Promise<UlozFile> {
    try {
      await this.ensureLoggedIn();
      
      const fileSlug = this.extractSlug(fileUrlOrSlug);
      
      console.log('🔍 Getting file info for slug:', fileSlug);
      console.log('🔑 Using endpoint:', `${this.baseUrl}/v7/file/${fileSlug}/private`);

      const response = await this.client.get(`/v7/file/${fileSlug}/private`);

      console.log('✅ File info response:', JSON.stringify(response.data, null, 2));
      
      const fileData = response.data;
      
      // Get full filename
      const fullName = fileData.name || fileData.name_sanitized || fileData.filename || fileData.title || 'unknown';

      // Extract duration from format object (in seconds)
      const duration = fileData.format?.duration || fileData.duration || null;
      
      // Extract thumbnail from preview_info
      const thumbnail = fileData.preview_info?.small_image || 
                       fileData.preview_info?.large_image || 
                       fileData.thumbnail || 
                       fileData.thumbnailUrl || 
                       null;
      
      // Extract video preview (animated preview)
      const videoPreview = fileData.preview_info?.video || null;
      
      // Extract folder slug
      const folderSlug = fileData.folder_slug || null;

      return {
        slug: fileSlug,
        name: fullName, // Keep full filename with extension
        extension: fileData.extension || this.extractExtension(fullName),
        size: fileData.filesize || fileData.size || 0, // uloz.to uses 'filesize', not 'size'
        contentType: fileData.content_type || fileData.contentType || fileData.type || 'video/mp4',
        description: fileData.description,
        duration: duration,
        thumbnail: thumbnail,
        videoPreview: videoPreview,
        folderSlug: folderSlug,
        url: fileUrlOrSlug.includes('http') ? fileUrlOrSlug : `https://uloz.to/file/${fileSlug}`,
      };
    } catch (error: any) {
      console.error('❌ Error getting file info:');
      console.error('   Status:', error.response?.status);
      console.error('   Data:', JSON.stringify(error.response?.data, null, 2));
      console.error('   Message:', error.message);
      console.error('   URL:', error.config?.url);
      console.error('   Auth header present:', !!error.config?.headers?.Authorization);
      throw new Error(`Failed to get file info: ${error.message}`);
    }
  }

  /**
   * Get download/stream links for a file
   */
  async getStreamLinks(fileSlug: string, attempt: number = 0): Promise<UlozStreamLinks> {
    try {
      await this.ensureLoggedIn();
      
      console.log('🎬 Getting stream URL for file slug:', fileSlug);
      console.log('   Endpoint: POST /v5/file/download-link/vipdata');
      
      const response = await this.client.post(`/v5/file/download-link/vipdata`, {
        file_slug: fileSlug,
        user_login: this.config.username,
        device_id: 'uloz-to',
        download_type: 'normal',
      });

      console.log('✅ Stream URL response:', JSON.stringify(response.data, null, 2));

      const data = response.data;

      return {
        slowDirectLink: data.slow_direct_link || data.downloadLink || data.link,
        quickDirectLink: data.quick_direct_link || data.streamLink || data.link,
      };
    } catch (error: any) {
      const status = error?.response?.status;

      if (status === 401 && attempt < 1) {
        console.warn('⚠️  uloz.to session appears invalid. Re-authenticating...');
        this.sessionToken = null;
        delete this.client.defaults.headers.common['X-User-Token'];
        await this.ensureLoggedIn();
        return this.getStreamLinks(fileSlug, attempt + 1);
      }

      console.error('❌ Error getting stream links:', error.response?.data || error.message);
      throw new Error(`Failed to get stream links: ${error.message}`);
    }
  }

  /**
   * Get stream URL for a file (public method)
   */
  async getStreamUrl(fileUrl: string): Promise<string | null> {
    try {
      const fileSlug = this.extractSlug(fileUrl);
      const cached = this.streamCache.get(fileSlug);
      const now = Date.now();
      if (cached && cached.expiresAt > now) {
        return cached.url;
      }

      const links = await this.getStreamLinks(fileSlug);
      
      // Prefer quick direct link (faster streaming)
      const url = links.quickDirectLink || links.slowDirectLink || null;

      if (url) {
        const expiresAt = now + 15 * 60 * 1000; // cache for 15 minutes
        this.streamCache.set(fileSlug, { url, expiresAt });
      }

      return url;
    } catch (error) {
      console.error('Error getting stream URL:', error);
      return null;
    }
  }

  /**
   * Import folder as episodes with subtitles
   * Returns array of file information that can be used to create episodes
   */
  async importFolderAsEpisodes(folderUrl: string): Promise<Array<UlozFile & { 
    suggestedEpisodeNumber?: number;
    subtitles?: Array<{
      slug: string;
      name: string;
      url: string;
      language: string;
      label: string;
    }>;
  }>> {
    try {
      const files = await this.getFolderContents(folderUrl);

      // Filter video files and subtitle files
      const videoFiles = files.filter(file => 
        file.type.includes('video') || 
        this.isVideoExtension(this.extractExtension(file.name))
      );

      const subtitleFiles = files.filter(file =>
        this.isSubtitleExtension(this.extractExtension(file.name))
      );

      console.log(`   Found ${videoFiles.length} video files and ${subtitleFiles.length} subtitle files`);

      // Get detailed info for each video file and match subtitles
      const episodePromises = videoFiles.map(async (file, index) => {
        try {
          // Use slug instead of url to avoid double /file/ in the path
          const fileInfo = await this.getFileInfo(file.slug);
          const episodeNumber = this.extractEpisodeNumber(file.name) || index + 1;

          // Find matching subtitle files for this video
          const videoBaseName = this.getBaseFilename(file.name);
          const matchingSubtitles = subtitleFiles
            .filter(subtitleFile => {
              const subtitleBaseName = this.getBaseFilename(subtitleFile.name);
              return videoBaseName === subtitleBaseName;
            })
            .map(subtitleFile => {
              const langInfo = this.extractSubtitleLanguage(subtitleFile.name);
              return {
                slug: subtitleFile.slug,
                name: subtitleFile.name,
                url: `https://uloz.to/file/${subtitleFile.slug}`, // Use simple format for subtitles
                language: langInfo.code,
                label: langInfo.label,
              };
            });

          if (matchingSubtitles.length > 0) {
            console.log(`   📝 Found ${matchingSubtitles.length} subtitle(s) for: ${file.name}`);
            matchingSubtitles.forEach(sub => {
              console.log(`      - ${sub.label} (${sub.language})`);
            });
          }

          return {
            ...fileInfo,
            suggestedEpisodeNumber: episodeNumber,
            subtitles: matchingSubtitles,
          };
        } catch (error) {
          console.error(`Error getting info for file ${file.name}:`, error);
          return null;
        }
      });

      const episodes = await Promise.all(episodePromises);
      return episodes.filter(ep => ep !== null) as Array<UlozFile & { 
        suggestedEpisodeNumber?: number;
        subtitles?: Array<{
          slug: string;
          name: string;
          url: string;
          language: string;
          label: string;
        }>;
      }>;
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
   * Check if extension is a subtitle format
   */
  private isSubtitleExtension(ext: string): boolean {
    const subtitleExtensions = ['srt', 'vtt', 'ass', 'ssa'];
    return subtitleExtensions.includes(ext.toLowerCase());
  }

  /**
   * Extract language code from subtitle filename
   * Supports formats: filename.eng.srt, filename.tha.srt, filename.srt (default to eng)
   */
  private extractSubtitleLanguage(filename: string): { code: string; label: string } {
    const languageMap: { [key: string]: string } = {
      // Common languages
      'eng': 'English',
      'tha': 'Thai',
      'jpn': 'Japanese',
      'kor': 'Korean',
      'chi': 'Chinese (Simplified)',
      'zho': 'Chinese (Traditional)',
      'spa': 'Spanish',
      'fre': 'French',
      'fra': 'French',
      'ger': 'German',
      'deu': 'German',
      'ita': 'Italian',
      'por': 'Portuguese',
      'rus': 'Russian',
      'ara': 'Arabic',
      'hin': 'Hindi',
      'vie': 'Vietnamese',
      
      // European languages
      'dut': 'Dutch',
      'nld': 'Dutch',
      'pol': 'Polish',
      'cze': 'Czech',
      'ces': 'Czech',
      'hun': 'Hungarian',
      'gre': 'Greek',
      'ell': 'Greek',
      'rum': 'Romanian',
      'ron': 'Romanian',
      'tur': 'Turkish',
      'swe': 'Swedish',
      'nor': 'Norwegian',
      'dan': 'Danish',
      'fin': 'Finnish',
      'ukr': 'Ukrainian',
      
      // Asian languages
      'fil': 'Filipino',
      'ind': 'Indonesian',
      'may': 'Malay',
      'msa': 'Malay',
      'bur': 'Burmese',
      'mya': 'Burmese',
      'khm': 'Khmer',
      'lao': 'Lao',
      
      // Other
      'heb': 'Hebrew',
      'per': 'Persian',
      'fas': 'Persian',
      'ben': 'Bengali',
      'tam': 'Tamil',
      'tel': 'Telugu',
      'urd': 'Urdu',
      'slo': 'Slovak',
      'slk': 'Slovak',
      'bul': 'Bulgarian',
      'hrv': 'Croatian',
      'srp': 'Serbian',
      'slv': 'Slovenian',
      'est': 'Estonian',
      'lav': 'Latvian',
      'lit': 'Lithuanian',
      'ice': 'Icelandic',
      'isl': 'Icelandic',
      'mal': 'Malayalam',
      'kan': 'Kannada',
      'mar': 'Marathi',
      'guj': 'Gujarati',
      'pan': 'Punjabi',
      'ori': 'Odia',
      'asm': 'Assamese',
      'nep': 'Nepali',
      'sin': 'Sinhala',
      'mon': 'Mongolian',
      'tib': 'Tibetan',
      'bod': 'Tibetan',
      'geo': 'Georgian',
      'kat': 'Georgian',
      'arm': 'Armenian',
      'hye': 'Armenian',
      'aze': 'Azerbaijani',
      'kaz': 'Kazakh',
      'uzb': 'Uzbek',
      'tgk': 'Tajik',
      'pus': 'Pashto',
      'kur': 'Kurdish',
      'amh': 'Amharic',
      'swa': 'Swahili',
      'hau': 'Hausa',
      'yor': 'Yoruba',
      'zul': 'Zulu',
      'afr': 'Afrikaans',
      'mlt': 'Maltese',
      'glg': 'Galician',
      'cat': 'Catalan',
      'baq': 'Basque',
      'eus': 'Basque',
      'wel': 'Welsh',
      'cym': 'Welsh',
      'gle': 'Irish',
      'sco': 'Scots Gaelic',
      'gla': 'Scots Gaelic',
      'ltz': 'Luxembourgish',
      'mao': 'Maori',
      'mri': 'Maori',
      'haw': 'Hawaiian',
      'smo': 'Samoan',
      'ton': 'Tongan',
      'fij': 'Fijian',
    };

    // Try to find language code before the extension
    // e.g., "filename.eng.srt" or "filename.tha.srt"
    const match = filename.match(/\.([a-z]{3})\.[^.]+$/i);
    
    if (match && match[1]) {
      const code = match[1].toLowerCase();
      return {
        code,
        label: languageMap[code] || code.toUpperCase(),
      };
    }

    // Default to English if no language code found
    return { code: 'eng', label: 'English' };
  }

  /**
   * Get base filename without language code and extension
   * e.g., "video.eng.srt" -> "video"
   */
  private getBaseFilename(filename: string): string {
    // Remove extension(s)
    let base = filename;
    
    // Remove subtitle extension (.srt, .vtt, etc.)
    base = base.replace(/\.(srt|vtt|ass|ssa)$/i, '');
    
    // Remove language code if present (.eng, .tha, etc.)
    base = base.replace(/\.[a-z]{3}$/i, '');
    
    // Remove video extension (.mp4, .mkv, etc.)
    base = base.replace(/\.(mp4|mkv|avi|mov|webm|flv|wmv|m4v)$/i, '');
    
    return base;
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

