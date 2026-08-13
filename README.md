# Fibu

Mobile app to sync your device files to any cloud storage — powered by [rclone](https://rclone.org).

Built with Expo (React Native), TypeScript strict, NativeWind, and expo-sqlite.

---

## Features

- **60+ cloud providers** — Google Drive, OneDrive, Dropbox, S3, SFTP, WebDAV, Nextcloud, and everything else rclone supports
- **Searchable provider picker** — find any backend instantly
- **Encrypted local database** — AES-256-GCM via Web Crypto + expo-secure-store
- **Background sync** — expo-task-manager keeps your files in sync automatically
- **Crypt remote support** — encrypt files on the fly before uploading
- **Privacy first** — rclone runs locally on your device; no intermediate server

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Expo SDK 57 / React Native 0.86 |
| Language | TypeScript 6 (strict) |
| Styling | NativeWind v4 (Tailwind CSS v3) |
| Navigation | React Navigation v7 |
| Database | expo-sqlite + AES-256-GCM encryption |
| Cloud backend | rclone (embedded binary, `rclone rcd` HTTP mode) |
| Native bridge | Expo Modules API (Kotlin / Swift) |
| Testing | jest-expo (unit) + Maestro (E2E) |

---

## Getting Started

### Prerequisites

- Node.js 22 LTS
- Java 21 (for Android builds — Java 26 is not supported by Gradle yet)
- Xcode 16+ (for iOS builds)
- [Expo CLI](https://docs.expo.dev/get-started/installation/)

### Setup

```bash
# Install dependencies
npm ci

# Generate the iOS and Android projects
npx expo prebuild

# Start development server
npm start
```

### Run on device / emulator

```bash
# Android
npm run android

# iOS
npm run ios
```

---

## Project Structure

```
fibu/
├── src/
│   ├── screens/          # Screen components
│   ├── components/       # Shared UI components
│   ├── db/               # SQLite repositories + crypto
│   ├── data/             # Static data (rcloneProviders.ts)
│   ├── navigation/       # React Navigation setup
│   ├── theme/            # Design tokens
│   ├── types/            # Shared TypeScript types
│   └── utils/            # Logger, onboarding helpers
├── modules/
│   └── rclone/
│       ├── src/          # RcloneService.ts (JS layer)
│       ├── android/      # Kotlin Expo Module
│       └── ios/          # Swift Expo Module
└── __tests__/
```

---

## Adding a Cloud Drive

1. Open the **Cloud Drives** tab
2. Tap **Add Cloud Drive**
3. Search for your provider (60+ supported)
4. Fill in the required credentials
5. Tap **Save**

For OAuth providers (Google Drive, OneDrive, Dropbox, …) you will be redirected to the provider's login page. The token is stored encrypted on your device.

---

## Rclone Bridge

The typed JavaScript service and the local Expo module are autolinked for both
Android and iOS. The app shell can therefore be generated for both platforms
without manual edits to Gradle or Xcode.

The in-process rclone engine is not release-ready yet. Both native bridges
currently reject rclone calls with an explicit `NotImplemented` error. A
production implementation must package rclone's `librclone/gomobile` output as
an Android AAR and iOS XCFramework. Executing a binary copied into writable app
storage is not a supported mobile architecture.

---

## Development

```bash
# TypeScript check
npm run typecheck

# Lint
npm run lint

# Tests
npm test

# E2E (Maestro)
maestro test e2e/
```

---

## CI

GitHub Actions runs on every push:
- `npm ci`
- `tsc --noEmit`
- `eslint . --max-warnings 0`
- `jest`

Requires Java 21 and Node 22 in the CI environment.

---

## Supported Providers

Google Drive · OneDrive · Dropbox · MEGA · Box · pCloud · Yandex Disk · Jottacloud · Koofr · Mail.ru · Zoho WorkDrive · HiDrive · Proton Drive · Filen · PremiumizeMe · Put.io · OpenDrive · SugarSync · Linkbox · PikPak · Ulož.to · Seafile · Citrix ShareFile · Quatrix · FileFabric · Google Photos · Internet Archive · Amazon S3 · Backblaze B2 · Storj · IDrive e2 · Azure Blob Storage · Azure Files · Google Cloud Storage · OpenStack Swift · Oracle Object Storage · Sia · HDFS · SFTP · FTP · FTPS · WebDAV · SMB/CIFS · NFS · Wasabi · Cloudflare R2 · DigitalOcean Spaces · MinIO · Scaleway · Linode · Rackspace · Alibaba OSS · Tencent COS · Huawei OBS · and more via the `s3`-compatible backend

---

## License

Private repository — all rights reserved.
