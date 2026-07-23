# WeVois Billing CRM — Android APK & PWA Build Guide

This guide explains how to install the **WeVois CRM Mobile App** on Android devices as a native-like PWA app or generate a signed `.apk` file using Capacitor / Bubblewrap CLI.

---

## Method 1: Instant PWA Mobile Installation (No Build Required)

1. Open **Google Chrome** or **Safari** on your mobile device.
2. Navigate to: **[https://wevoisbilling.vercel.app/wevois-billing-executive-app.html](https://wevoisbilling.vercel.app/wevois-billing-executive-app.html)**
3. Tap the browser **Menu (⋮)** or **Share Button** ➔ Select **"Add to Home Screen"** or **"Install App"**.
4. The **WeVois CRM** app icon will appear on your phone's home screen as a standalone mobile application with full Camera & Gallery access.

---

## Method 2: Building Native `.apk` with Bubblewrap TWA CLI

Run the following commands in your terminal:

```bash
# 1. Install Node TWA Builder
npm install -g @bubblewrap/cli

# 2. Generate Android Project from Web Manifest
bubblewrap init --manifest=https://wevoisbilling.vercel.app/manifest.json

# 3. Build APK
bubblewrap build
```

This generates `app-release-signed.apk` in your build folder, which can be directly installed on Android phones or uploaded to Google Play Console.

---

## Method 3: Building Native `.apk` with Capacitor & Android Studio

```bash
# 1. Initialize Capacitor
npx cap init "WeVois Billing CRM" "com.wevois.billingcrm"

# 2. Add Android Platform
npx cap add android

# 3. Open in Android Studio & Build APK
npx cap open android
```

In Android Studio:
1. Go to **Build ➔ Build Bundle(s) / APK(s) ➔ Build APK(s)**.
2. The generated `.apk` file will be located at `android/app/build/outputs/apk/debug/app-debug.apk`.

---

## Permissions Configured in Mobile App:
- 📷 **Camera**: `android.permission.CAMERA` (Live photo capture of notesheets / cleared bills).
- 🖼️ **Gallery / Storage**: `android.permission.READ_MEDIA_IMAGES` & `READ_EXTERNAL_STORAGE` (Selecting photos or PDFs from device gallery).
