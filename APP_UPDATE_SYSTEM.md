# In-App Update System Documentation

## Overview

The Blue Video app includes an automatic update notification system that checks for new versions and prompts users to download and install updates from your website (onlybl.com).

## ✨ Features

✅ **Automatic Version Checking** - Checks on app startup and resume  
✅ **Optional Updates** - Users can choose "Later" for non-critical updates  
✅ **Force Updates** - Required updates that block app usage  
✅ **Beautiful UI** - Professional update dialog with gradient design  
✅ **Multi-language** - Translated to EN, ZH, JA  
✅ **Direct Download** - Downloads the Android APK inside the app and opens the system installer  
✅ **Release Notes** - Shows what's new in each version  
✅ **Smart Caching** - Checks max once per hour on resume to save bandwidth  
✅ **Persistent Cooldown** - Optional update prompts are snoozed for 24 hours across app restarts  
✅ **Platform-Specific** - Different versions for Android and iOS  

---

## How It Works

### 1. Version Check Flow

```
App opens to Splash Screen
    ↓
Splash checks `/app-version` before routing to Login or Main
  ↓
If optional update was dismissed in the last 24 hours, skip dialog
  ↓
If app later resumes from background, check again only if 1 hour passed
  ↓
Call API: GET /app-version?platform=android&currentVersion=1.0.0
    ↓
Backend compares versions
    ↓
Returns: updateRequired=true/false, forceUpdate=true/false
    ↓
If update required → Show update dialog
    ↓
User clicks "Update Now"
  ↓
Android: app downloads APK in-place and shows progress
  ↓
Android: system install prompt opens
  ↓
iOS: app falls back to external download URL
```

### 2. Version Comparison

The system uses **semantic versioning** (e.g., `1.0.0`):

```
Major.Minor.Patch
  1  . 0  . 0
```

**Comparison Logic:**
- `1.0.0` vs `1.0.1` → Update available (patch update)
- `1.0.0` vs `1.1.0` → Update available (minor update)
- `1.0.0` vs `2.0.0` → Update available (major update)

**Force Update Logic:**
- If `currentVersion < minVersion` → Force update (blocks app)
- If `currentVersion < latestVersion` → Optional update (can skip)

---

## Backend Configuration

### API Endpoint

**URL:** `GET /app-version`

**Query Parameters:**
- `platform` (string) - `android` or `ios`
- `currentVersion` (string) - Current app version (e.g., `1.0.0`)

**Response:**
```json
{
  "success": true,
  "latestVersion": "1.0.1",
  "minVersion": "1.0.0",
  "currentVersion": "1.0.0",
  "updateRequired": true,
  "forceUpdate": false,
  "downloadUrl": "https://onlybl.com/downloads/blue-video-latest.apk",
  "releaseNotes": "Bug fixes and performance improvements",
  "releaseDate": "2025-10-27T00:00:00Z",
  "platform": "android"
}
```

### Environment Variables (`backend/.env`)

```env
# Android Version
ANDROID_LATEST_VERSION=1.0.0
ANDROID_MIN_VERSION=1.0.0
ANDROID_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-latest.apk
ANDROID_RELEASE_NOTES=Initial release with full features
ANDROID_RELEASE_DATE=2025-10-27T00:00:00Z

# iOS Version
IOS_LATEST_VERSION=1.0.0
IOS_MIN_VERSION=1.0.0
IOS_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-latest.ipa
IOS_RELEASE_NOTES=Initial release with full features
IOS_RELEASE_DATE=2025-10-27T00:00:00Z
```

### Updating to a New Version

**Example: Release version 1.0.1**

#### 1. Update `.env` file:

```env
# For optional update (users can skip)
ANDROID_LATEST_VERSION=1.0.1
ANDROID_MIN_VERSION=1.0.0  # Keep old min version
ANDROID_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-v1.0.1.apk
ANDROID_RELEASE_NOTES=• Fixed video player bug\n• Improved chat performance\n• Added new filters
ANDROID_RELEASE_DATE=2025-11-01T00:00:00Z
```

#### 2. For force update (users MUST update):

```env
# Users on version < 1.0.1 will be forced to update
ANDROID_LATEST_VERSION=1.0.1
ANDROID_MIN_VERSION=1.0.1  # ← Set this to force update
ANDROID_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-v1.0.1.apk
ANDROID_RELEASE_NOTES=• Critical security fix\n• Database migration\n• Must update to continue
ANDROID_RELEASE_DATE=2025-11-01T00:00:00Z
```

#### 3. Restart backend:

```bash
cd backend
# Kill existing process
pm2 restart blue-video-api
# Or if running locally:
# Ctrl+C then npm run dev
```

#### 4. Upload APK/IPA to website:

```bash
# Upload new version to your web server
scp blue-video-v1.0.1.apk user@onlybl.com:/var/www/html/downloads/

# Update the "latest" symlink
ssh user@onlybl.com "ln -sf /var/www/html/downloads/blue-video-v1.0.1.apk /var/www/html/downloads/blue-video-latest.apk"
```

---

## Frontend Implementation

### Files Created

1. **`core/services/version_service.dart`**
   - Calls backend API to check for updates
   - Returns `VersionInfo` object with update details
   - Platform detection (Android/iOS)
   - Current version detection from package info

2. **`core/services/app_lifecycle_service.dart`**
  - Owns the shared update coordinator
  - Persists last-check time and optional prompt cooldown
  - Shows update dialog when needed
  - Prevents spam (max 1 check per hour on resume)

3. **`widgets/dialogs/app_update_dialog.dart`**
   - Beautiful update dialog UI
   - Shows version comparison
   - Displays release notes
   - Force update warning (red)
  - "Update Now" and "Later" buttons
  - Downloads Android updates in-app with progress
  - Opens Android system installer after download

### Files Modified

1. **`screens/splash/splash_screen.dart`**
  - Triggers the startup update check before routing to login or main

2. **`screens/main/main_screen.dart`**
  - Registers the lifecycle observer
  - Monitors app resume events only

3. **`core/services/api_service.dart`**
   - Added `checkAppVersion()` method

4. **Localization files** - Added update dialog translations

---

## Update Dialog UI

### Optional Update

```
╔════════════════════════════════════╗
║  🔄  Update Available              ║
╠════════════════════════════════════╣
║                                    ║
║  Current Version    →  Latest Ver  ║
║      1.0.0              1.0.1      ║
║                                    ║
║  What's New:                       ║
║  • Fixed video player bug          ║
║  • Improved chat performance       ║
║  • Added new filters               ║
║                                    ║
║  📅 2025-11-01                     ║
║                                    ║
║         [Later]    [Update Now]    ║
╚════════════════════════════════════╝
```

### Force Update

```
╔════════════════════════════════════╗
║  ⚠️  Update Required               ║
╠════════════════════════════════════╣
║                                    ║
║  Current Version    →  Latest Ver  ║
║      1.0.0              1.0.1      ║
║                                    ║
║  ⚠️ This update is required to     ║
║     continue using the app.        ║
║                                    ║
║  What's New:                       ║
║  • Critical security fix           ║
║  • Database migration              ║
║  • Must update to continue         ║
║                                    ║
║  📅 2025-11-01                     ║
║                                    ║
║              [Update Now]          ║
╚════════════════════════════════════╝
```

**Note:** Force update dialog cannot be dismissed (no "X" or "Later" button).

---

## Usage Examples

### Example 1: Optional Update (Patch)

**Scenario:** Release bug fix version 1.0.1

**Backend `.env`:**
```env
ANDROID_LATEST_VERSION=1.0.1
ANDROID_MIN_VERSION=1.0.0
ANDROID_RELEASE_NOTES=• Fixed video playback issues\n• Improved stability
```

**User Experience:**
1. Opens app
2. Sees "Update Available" dialog
3. Can click "Later" to continue using current version
4. Can click "Update Now" to download new version
5. Dialog won't show again for 24 hours if dismissed

### Example 2: Force Update (Critical)

**Scenario:** Critical security fix or database migration

**Backend `.env`:**
```env
ANDROID_LATEST_VERSION=1.1.0
ANDROID_MIN_VERSION=1.1.0  # ← Force all users to update
ANDROID_RELEASE_NOTES=• CRITICAL SECURITY FIX\n• Database migration required\n• Please update immediately
```

**User Experience:**
1. Opens app
2. Sees "Update Required" dialog with red warning
3. No "Later" button available
4. Cannot dismiss dialog (no back button, no tap outside)
5. MUST click "Update Now" to continue
6. After update, app works normally

### Example 3: No Update Available

**Backend `.env`:**
```env
ANDROID_LATEST_VERSION=1.0.0
ANDROID_MIN_VERSION=1.0.0
```

**User on version 1.0.0:**
- No dialog shown
- App continues normally
- Backend logs: "No update required"

---

## Testing

### Test Optional Update

1. **Set up test:**
   ```env
   # In backend/.env
   ANDROID_LATEST_VERSION=1.0.1
   ANDROID_MIN_VERSION=1.0.0
   ```

2. **Test with app version 1.0.0:**
   - Open app
   - Should see "Update Available" dialog
   - Click "Later" → Dialog dismisses, app continues
   - Click "Update Now" → Browser opens to download URL

3. **Verify:**
   - Backend logs show version check
   - Dialog shows correct versions
   - Release notes display correctly
   - Download URL works

### Test Force Update

1. **Set up test:**
   ```env
   ANDROID_LATEST_VERSION=1.1.0
   ANDROID_MIN_VERSION=1.1.0  # Same as latest = force all
   ```

2. **Test with app version 1.0.0:**
   - Open app
   - Should see "Update Required" with red warning
   - No "Later" button
   - Cannot dismiss dialog
   - Can only click "Update Now"

3. **Verify:**
   - Dialog cannot be dismissed
   - Force update warning shows
   - Back button doesn't close dialog

### Test Check Frequency

1. **Open app** → Version check runs
2. **Close app** (don't force quit)
3. **Reopen within 1 hour** → No version check
4. **Wait 1+ hour and reopen** → Version check runs again

### Test Platform Detection

**Android:**
- App sends `platform=android`
- Receives Android download URL

**iOS:**
- App sends `platform=ios`
- Receives iOS download URL

---

## Download URL Setup

### Hosting APK/IPA Files

#### Option 1: Direct Server Hosting

**Setup:**
```bash
# SSH to your server
ssh user@onlybl.com

# Create downloads directory
sudo mkdir -p /var/www/html/downloads
sudo chown www-data:www-data /var/www/html/downloads

# Upload APK
scp blue-video-v1.0.0.apk user@onlybl.com:/var/www/html/downloads/

# Create "latest" symlink
cd /var/www/html/downloads
sudo ln -s blue-video-v1.0.0.apk blue-video-latest.apk
```

**Access:**
- Direct: `https://onlybl.com/downloads/blue-video-v1.0.0.apk`
- Latest: `https://onlybl.com/downloads/blue-video-latest.apk`

#### Option 2: CDN (Recommended)

**Use Cloudflare R2 or similar:**

```bash
# Upload to R2
aws s3 cp blue-video-v1.0.0.apk s3://your-bucket/downloads/

# Set public read permission
aws s3api put-object-acl --bucket your-bucket --key downloads/blue-video-v1.0.0.apk --acl public-read
```

**Update `.env`:**
```env
ANDROID_DOWNLOAD_URL=https://cdn.onlybl.com/downloads/blue-video-latest.apk
```

#### Option 3: GitHub Releases

**Upload to GitHub:**
1. Create new release in GitHub
2. Attach APK/IPA files
3. Copy download URL

**Update `.env`:**
```env
ANDROID_DOWNLOAD_URL=https://github.com/your-org/blue-video/releases/download/v1.0.1/blue-video.apk
```

---

## Android Installation

### APK Download and Install

When user clicks "Update Now":

1. **Browser opens** download URL
2. **APK downloads** to Downloads folder
3. **User clicks notification** or opens Downloads
4. **Android prompts** "Install unknown app"
5. **User grants permission** (one-time)
6. **Installation begins**
7. **App updates** to new version

### Required Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Allow installation from unknown sources -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:requestLegacyExternalStorage="true"
        android:usesCleartextTraffic="true">
        <!-- Your existing config -->
    </application>
</manifest>
```

### Enable Unknown Sources

**User must enable:**
Settings → Security → Unknown Sources → Enable for browser/Chrome

---

## iOS Installation

### IPA Installation (Requires Profile)

iOS requires apps to be signed and either:
- Distributed via App Store
- Installed via enterprise certificate
- Installed via TestFlight
- Installed via development profile

**For your use case (self-hosted IPA):**

#### Option A: TestFlight (Recommended)

1. Create Apple Developer account ($99/year)
2. Upload IPA to App Store Connect
3. Use TestFlight for distribution
4. Users install via TestFlight app

**Update `.env`:**
```env
IOS_DOWNLOAD_URL=https://testflight.apple.com/join/YOUR_CODE
```

#### Option B: Enterprise Certificate

1. Get Apple Enterprise Developer account ($299/year)
2. Sign IPA with enterprise certificate
3. Host IPA and manifest.plist on HTTPS server
4. Users install via Safari

**Update `.env`:**
```env
IOS_DOWNLOAD_URL=itms-services://?action=download-manifest&url=https://onlybl.com/downloads/manifest.plist
```

#### Option C: Development Profile (Testing Only)

- Limited to 100 devices
- Requires device UDIDs
- Expires every 7 days
- Not suitable for production

---

## Release Process

### Step-by-Step Guide

#### 1. Prepare New Release

```bash
cd mobile-app

# Update version in pubspec.yaml
# version: 1.0.1+2  (1.0.1 = version name, 2 = build number)

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

#### 2. Upload to Server

```bash
# APK
scp build/app/outputs/flutter-apk/app-release.apk user@onlybl.com:/var/www/html/downloads/blue-video-v1.0.1.apk

# Update "latest" symlink
ssh user@onlybl.com "cd /var/www/html/downloads && rm blue-video-latest.apk && ln -s blue-video-v1.0.1.apk blue-video-latest.apk"
```

#### 3. Update Backend Configuration

```bash
# Edit backend/.env
ANDROID_LATEST_VERSION=1.0.1
ANDROID_RELEASE_NOTES=• Fixed video player bug\n• Improved performance\n• UI enhancements
ANDROID_RELEASE_DATE=2025-11-01T00:00:00Z

# Restart backend
pm2 restart blue-video-api
```

#### 4. Verify

```bash
# Test API endpoint
curl "http://localhost:3000/app-version?platform=android&currentVersion=1.0.0"

# Should return:
# {
#   "updateRequired": true,
#   "latestVersion": "1.0.1",
#   ...
# }
```

#### 5. Test in App

1. Open app with version 1.0.0
2. Should see update dialog
3. Click "Update Now"
4. Should download new APK
5. Install and verify version 1.0.1

---

## Translations

### Update Dialog Translations

| Key | English | 中文 | 日本語 |
|-----|---------|------|--------|
| updateAvailable | Update Available | 有可用更新 | アップデート可能 |
| updateRequired | Update Required | 需要更新 | アップデート必須 |
| currentVersion | Current Version | 当前版本 | 現在のバージョン |
| latestVersion | Latest Version | 最新版本 | 最新バージョン |
| whatsNew | What's New | 更新内容 | 新機能 |
| updateNow | Update Now | 立即更新 | 今すぐ更新 |
| later | Later | 稍后 | 後で |
| forceUpdateMessage | This update is required... | 此更新为必需更新... | このアップデートは必須です... |

---

## Technical Details

### Version Check Frequency

```dart
// Checks on:
1. App startup (initState in MainScreen)
2. App resume from background (AppLifecycleState.resumed)

// Rate limiting:
- Maximum 1 check per hour
- Prevents excessive API calls
- Saves bandwidth
```

### Dialog Behavior

**Optional Update:**
- User can dismiss with "Later" button
- User can tap outside to dismiss
- Won't show again for 24 hours after dismissal
- Back button closes dialog

**Force Update:**
- No "Later" button
- Cannot tap outside to dismiss
- Cannot use back button to dismiss
- `PopScope(canPop: false)` prevents dismissal
- MUST click "Update Now" to proceed

### Download Mechanism

```dart
Future<void> _downloadUpdate() async {
  final url = Uri.parse(versionInfo.downloadUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
```

**What happens:**
1. Opens default browser
2. Browser downloads APK/IPA
3. User installs manually
4. App updates

---

## Monitoring & Analytics

### Backend Logs

```bash
# Version check logs
GET /app-version?platform=android&currentVersion=1.0.0 200
→ Update required: true, Force: false

# Monitor update checks
tail -f logs/app.log | grep app-version
```

### Metrics to Track

```sql
-- Create a version_checks table (optional)
CREATE TABLE version_checks (
  id SERIAL PRIMARY KEY,
  platform VARCHAR(10),
  current_version VARCHAR(20),
  user_agent TEXT,
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Track adoption rate
SELECT 
  current_version,
  COUNT(*) as users,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM version_checks
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY current_version
ORDER BY users DESC;
```

---

## Troubleshooting

### Issue: Dialog Not Showing

**Check:**
1. Backend `/app-version` endpoint is accessible
2. `updateRequired` is `true` in API response
3. Less than 1 hour since last check
4. Not already shown in this session

**Debug:**
```dart
// Add logs to version_service.dart
print('Version check response: $response');
```

### Issue: Download URL Not Opening

**Check:**
1. `url_launcher` package installed
2. URL is valid and accessible
3. HTTPS (not HTTP) for better security
4. File exists at download URL

**Test URL:**
```bash
curl -I https://onlybl.com/downloads/blue-video-latest.apk
# Should return: 200 OK
```

### Issue: Android Won't Install APK

**Common causes:**
1. **Unknown sources disabled** → Enable in Android settings
2. **APK corrupted** → Re-download or re-build
3. **Signature mismatch** → Use same signing key
4. **Insufficient storage** → Free up space

**Solution:**
```bash
# Verify APK signature
keytool -printcert -jarfile blue-video.apk

# Check APK info
aapt dump badging blue-video.apk | grep version
```

---

## Security Considerations

### ✅ Implemented

- HTTPS for download URLs (recommended)
- Version comparison on backend (prevents client manipulation)
- Semantic versioning validation
- Rate limiting on API endpoint

### 🔒 Recommended

1. **Sign APKs** with proper keystore
2. **Use HTTPS** for all downloads
3. **Verify checksums** - Add SHA256 hash to API response
4. **Code signing** for iOS (required)
5. **Monitor downloads** - Track who's downloading what version

### Example: Add Checksum Verification

**Backend response:**
```json
{
  "downloadUrl": "https://onlybl.com/downloads/blue-video-v1.0.1.apk",
  "sha256": "abc123def456...",
  "fileSize": 25165824
}
```

**Mobile app can verify:**
```dart
// After download completes
final downloadedHash = await calculateSHA256(downloadedFile);
if (downloadedHash != versionInfo.sha256) {
  showError('Download corrupted. Please try again.');
}
```

---

## Production Deployment

### CloudPanel VPS Setup

**Nginx configuration for downloads:**

```nginx
# In your site config
location /downloads {
    alias /var/www/html/downloads;
    autoindex on;  # Allow directory listing
    
    # Set proper headers for APK/IPA
    location ~ \.apk$ {
        add_header Content-Type application/vnd.android.package-archive;
        add_header Content-Disposition "attachment; filename=$1";
    }
    
    location ~ \.ipa$ {
        add_header Content-Type application/octet-stream;
        add_header Content-Disposition "attachment; filename=$1";
    }
}
```

**Update `.env` for production:**
```env
ANDROID_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-latest.apk
IOS_DOWNLOAD_URL=https://onlybl.com/downloads/blue-video-latest.ipa
```

---

## Release Notes Best Practices

### Format

Use bullet points with emojis:

```env
ANDROID_RELEASE_NOTES=🎉 New Features:\n• Dark mode support\n• Multi-language (EN/ZH/JA)\n• Theme customization\n\n🐛 Bug Fixes:\n• Fixed video player crash\n• Improved chat stability\n\n⚡ Performance:\n• 30% faster loading\n• Reduced memory usage
```

### Categories

- 🎉 **New Features** - New functionality
- 🐛 **Bug Fixes** - Issues resolved
- ⚡ **Performance** - Speed improvements
- 🔒 **Security** - Security enhancements
- 💄 **UI/UX** - Design improvements
- 📝 **Other** - Miscellaneous changes

---

## Advanced Features (Future)

### 1. In-App Download

Instead of opening browser, download within app:

```dart
// Using flutter_downloader package
await FlutterDownloader.enqueue(
  url: versionInfo.downloadUrl,
  savedDir: '/storage/emulated/0/Download',
  fileName: 'blue-video.apk',
  showNotification: true,
);
```

### 2. Background Download

Download while user continues using app:

```dart
// Show progress indicator
// Allow app usage during download
// Prompt to install when complete
```

### 3. Auto-Install (Android Only)

With `REQUEST_INSTALL_PACKAGES` permission:

```dart
// Automatically trigger installation after download
await InstallPlugin.installApk(filePath);
```

### 4. Silent Updates

Check for updates silently, download in background, prompt only when ready:

```dart
// Check → Download silently → Prompt "Update ready to install"
```

---

## Summary

✅ **Backend API** - `/app-version` endpoint  
✅ **Version Management** - Configurable via `.env`  
✅ **Mobile Service** - Automatic checking  
✅ **Update Dialog** - Beautiful UI with force update support  
✅ **Lifecycle Integration** - Checks on startup and resume  
✅ **Multi-language** - EN, ZH, JA translations  
✅ **Rate Limiting** - Max 1 check per hour  
✅ **Platform Detection** - Android/iOS support  

**Status:** ✅ **READY TO USE**

---

## Quick Reference

### Release New Version

```bash
# 1. Build app
cd mobile-app
flutter build apk --release

# 2. Upload APK
scp build/app/outputs/flutter-apk/app-release.apk user@onlybl.com:/var/www/html/downloads/blue-video-v1.0.1.apk

# 3. Update backend .env
ANDROID_LATEST_VERSION=1.0.1
ANDROID_RELEASE_NOTES=Your release notes here

# 4. Restart backend
pm2 restart blue-video-api

# 5. Done! Users will see update prompt
```

---

**Last Updated:** October 27, 2025  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

