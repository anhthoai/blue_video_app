# Quick Guide: Releasing App Updates

## 🚀 How to Release a New Version (5 minutes)

The app now checks for updates automatically on the splash screen every time it starts, before routing to Login or Main. After that, it only rechecks when the app resumes from background and at least 1 hour has passed. If a user taps `Later` on an optional update, that prompt is hidden for 24 hours even after restarting the app.

### Step 1: Build New Version (2 min)

```bash
cd mobile-app

# Update version in pubspec.yaml
# Change: version: 1.0.1+2

# Build APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

### Step 2: Upload to Server (1 min)

```bash
# Upload to your downloads folder
scp build/app/outputs/flutter-apk/app-release.apk user@onlybl.com:/var/www/html/downloads/blue-video-v1.0.1.apk

# Create/update "latest" link
ssh user@onlybl.com "cd /var/www/html/downloads && ln -sf blue-video-v1.0.1.apk blue-video-latest.apk"
```

**Or manually via FTP/FileZilla:**
1. Upload `app-release.apk` to `/var/www/html/downloads/`
2. Rename to `blue-video-v1.0.1.apk`
3. Copy to `blue-video-latest.apk`

### Step 3: Update Backend Config (1 min)

Edit `backend/.env`:

```env
# For OPTIONAL update (users can skip):
ANDROID_LATEST_VERSION=1.0.1
ANDROID_MIN_VERSION=1.0.0
ANDROID_RELEASE_NOTES=• Bug fixes\n• Performance improvements
ANDROID_RELEASE_DATE=2025-11-01T00:00:00Z

# For FORCE update (users MUST update):
ANDROID_LATEST_VERSION=1.0.1
ANDROID_MIN_VERSION=1.0.1  # ← Same as latest = force
ANDROID_RELEASE_NOTES=• Critical security fix - please update immediately
ANDROID_RELEASE_DATE=2025-11-01T00:00:00Z
```

### Step 4: Restart Backend (30 sec)

```bash
cd backend
pm2 restart blue-video-backend

# Or if running manually:
# Ctrl+C then npm run dev
```

### Step 5: Test (30 sec)

```bash
# Test API
curl "http://your-server.com/app-version?platform=android&currentVersion=1.0.0"

# Should return:
# { "updateRequired": true, "latestVersion": "1.0.1", ... }
```

**Open app on phone:**
- Should see update dialog
- Click "Update Now"
- On Android, the app downloads the APK inside the dialog, shows progress, then opens the system install prompt ✅
- On iOS, the app still uses the external download link because iOS does not allow APK-style in-app installs

Important:
- `ANDROID_DOWNLOAD_URL` and `IOS_DOWNLOAD_URL` must be public direct download links.
- The version in `mobile-app/pubspec.yaml` must match the build you installed on the phone.

---

## 📋 Quick Checklist

- [ ] Build new APK with updated version number
- [ ] Upload APK to server downloads folder
- [ ] Update `ANDROID_LATEST_VERSION` in backend `.env`
- [ ] Update `ANDROID_MIN_VERSION` if force update
- [ ] Write release notes in `.env`
- [ ] Restart backend server
- [ ] Test API endpoint
- [ ] Test in app on old version
- [ ] Verify download works
- [ ] Confirm installation succeeds

---

## 💡 Tips

### Version Numbering

**Semantic Versioning:**
- `1.0.0` → `1.0.1` = Bug fixes (patch)
- `1.0.0` → `1.1.0` = New features (minor)
- `1.0.0` → `2.0.0` = Breaking changes (major)

**Build Numbers:**
- Increment for every build
- `version: 1.0.1+2` → Version 1.0.1, Build 2

### When to Force Update

**Use force update for:**
- ✅ Critical security vulnerabilities
- ✅ Database schema changes
- ✅ API breaking changes
- ✅ App-breaking bugs

**Don't force update for:**
- ❌ Minor bug fixes
- ❌ UI improvements
- ❌ New features (unless essential)

### Release Notes

**Good:**
```
• Fixed crash when uploading videos
• Improved chat message delivery
• Added dark mode support
• Better performance on older devices
```

**Bad:**
```
Bug fixes and improvements
```

**Best:**
```
🎉 New Features:
• Dark mode support
• Japanese language option

🐛 Bug Fixes:
• Fixed video upload crash
• Resolved chat sync issues

⚡ Performance:
• 30% faster video loading
• Reduced memory usage by 20%
```

---

## 🎯 Common Scenarios

### Scenario 1: Minor Bug Fix (Optional Update)

```env
ANDROID_LATEST_VERSION=1.0.1  # Increment patch
ANDROID_MIN_VERSION=1.0.0      # Keep old min (optional)
ANDROID_RELEASE_NOTES=• Fixed minor bugs\n• Improved stability
```

**Result:** Users see "Update Available" with "Later" option

### Scenario 2: Critical Security Fix (Force Update)

```env
ANDROID_LATEST_VERSION=1.0.2
ANDROID_MIN_VERSION=1.0.2      # Force everyone to update
ANDROID_RELEASE_NOTES=🔒 CRITICAL SECURITY UPDATE\n• Fixed security vulnerability\n• Please update immediately
```

**Result:** Users see "Update Required", cannot dismiss

### Scenario 3: Major New Version

```env
ANDROID_LATEST_VERSION=2.0.0
ANDROID_MIN_VERSION=1.5.0      # Force very old versions
ANDROID_RELEASE_NOTES=🎉 Major Update!\n• Complete UI redesign\n• New video editor\n• Live streaming\n• And much more!
```

**Result:** 
- Users on 1.5.0+ → Optional update
- Users on < 1.5.0 → Force update

---

## 🔄 Update Process for Users

### What Users See

**1. Open App:**
```
Loading...
↓
Checking for updates...
↓
[Update Dialog Appears]
```

**2. Update Dialog:**
- Shows current vs latest version
- Shows what's new
- Shows release date
- "Update Now" button (and "Later" if optional)

**3. Click "Update Now":**
```
Dialog stays open
↓
APK downloads inside the app
↓
Progress bar updates in the dialog
↓
System install prompt appears
↓
User taps Install
↓
User taps notification
↓
"Install app?" prompt
↓
Install completes
↓
App opens with new version
```

**4. Verification:**
- Open app
- Check Settings → App Information
- Version should show 1.0.1 ✅

---

## 📊 Monitoring Dashboard (Optional)

Track update adoption:

```javascript
// Backend analytics endpoint
app.get('/api/v1/admin/version-stats', async (req, res) => {
  const stats = await prisma.$queryRaw`
    SELECT 
      app_version,
      COUNT(*) as user_count,
      ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
    FROM users
    WHERE last_active > NOW() - INTERVAL '30 days'
    GROUP BY app_version
    ORDER BY user_count DESC
  `;
  
  res.json({ success: true, data: stats });
});
```

---

## ✅ System Status

**Backend:**
- ✅ `/app-version` API endpoint
- ✅ Version comparison logic
- ✅ Platform-specific configurations
- ✅ Environment variables
- ✅ Swagger documentation

**Mobile App:**
- ✅ Version check service
- ✅ App lifecycle monitoring
- ✅ Update dialog UI
- ✅ Multi-language support
- ✅ Force update support
- ✅ Download integration

**Everything is ready!** Just update the version numbers in `.env` and restart the backend to trigger updates for users.

---

**Quick Test:**

1. Set `ANDROID_LATEST_VERSION=1.0.1` in backend `.env`
2. Restart backend
3. Open app (version 1.0.0)
4. See update dialog! 🎉

