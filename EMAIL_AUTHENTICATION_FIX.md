# Fixing Email Authentication Issues (SPF/DKIM)

## 🚨 Current Problem

Gmail (and other major email providers) are **blocking emails** from your server because:

❌ **SPF (Sender Policy Framework)** - Failed  
❌ **DKIM (DomainKeys Identified Mail)** - Failed

**Error Message:**
```
550-5.7.26 Your email has been blocked because the sender is unauthenticated.
550-5.7.26 Gmail requires all senders to authenticate with either SPF or DKIM.
```

**Your server IP:** `23.172.139.247` (sg-shared01.cpanelplatform.com)  
**Sender domain:** `onlybl.com`

---

## ✅ Temporary Workaround (For Testing)

**GOOD NEWS:** The verification system code is working perfectly! The email server successfully sent the email, but Gmail rejected it.

**For now**, the backend console will print the verification URL:

```bash
================================================================================
📧 EMAIL VERIFICATION LINK (Copy this to verify):
http://localhost:3000/verify-email?token=eyJhbGciOiJI...
================================================================================
```

**To test verification:**
1. Register a new user
2. Check backend console for the verification URL
3. Copy and paste the URL into your browser
4. Verification screen will appear and verify the email

---

## 🔧 Permanent Fix: Configure SPF and DKIM

You need to add DNS records for your domain `onlybl.com`. This is done through your domain registrar (e.g., GoDaddy, Namecheap, Cloudflare).

### Step 1: Add SPF Record

**What is SPF?** Tells email servers which IPs are allowed to send email from your domain.

**DNS Record to Add:**

| Type | Host/Name | Value | TTL |
|------|-----------|-------|-----|
| TXT | @ (or onlybl.com) | `v=spf1 ip4:23.172.139.247 include:_spf.onlybl.com ~all` | 3600 |

**Or if your cPanel/hosting provides SPF:**
```
v=spf1 a mx include:mail.onlybl.com ~all
```

**Explanation:**
- `v=spf1` - SPF version 1
- `ip4:23.172.139.247` - Allow your server IP
- `include:mail.onlybl.com` - Include mail server's SPF
- `~all` - Soft fail for other IPs (recommended for testing)

### Step 2: Add DKIM Record

**What is DKIM?** Cryptographically signs your emails to prove they're legitimate.

**How to Get DKIM Key:**

#### Option A: cPanel (Most Common)

1. Log into your cPanel for `onlybl.com`
2. Go to **Email** → **Email Deliverability** or **Authentication**
3. Click **Manage** next to your domain
4. Enable **DKIM**
5. Copy the DKIM DNS record
6. Add it to your DNS

**It will look like:**
```
Type: TXT
Host: default._domainkey.onlybl.com
Value: v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKB...
```

#### Option B: Check Current DKIM

Your email shows DKIM is already configured (selector: `default`), but it's **failing**. Check:

1. Go to your DNS manager
2. Look for TXT record: `default._domainkey.onlybl.com`
3. Verify the public key matches what cPanel shows
4. If missing or wrong, update it

### Step 3: Add DMARC (Recommended)

**What is DMARC?** Tells email providers what to do if SPF/DKIM fails.

**DNS Record to Add:**

| Type | Host/Name | Value | TTL |
|------|-----------|-------|-----|
| TXT | _dmarc.onlybl.com | `v=DMARC1; p=quarantine; rua=mailto:dmarc@onlybl.com` | 3600 |

**Explanation:**
- `v=DMARC1` - DMARC version 1
- `p=quarantine` - Quarantine suspicious emails
- `rua=mailto:dmarc@onlybl.com` - Send aggregate reports here

---

## 🔍 Testing DNS Records

### Check SPF

**Online Tool:** https://mxtoolbox.com/spf.aspx

**Command Line:**
```bash
nslookup -type=txt onlybl.com

# Should show:
# onlybl.com text = "v=spf1 ip4:23.172.139.247 include:mail.onlybl.com ~all"
```

**Or use:**
```bash
dig txt onlybl.com +short
```

### Check DKIM

**Online Tool:** https://mxtoolbox.com/dkim.aspx  
**Domain:** onlybl.com  
**Selector:** default

**Command Line:**
```bash
nslookup -type=txt default._domainkey.onlybl.com

# Should show:
# default._domainkey.onlybl.com text = "v=DKIM1; k=rsa; p=MIGfMA0GCS..."
```

### Check DMARC

```bash
nslookup -type=txt _dmarc.onlybl.com

# Should show:
# _dmarc.onlybl.com text = "v=DMARC1; p=quarantine; rua=mailto:dmarc@onlybl.com"
```

---

## 📧 Alternative: Use a Third-Party Email Service

If configuring SPF/DKIM is too complex, use a service that handles it for you:

### Option 1: SendGrid (Recommended)

**Free tier:** 100 emails/day

**Setup:**
1. Sign up at https://sendgrid.com
2. Verify your sender identity
3. Get API key
4. Update backend `.env`:

```env
# SendGrid Configuration
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=SG.your_sendgrid_api_key_here
```

**Benefits:**
- ✅ Pre-authenticated
- ✅ High deliverability
- ✅ Analytics dashboard
- ✅ Free tier sufficient for testing

### Option 2: Mailgun

**Free tier:** 100 emails/day for 3 months

```env
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USER=postmaster@yourdomain.mailgun.org
SMTP_PASS=your_mailgun_password
```

### Option 3: AWS SES

**Free tier:** 62,000 emails/month (if hosted on AWS)

```env
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USER=your_aws_access_key
SMTP_PASS=your_aws_secret_key
```

### Option 4: Gmail SMTP (For Testing Only)

**Setup:**
1. Enable 2FA on your Gmail account
2. Generate App Password
3. Update `.env`:

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.email@gmail.com
SMTP_PASS=your_16_character_app_password
```

**⚠️ Warning:** Gmail has low sending limits (500/day) and is not recommended for production.

---

## 🛠️ Fixing onlybl.com Email Server

Since you're using `mail.onlybl.com` (likely cPanel), here's how to fix it:

### Step-by-Step Fix

#### 1. Access Your cPanel

Log into cPanel for `onlybl.com` domain.

#### 2. Configure SPF

**Navigate to:** Zone Editor or DNS Zone Editor

**Add TXT Record:**
```
Name: @ (or leave blank for root domain)
Type: TXT
Record: v=spf1 a mx ip4:23.172.139.247 ~all
TTL: 14400
```

**Or if you have dedicated mail server:**
```
v=spf1 include:mail.onlybl.com ~all
```

#### 3. Enable DKIM in cPanel

**Navigate to:** Email → Email Deliverability

**Steps:**
1. Find `onlybl.com` in the list
2. Click **Manage**
3. Look for DKIM section
4. If "Not Installed", click **Install**
5. If "Invalid", click **Reinstall**
6. Copy the DKIM DNS record shown
7. Add it to your DNS (usually auto-added if using cPanel DNS)

**Manual DKIM DNS Record (if needed):**
```
Name: default._domainkey.onlybl.com
Type: TXT
Value: v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3... (very long key)
```

#### 4. Verify DNS Propagation

**Wait:** 15 minutes to 48 hours (usually 1-2 hours)

**Check with:**
```bash
# SPF
dig txt onlybl.com

# DKIM
dig txt default._domainkey.onlybl.com
```

#### 5. Test Email Sending

**After DNS propagates:**
1. Register a new user in your app
2. Email should now deliver to Gmail
3. Check Gmail inbox (not spam)

---

## 🔍 Debugging Current Configuration

### Check What DNS Records You Have Now

**SPF Check:**
```bash
nslookup -type=txt onlybl.com
```

**DKIM Check:**
```bash
nslookup -type=txt default._domainkey.onlybl.com
```

**Current Issue:** These records are either:
- ❌ Missing completely
- ❌ Present but incorrect
- ❌ Not including your mail server IP

### Your Email Headers Show

```
X-Originating-IP: 160.30.208.12
```

But error shows IP:
```
SPF [onlybl.com] with ip: [23.172.139.247] = did not pass
```

**This means:** The originating IP (160.30.208.12) is different from the IP Gmail sees (23.172.139.247). You need to include **BOTH** in your SPF record:

```
v=spf1 ip4:160.30.208.12 ip4:23.172.139.247 include:mail.onlybl.com ~all
```

---

## 📊 Email Authentication Status

### What Works ✅

- ✅ SMTP connection successful
- ✅ Email sent from server
- ✅ Email reaches Gmail servers
- ✅ Verification system code is correct
- ✅ Backend logs show success
- ✅ Token generated correctly

### What Fails ❌

- ❌ SPF authentication (IP not authorized)
- ❌ DKIM authentication (signature failed)
- ❌ Gmail rejects email as unauthenticated
- ❌ Email never reaches inbox

---

## 🎯 Quick Fix Options

### Option 1: Fix DNS (Best for Production)

**Time:** 1-2 hours (including DNS propagation)  
**Cost:** Free  
**Effort:** Medium  
**Deliverability:** Excellent

**Steps:**
1. Add SPF record to DNS
2. Enable DKIM in cPanel
3. Wait for DNS propagation
4. Test

### Option 2: Use SendGrid (Best for Testing)

**Time:** 15 minutes  
**Cost:** Free (100 emails/day)  
**Effort:** Easy  
**Deliverability:** Excellent

**Steps:**
1. Sign up for SendGrid
2. Verify sender
3. Get API key
4. Update `.env`
5. Done!

### Option 3: Use Console Workaround (Current)

**Time:** Immediate  
**Cost:** Free  
**Effort:** None  
**Deliverability:** Manual (copy-paste URL)

**Steps:**
1. Register user
2. Copy verification URL from console
3. Paste in browser
4. Verify manually

---

## 📝 Recommended DNS Records for onlybl.com

Add these to your DNS:

### 1. SPF Record
```
Type: TXT
Name: @
Value: v=spf1 ip4:160.30.208.12 ip4:23.172.139.247 include:mail.onlybl.com ~all
TTL: 3600
```

### 2. DKIM Record (Get from cPanel)
```
Type: TXT
Name: default._domainkey
Value: v=DKIM1; k=rsa; p=[YOUR_PUBLIC_KEY_FROM_CPANEL]
TTL: 3600
```

### 3. DMARC Record
```
Type: TXT
Name: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@onlybl.com; fo=1
TTL: 3600
```

---

## 🧪 Testing After Fix

### 1. Verify DNS Records Are Live

```bash
# Check SPF
dig txt onlybl.com +short

# Check DKIM
dig txt default._domainkey.onlybl.com +short

# Check DMARC
dig txt _dmarc.onlybl.com +short
```

### 2. Test Email Authentication

**Use MxToolbox:**
- https://mxtoolbox.com/spf.aspx?domain=onlybl.com
- https://mxtoolbox.com/dkim.aspx?domain=onlybl.com
- https://mxtoolbox.com/dmarc.aspx?domain=onlybl.com

**All should show:** ✅ PASS

### 3. Send Test Email

1. Register a new user with Gmail address
2. Email should arrive in inbox (not spam)
3. Check email headers - should show:
   ```
   SPF: PASS
   DKIM: PASS
   DMARC: PASS
   ```

---

## 📧 Testing Email Headers

### How to View Email Headers in Gmail

1. Open the email
2. Click three dots menu → **Show original**
3. Look for:

```
Authentication-Results: mx.google.com;
       dkim=pass header.i=@onlybl.com;
       spf=pass (google.com: domain of hello@onlybl.com designates 23.172.139.247 as permitted sender);
       dmarc=pass
```

**All should say PASS** ✅

---

## 🚀 Quick Start: Using SendGrid (Easiest Solution)

If you want to skip DNS configuration and get emails working **immediately**:

### 1. Sign Up for SendGrid

Go to: https://sendgrid.com/pricing/  
Choose: **Free Plan** (100 emails/day forever)

### 2. Verify Your Sender Identity

**Option A: Single Sender (Easiest)**
1. Dashboard → Settings → Sender Authentication
2. Click "Verify a Single Sender"
3. Enter: hello@onlybl.com
4. Verify your email

**Option B: Domain Authentication (Better)**
1. Dashboard → Settings → Sender Authentication
2. Click "Authenticate Your Domain"
3. Enter: onlybl.com
4. Follow instructions to add DNS records
5. Wait for verification (5-10 minutes)

### 3. Create API Key

1. Dashboard → Settings → API Keys
2. Click "Create API Key"
3. Name: "Blue Video App"
4. Permissions: "Full Access" or "Mail Send"
5. Copy the key (shown only once!)

**Example:** `SG.xxxxxxxxxxxxxxxxxxx.yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy`

### 4. Update Backend .env

```env
# Replace SMTP settings with SendGrid
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=SG.xxxxxxxxxxxxxxxxxxx.yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy

# Keep these
APP_NAME=Blue Video
FRONTEND_URL=http://localhost:3000
```

### 5. Restart Backend

```bash
cd backend
npm run dev
```

### 6. Test Registration

Register a new user → Email should arrive in seconds! ✅

---

## 📊 Comparison

| Method | Setup Time | Cost | Deliverability | Complexity | Production Ready? |
|--------|-----------|------|----------------|------------|-------------------|
| **Fix Current Server** | 1-2 hours | Free | Excellent | Medium | ✅ Yes |
| **SendGrid** | 15 min | Free (100/day) | Excellent | Easy | ✅ Yes |
| **Mailgun** | 20 min | Free trial | Excellent | Easy | ✅ Yes |
| **AWS SES** | 30 min | $0.10/1000 | Excellent | Medium | ✅ Yes |
| **Gmail SMTP** | 5 min | Free | Good | Easy | ❌ Testing only |
| **Console Workaround** | 0 min | Free | Manual | None | ❌ Dev only |

---

## 🎯 Recommended Solution

**For Immediate Testing:**
→ Use **SendGrid Free Plan** (15 minutes setup, works immediately)

**For Production:**
→ **Fix your onlybl.com DNS records** (proper long-term solution)

---

## 💡 Why This Happened

Gmail (and Outlook, Yahoo, etc.) now **require** email authentication to prevent spam and phishing. Without SPF/DKIM:

- Your emails look like they're from `hello@onlybl.com`
- But Gmail can't verify `onlybl.com` authorized your server
- So Gmail assumes it's spam/phishing
- Email is rejected before reaching inbox

**This affects ALL emails from your server**, not just verification emails.

---

## 📞 Next Steps

### Option A: Quick Fix (5 minutes)

1. **Sign up for SendGrid** free account
2. **Get API key**
3. **Update `.env`** with SendGrid credentials
4. **Restart backend**
5. **Test registration** → Email delivered! ✅

### Option B: Proper Fix (1-2 hours)

1. **Access your domain DNS** (registrar or Cloudflare)
2. **Add SPF record** with your server IPs
3. **Enable DKIM** in cPanel and copy DNS record
4. **Add DKIM record** to DNS
5. **Add DMARC record** (optional but recommended)
6. **Wait for DNS propagation** (15 mins - 48 hours)
7. **Test with MxToolbox** to verify
8. **Test registration** → Email delivered! ✅

---

## ✅ Current Status

**Email System Code:** ✅ Working perfectly  
**SMTP Connection:** ✅ Working  
**Email Sending:** ✅ Working  
**Email Delivery to Gmail:** ❌ **Blocked due to missing SPF/DKIM**

**Workaround Active:** ✅ Verification URL printed to console

**To Test Now:**
1. Register new user
2. Check backend console for verification URL
3. Copy URL and open in browser
4. Email verification works! ✅

**For Production:**
→ **Add SPF/DKIM DNS records** or **switch to SendGrid**

---

## 📚 Additional Resources

- [Google SPF Guide](https://support.google.com/a/answer/33786)
- [Google DKIM Guide](https://support.google.com/a/answer/174124)
- [SendGrid Documentation](https://docs.sendgrid.com)
- [MxToolbox Testing Suite](https://mxtoolbox.com)
- [DMARC Guide](https://dmarc.org/overview/)

---

**Last Updated:** October 27, 2025  
**Status:** ⚠️ Email Authentication Required  
**Workaround:** ✅ Console URL logging active

