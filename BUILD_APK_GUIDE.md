# WeVois Billing CRM — Android APK & PWA Package Guide

This repository contains the complete native Android packaging files (`capacitor.config.json`, `manifest.json`, `sw.js`, and `android/app/src/main/AndroidManifest.xml`) for **WeVois Billing CRM**.

---

## 📱 Method 1: Instant Mobile App Installation (Recommended — 10 Seconds)

1. Open **Google Chrome** on your Android phone.
2. Navigate to: **[https://wevoisbilling.vercel.app/wevois-billing-executive-app.html](https://wevoisbilling.vercel.app/wevois-billing-executive-app.html)**
3. Tap the browser **Menu (⋮)** in the top right.
4. Select **"Add to Home Screen"** or **"Install App"**.
5. The **WeVois CRM** icon will appear on your mobile home screen as a standalone Android app with full Camera & Storage access!

---

## 🛠️ Method 2: Building `.apk` File via PWABuilder (Online — 1 Click)

1. Go to **[https://www.pwabuilder.com/](https://www.pwabuilder.com/)**
2. Enter your app URL: `https://wevoisbilling.vercel.app/wevois-billing-executive-app.html`
3. Click **"Build My PWA"** ➔ Select **"Android"**.
4. Click **"Download APK"**. You will receive your signed `app-release-signed.apk` file ready to install on any Android phone or upload to Google Play Console!

---

## 💻 Method 3: Building `.apk` via Command Line (Bubblewrap / Android Studio)

### Using Bubblewrap CLI:
```bash
# 1. Install TWA CLI
npm install -g @bubblewrap/cli

# 2. Generate APK
bubblewrap init --manifest=https://wevoisbilling.vercel.app/manifest.json
bubblewrap build
```

### Using Android Studio:
```bash
# Open android directory in Android Studio
npx cap open android
```
In Android Studio: Go to **Build ➔ Build Bundle(s) / APK(s) ➔ Build APK(s)**.

---

## 📋 Configured Android Permissions:
- 📷 **Camera**: `android.permission.CAMERA`
- 🖼️ **Gallery / Storage**: `android.permission.READ_MEDIA_IMAGES` & `READ_EXTERNAL_STORAGE`
- 🌐 **Internet**: `android.permission.INTERNET`
