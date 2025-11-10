# Payment Testing Guide

This document explains how to test the Blue Video payment flow, covering both real IPN callbacks from the payment gateway and the mock IPN endpoint that is available for local development.

---

## 1. Glossary

- **IPN (Instant Payment Notification)**: Server to server callback sent by the payment gateway when a transaction changes status.
- **Order ID / Invoice ID**: Unique identifier returned by the backend when you create an invoice. This value is used when polling or triggering mock IPN events.
- **Gateway**: External provider (MyPremium.Store / PayFlare) that hosts the credit card payment form and sends IPN callbacks.

## 1.1 Prerequisites

Before testing payments, ensure you have configured the payment gateway credentials in `backend/.env`:

```env
# MyPremium.Store Payment Gateway Credentials
MPS_API_KEY=your_api_key_here
MPS_SECRET_KEY=your_secret_key_here
BASE_URL=http://192.168.1.100:3000  # Your server IP (not localhost!)
```

**Important:** If these credentials are missing or invalid, you'll get a "Prerequest failed" error from the gateway.

---

## 2. Payment Endpoints

### User-Facing Redirect Endpoints

After processing the payment, the gateway redirects the user to:

**Success**: `GET /payment/success`
- Displays "Payment Successful!" message
- Mobile app detects this and polls for payment status

**Failure**: `GET /payment/fail?msg=error_message`
- Displays "Payment Failed" with error details
- Mobile app detects this and shows error to user

### IPN Callback Endpoint

The backend exposes an IPN handler at:

```
POST /api/v1/payment/ipn
```

### Production URL

```
https://<your-domain>/api/v1/payment/ipn
```

### Local Development URL

```
http://<YOUR_LOCAL_IP>:3000/api/v1/payment/ipn
```

Example: `http://192.168.1.100:3000/api/v1/payment/ipn`

> **Important:** Set `BASE_URL` in `backend/.env` to your local IP (e.g., `BASE_URL=http://192.168.1.100:3000`) so the mobile app can access success/fail redirect URLs.

> **Note:** For external gateway IPN callbacks, use a tunnelling tool (ngrok, Cloudflare Tunnel, localtunnel, …) and register the tunnel URL as the IPN callback in the payment dashboard.

---

## 3. Testing with Real Payments

1. **Configure IPN URL in the Gateway**
   - Log in to the MyPremium.Store (PayFlare) dashboard.
   - Set the callback / IPN URL to your production server URL (`https://…/api/v1/payment/ipn`) or your tunnel URL if you are testing locally.

2. **Create a Credit Card Invoice**
   - In the mobile app choose Coins → Credit Card, or upgrade to VIP and pick Credit Card.
   - The backend will create an invoice and return `trans_id`, `amount`, `sign`, `endpoint_url`, and `orderId`.

3. **Complete the Payment**
   - The Flutter app opens a WebView that auto-posts the invoice data to `endpoint_url`.
   - Fill in the test card information and submit.

4. **Observe IPN Callback**
   - After the gateway processes the payment it sends a POST request to `/api/v1/payment/ipn`.
   - Backend verifies the signature, finalises the payment record, and marks the VIP subscription (or coin purchase) as completed.
   - Logs you should see:
     - `🎯 IPN notification received:`
     - `✅ Payment completed…`

5. **Client Confirmation**
   - The app polls `/api/v1/payment/status/:orderId` (every 10 seconds).
   - Once the payment is marked `COMPLETED` the WebView closes and the success flow (coin balance update / VIP activation) runs.

### Tips

- Use test cards supplied by the gateway.
- Ensure the IPN URL uses HTTPS in production.
- Keep browser dev tools open if you need to inspect form submission – the HTML auto-submits but you can disable `onload` for debugging if necessary.

---

## 4. Troubleshooting Gateway Timeout (Error 504)

### Symptom
WebView shows: "Gateway time-out - Error code 504" from Cloudflare when trying to submit payment.

### Cause
The payment gateway (`premiumflare.net/paygate/payblis/checkout/`) is slow or overloaded. Even though the homepage loads fine in a browser, the **actual payment processing endpoint** may timeout when receiving the POST request with payment data.

This is **NOT your app's fault** - it's a gateway infrastructure issue.

### Solutions

**Option 1: Wait and Retry**
- Gateway might recover in a few minutes
- Try again during off-peak hours

**Option 2: Use Mock IPN (Recommended for Development)**
- See section below to bypass the gateway entirely
- Perfect for testing the payment flow locally

**Option 3: Contact Gateway Support**
- Email support@premiumflare.net or mypremium.store
- Report the 504 timeout issue
- Verify your API credentials are active

---

## 5. Testing with Mock IPN (No external gateway)

For rapid testing or when the gateway is down, you can trigger the backend's mock endpoint. This simulates a successful `COMPLETED` IPN without contacting the real gateway.

### Endpoint

```
POST /api/v1/payment/mock-ipn/:orderId
```

- Replace `:orderId` with the invoice/order ID returned when creating the payment.
- Requires no body payload. The server builds a fake IPN matching the real structure and processes it via the same logic used for production.

### Steps

1. Generate an invoice (Coins → Credit Card or VIP → Credit Card).
2. Copy the `orderId` (log output or API response).
3. Call the mock IPN endpoint:

   ```bash
   curl -X POST http://localhost:3000/api/v1/payment/simulate-ipn/<orderId>
   ```

4. The backend logs `🎭 Simulating IPN for local development…` and the payment becomes `COMPLETED` immediately.
5. The app polling loop detects the status change and runs the normal success flow.

> **Reminder:** Mock IPN only exists in the development server (`server-local.ts`). Do not enable it in production.

---

## 5. Troubleshooting

| Symptom | Possible Cause | Resolution |
| --- | --- | --- |
| WebView closes but payment never completes | No IPN received | Ensure callback URL is correct, reachable, and the gateway has the updated URL |
| IPN request logged but status stays pending | Signature validation failed | Verify API keys/secrets used in `paymentService.verifyIPNSignature` |
| Local testing fails | Gateway cannot reach localhost | Use a tunnel service or trigger the mock IPN endpoint |
| WebView shows gateway error | Missing `trans_id`, `amount`, or `sign` | Confirm invoice API returns the fields and they are passed through the dialog |
| `ERR_CLEARTEXT_NOT_PERMITTED` in WebView | Android blocks HTTP traffic | Already fixed - see "Android Cleartext Traffic" section below |

### Android Cleartext Traffic (Already Configured)

Android 9+ blocks HTTP (cleartext) traffic by default. The app is already configured to allow localhost HTTP for development:

**File: `android/app/src/main/AndroidManifest.xml`**
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="true">
```

**File: `android/app/src/main/res/xml/network_security_config.xml`**
```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">192.168.1.100</domain>
    </domain-config>
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

> **Note:** Production builds should only use HTTPS. The configuration above allows HTTP only for localhost development.

---

## 6. Useful Logs & Commands

- Backend logs around IPN handling
  - `🎯 IPN notification received:`
  - `✅ Payment completed…`
  - `❌ Payment failed…`
- Manual status check

  ```bash
  curl http://localhost:3000/api/v1/payment/status/<orderId>
  ```

- Regenerate an invoice if the previous one has expired.

---

## 7. Summary

- Always configure the correct IPN URL for real transactions.
- Use the WebView flow to submit real credit card details to the gateway.
- Use the mock IPN endpoint for fast, offline testing.
- Watch backend logs to verify processing.

This guide should help you confidently test both real and simulated payment flows end to end.
