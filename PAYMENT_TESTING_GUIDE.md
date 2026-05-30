# Payment Testing Guide

This guide covers the current payment flow using OxaPay only.

- Gateway: OxaPay
- Supported payment method: USDT (TRC20) only
- Legacy payment methods (credit card / old gateway): removed

---

## 1. Prerequisites

Configure backend payment environment values in backend/.env:

```env
OXAPAY_MERCHANT_API_KEY=your_oxapay_merchant_api_key
OXAPAY_CALLBACK_TOKEN=your_random_callback_token
OXAPAY_RETURN_URL=https://api.onlybl.com/payment-return
BASE_URL=http://192.168.1.100:3000
PUBLIC_API_URL=https://api.onlybl.com

# Optional for Universal Links / App Links (.well-known generation)
ANDROID_PACKAGE_NAME=com.onlybl.app
ANDROID_SHA256_CERT_FINGERPRINTS=AA:BB:...:ZZ
IOS_TEAM_ID=ABCDE12345
IOS_BUNDLE_ID=com.onlybl.app
```

Notes:
- PUBLIC_API_URL is used to build OxaPay callback/return URLs and must be public HTTPS.
- BASE_URL can remain local/internal for development usage.
- OXAPAY_CALLBACK_TOKEN is used to protect the callback endpoint.
- OXAPAY_RETURN_URL must be a valid HTTP(S) URL accepted by OxaPay.

---

## 2. Active Payment Endpoints

### Invoice creation

- POST /api/v1/payment/create-usdt-invoice
- POST /api/v1/payment/create-invoice (USDT-only compatibility endpoint)
- POST /api/v1/payment/create-invoice-demo (USDT-only demo endpoint)

### Callback and status

- POST /api/v1/payment/ipn
- GET /api/v1/payment/status/:orderId
- POST /api/v1/payment/simulate-ipn/:orderId (local/dev helper)

### Redirect pages

- GET /payment/success
- GET /payment/fail?msg=...

---

## 3. OxaPay Callback Setup

In OxaPay merchant settings, set callback URL:

```text
https://<your-domain>/api/v1/payment/ipn?token=<OXAPAY_CALLBACK_TOKEN>
```

For local testing, use a tunnel URL (ngrok/Cloudflare Tunnel/localtunnel), for example:

```text
https://xxxx.ngrok.io/api/v1/payment/ipn?token=<OXAPAY_CALLBACK_TOKEN>
```

---

## 3.1 Universal Links / App Links Setup (Recommended)

1. Configure app link domain in mobile app:
  - Android app host placeholder is in android/app/build.gradle.kts as appLinkHost.
  - iOS associated domain is in ios/Runner/Runner.entitlements as applinks:api.your-app.com.
2. Serve association files from backend:
  - GET /.well-known/assetlinks.json
  - GET /.well-known/apple-app-site-association
3. Fill backend env values used by these endpoints:
  - ANDROID_PACKAGE_NAME
  - ANDROID_SHA256_CERT_FINGERPRINTS (comma-separated SHA256 fingerprints)
  - IOS_TEAM_ID
  - IOS_BUNDLE_ID
4. Use HTTPS return URL for OxaPay:
  - OXAPAY_RETURN_URL=https://api.your-app.com/payment-return

Result:
- If links are verified, browser opens app directly.
- If verification fails, the backend return page still shows an Open App fallback button.

---

## 4. Real Payment Test (USDT TRC20)

1. Open app and go to coin recharge or VIP subscription.
2. Tap a package amount to open the payment method bottom sheet.
3. Select USDT (TRC20). Credit Card is shown but disabled as coming soon.
4. Tap Continue to create invoice and open OxaPay in external browser.
5. Complete payment in browser/wallet.
6. OxaPay returns to https://api.onlybl.com/payment-return?orderId=... which then opens the app via Universal Links/App Links fallback flow.
7. OxaPay also sends callback to /api/v1/payment/ipn.
8. App auto-checks /api/v1/payment/status/:orderId and updates balance/subscription automatically.
9. If user closes the payment processing screen, app-level pending checker still confirms payment and shows toast on completion/failure.

Expected logs:
- Payment invoice creation logs
- IPN notification received
- Payment completed and balance/subscription update logs

---

## 5. Fast Local Test (No Real Transfer)

Use simulate endpoint:

```bash
curl -X POST http://localhost:3000/api/v1/payment/simulate-ipn/<orderId>
```

This marks the payment as completed through the same processing path.

Behavior with app auto confirmation:
- Yes, this works with the new workflow.
- Pending orderId is saved locally after invoice creation.
- The processing page polls status and updates UI immediately when terminal state is reached.
- An app-wide checker also validates pending orders on interval and app resume, so confirmation still happens even if the processing page is closed.
- On confirmation, current user profile balance is refreshed and coin history balance stays in sync with Profile.

---

## 6. Troubleshooting

- IPN returns 401 Unauthorized callback:
  - token missing or mismatch between OxaPay callback URL and OXAPAY_CALLBACK_TOKEN.
- Payment remains PENDING:
  - callback URL unreachable from internet, wrong BASE_URL, or tunnel not active.
- App cannot confirm payment:
  - verify orderId used by app matches extOrderId in backend record.
  - verify pending order key exists in app local storage until terminal status.
- Missing invoice creation:
  - verify OXAPAY_MERCHANT_API_KEY is valid.

---

## 7. Summary

- Payment stack is now OxaPay + USDT TRC20 only.
- Old credit card and legacy gateway flow is removed.
- Use callback token + status polling + simulate endpoint for reliable testing.
