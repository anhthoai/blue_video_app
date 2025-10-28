# Testing Email Verification - Quick Guide

## 🚀 Quick Test (5 minutes)

### Step 1: Start Backend
```bash
cd backend
npm run dev

# Look for:
# ✅ Email service configured successfully
# 📧 Server running on http://localhost:3000
```

### Step 2: Register New User

**Using Mobile App:**
1. Open app
2. Go to Register screen
3. Fill form:
   - Username: `testuser`
   - Email: `your-real-email@gmail.com` (use your real email!)
   - Password: `test123456`
4. Click "Create Account"

**Backend Console Should Show:**
```
✅ New user registered: your-real-email@gmail.com
📧 Sending verification email to your-real-email@gmail.com...
✅ Verification email sent successfully to your-real-email@gmail.com
```

**App Should:**
- Navigate to Home screen
- Show success message: "Registration successful! Please check your email for verification link."
- User is logged in (but not verified yet)

### Step 3: Check Email

**Check your inbox for:**
- **From:** "Blue Video" <hello@onlybl.com>
- **Subject:** "Verify your Blue Video account"
- **Content:** Beautiful purple gradient email with verification button

**If no email received:**
1. Check spam/junk folder
2. Check backend logs for errors
3. Verify SMTP credentials in `.env`

### Step 4: Verify Email

**Option A: Click Button in Email**
- Click "Verify Email Address" button
- Should open verification screen in browser

**Option B: Copy Link**
- Copy the verification URL
- Open in browser or paste in app

**Verification Screen Should:**
1. Show "Verifying your email..." with spinner
2. After 1-2 seconds, show:
   - ✅ Green check icon
   - "Email Verified!"
   - Success message
   - "Go to Login" button

**Backend Console Should Show:**
```
✅ Email verified for user: your-real-email@gmail.com
```

### Step 5: Confirm Verification

**Check Database:**
```sql
SELECT id, username, email, is_verified, verification_token 
FROM users 
WHERE email = 'your-real-email@gmail.com';

-- Should show:
-- is_verified: true
-- verification_token: null
```

---

## 🧪 Advanced Testing

### Test Case 1: Expired Token

**Setup:**
```sql
-- Manually expire token
UPDATE users 
SET verification_token_expiry = NOW() - INTERVAL '1 day'
WHERE email = 'test@example.com';
```

**Test:**
1. Click verification link
2. Should see: "Verification token has expired. Please request a new one."

**Expected:** ❌ Verification fails with expiration message

---

### Test Case 2: Invalid Token

**Test:**
1. Copy verification URL
2. Change last character of token
3. Try to verify

**Expected:** ❌ "Invalid or expired verification token"

---

### Test Case 3: Reused Token

**Test:**
1. Click verification link → Success
2. Click same link again → Fail

**Expected:** 
- First click: ✅ Success
- Second click: ❌ "User not found or token already used"

---

### Test Case 4: Admin User (First User)

**Setup:**
1. Clear database or use fresh database
2. Register first user

**Expected:**
- `role: ADMIN`
- `isVerified: true` (auto-verified)
- **No email sent**
- Success message: "You are the first user and have been granted admin privileges!"

---

## 📧 Email Deliverability Check

### Gmail Test
```bash
# Register with Gmail address
# Check:
# - Email arrives within 30 seconds
# - Not in spam
# - HTML renders correctly
# - Button is clickable
```

### Outlook Test
```bash
# Register with Outlook address
# Check same as Gmail
```

### Check Email Headers
```
# Look for in email source:
SPF: PASS
DKIM: PASS (if configured)
DMARC: PASS (if configured)
```

---

## 🔍 Debugging

### Check SMTP Connection

**Test SMTP manually:**
```bash
# Install telnet or use node script
node -e "
const nodemailer = require('nodemailer');
const transporter = nodemailer.createTransport({
  host: 'mail.onlybl.com',
  port: 587,
  auth: {
    user: 'hello@onlybl.com',
    pass: 'Thoai@311919239'
  }
});

transporter.verify().then(console.log).catch(console.error);
"
```

**Expected output:** `true` (connection successful)

### Check Database State

```sql
-- View users and their verification status
SELECT 
  username,
  email,
  is_verified,
  verification_token IS NOT NULL as has_token,
  verification_token_expiry,
  created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;
```

### Check Backend Logs

**Enable debug logging:**
```typescript
// In server-local.ts, registration endpoint
console.log('📧 Token:', verificationToken.substring(0, 20) + '...');
console.log('📧 Expiry:', verificationTokenExpiry);
console.log('📧 Email service configured:', emailService.isEmailConfigured());
```

---

## 📱 Mobile App Testing

### Deep Link Testing

**Test URL schemes:**
```
# HTTP (web browser)
http://localhost:3000/verify-email?token=<token>

# App deep link (if configured)
bluevideoapp://verify-email?token=<token>
```

### Network Debugging

**Enable in app:**
```dart
// Check API logs in console
// Look for:
🔍 API Call: GET /api/v1/auth/verify-email?token=...
✅ Verification successful
```

---

## ⚡ Performance

### Email Sending Time

**Target:** < 5 seconds from registration to email delivery

**Measure:**
```typescript
// In server-local.ts
const startTime = Date.now();
await emailService.sendVerificationEmail(...);
const endTime = Date.now();
console.log(`📧 Email sent in ${endTime - startTime}ms`);
```

**Typical times:**
- Local SMTP: 100-500ms
- External SMTP (Gmail, SendGrid): 1-3 seconds

### Token Verification Time

**Target:** < 1 second

**Typical:** 100-300ms (database query + JWT verification)

---

## 🔐 Security Best Practices

### ✅ Implemented

- JWT tokens with 24-hour expiration
- Tokens stored in database (can be invalidated)
- One-time use tokens
- HTTPS recommended for production
- Rate limiting on verification endpoint
- No sensitive data in email links

### 🚧 Recommended for Production

1. **Add CAPTCHA to registration**
2. **Monitor verification rates**
3. **Block disposable email domains**
4. **Add email reputation checking**
5. **Implement account deletion for unverified users after 30 days**

---

## 📊 Monitoring Dashboard Ideas

### Metrics to Track

```typescript
// Email verification metrics
{
  totalRegistrations: 1000,
  verifiedUsers: 850,
  verificationRate: 85%, // 850/1000
  avgVerificationTime: '2 hours',
  emailDeliveryRate: 99%, // 990/1000 emails sent successfully
  bounceRate: 1%, // 10/1000 emails bounced
}
```

### Database Queries

```sql
-- Verification rate (last 7 days)
SELECT 
  COUNT(*) as total_users,
  SUM(CASE WHEN is_verified THEN 1 ELSE 0 END) as verified_users,
  ROUND(100.0 * SUM(CASE WHEN is_verified THEN 1 ELSE 0 END) / COUNT(*), 2) as verification_rate
FROM users
WHERE created_at > NOW() - INTERVAL '7 days';

-- Users pending verification
SELECT username, email, created_at
FROM users
WHERE is_verified = false
  AND verification_token IS NOT NULL
ORDER BY created_at DESC;

-- Recently verified users
SELECT username, email, created_at, updated_at,
  EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600 as hours_to_verify
FROM users
WHERE is_verified = true
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY updated_at DESC;
```

---

## 🎯 Success Criteria

### ✅ System is Working If:

1. **Registration**
   - User can register
   - Backend logs show email sent
   - User receives email within 1 minute

2. **Email**
   - Email arrives in inbox (not spam)
   - HTML renders beautifully
   - Button is clickable
   - URL is correct and complete

3. **Verification**
   - Clicking link opens verification screen
   - Shows loading then success
   - Database shows `isVerified: true`
   - Token cleared from database

4. **Security**
   - Expired tokens rejected
   - Invalid tokens rejected
   - Reused tokens rejected
   - Only email_verification type accepted

5. **User Experience**
   - No errors or crashes
   - Clear success/error messages
   - Smooth navigation
   - Multi-language support works

---

## 📞 Support

If you encounter issues:

1. **Check backend logs** - Most issues show up here
2. **Check SMTP credentials** - Most common issue
3. **Check database state** - Verify data is being saved
4. **Check email spam folder** - Emails might be filtered
5. **Test SMTP connection** - Use nodemailer verify script

---

**Last Updated:** October 27, 2025  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

