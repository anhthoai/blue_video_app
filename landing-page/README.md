# Blue Video Landing Page

Static HTML landing page for quick deployment.

## Files

- `index.html` - responsive install page with Android and iPhone calls to action
- `zh/index.html` - Chinese version of the same install page
- `assets/logo-transparent.png` - real app logo used for the favicon and hero branding
- `manifest.plist` - sample OTA manifest for iPhone install testing

## Quick Deploy

1. Upload the contents of `landing-page/` to any static host.
2. Keep HTTPS enabled. iPhone install flows need HTTPS.
3. Update the Android and iPhone download URLs in `index.html` for each release.
4. If you use the Chinese page, deploy `zh/index.html` with the same folder structure.

## iPhone Link Guidance

- Best option: TestFlight invite URL
- Alternative: `itms-services://?action=download-manifest&url=https://your-domain/manifest.plist`
- Less reliable for public users: raw `.ipa` file URL

## Manifest Testing

- `manifest.plist` points to `https://cdn.onlybl.com/downloads/blue-video-latest.ipa`
- The HTML pages automatically switch the iPhone button to `itms-services` when served over HTTPS
- Local `file:///` preview cannot test OTA install, so the button falls back to the raw IPA URL
- OTA install still requires a properly signed iPhone build such as enterprise, ad hoc, or a TestFlight flow

## Local Preview

Open `index.html` directly in a browser or serve the folder with any static file server.
