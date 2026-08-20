# Fibu — Multi-Cloud Backup & Media Library Mirroring

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![rclone](https://img.shields.io/badge/rclone-70%2B%20Clouds-1C6BBA?logo=rclone)](https://rclone.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20iOS%20%7C%20Android-green)](#supported-platforms)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Fibu** is a modern, platform-adaptive multi-cloud backup app for iOS, Android, and Windows. It combines the power and protocol variety of **[rclone](https://rclone.org)** with an elegant UI inspired by **Apple's Human Interface Guidelines (HIG)**.

---

## Highlights & Core Features

### 1. 70+ Cloud Providers & Protocols
Support for every cloud storage and protocol in the rclone ecosystem:
- **Cloud storage (OAuth / web login):** Google Drive, Google Photos, Microsoft OneDrive, Dropbox, Box, pCloud, MEGA, Yandex Disk, STRATO HiDrive, Zoho WorkDrive, Proton Drive, PikPak, Put.io, Mail.ru, and more.
- **S3 & object storage:** Amazon S3, Wasabi Hot Cloud, Backblaze B2, Cloudflare R2 (zero egress fees), DigitalOcean Spaces, MinIO, Synology C2, IDrive e2, Ceph RADOS.
- **Native enterprise APIs:** Google Cloud Storage (GCS), Azure Blob Storage, Azure Files, Storj DCS, OpenStack Swift.
- **Protocols & servers:** SFTP (with SSH key support), WebDAV (Nextcloud, ownCloud, Synology), FTP/FTPS, SMB/CIFS (Windows shares), HTTP read-only.
- **Encryption & virtual drives:** Crypt (end-to-end encryption with your own master password), Chunker (file splitting), Union (storage pools), Combine & compression.

### 2. True 1:1 Media Library Mirror (iOS & Android)
- Reads the real album structure through native APIs (`PhotoKit` / `PHAsset` / `photo_manager`).
- Mirrors media with the exact hierarchy to the cloud:
  ```text
  fibu-backup/
  └── Photos/
      ├── Camera Roll/
      │   ├── IMG_0001.HEIC
      │   └── IMG_0002.MOV
      ├── Favorites/
      │   └── IMG_0042.HEIC
      └── WhatsApp/
          └── IMG_1337.JPG
  ```
- **Two-way mirroring (echo):** Synchronizes deletions and changes cleanly between the local device and the cloud. A persistent local mirror lives at `Documents/FibuMirror` (including a tombstone deletion log).
- **Collision-free staging filenames:** Empty or duplicated asset titles (iOS often returns null titles), screen recordings, live photos, and `/L0/001`-style asset IDs are deterministically uniquified per asset — target paths never resolve to directories.
- **Incremental mode without duplicate storage:** Pure upload tasks stage into a transient cache folder that is deleted right after the upload — no permanent local copies of your photos. Uploads stay incremental on the remote (rclone skips identical size/modtime files).
- **Album picker shows photo/video counts** per album (plus a grand total), loaded asynchronously via `assetCountAsync`.

### 3. Filesystem & Folder Backup (Files app)
- Full integration with the iOS Files app and Android's Storage Access Framework.
- Folder hierarchies are preserved 1:1: `fibu-backup/Dateien/<Project>/...`

### 4. Fibu Manifest & DB Catalog (`.fibu/manifest.json`)
- After every sync, a snapshot catalog with checksums, file sizes, timestamps and sync state is written locally and remotely.
- Enables fast incremental backups and offline browsing in the Cloud Explorer.

### 5. Resilient Offline & Network State Machine
- **Live network status:** a central `networkStatusProvider` built on `connectivity_plus` (initial check + live stream). Going offline shows a banner on the dashboard immediately; when connectivity returns, the UI updates automatically.
- **Sync blocker & global Wi-Fi-only:** No sync starts while offline; Wi-Fi-only is a single **global** setting that applies to the dashboard queue, single-task syncs, and the background scheduler.
- **Clear errors instead of hangs:** rclone calls use fast-fail connection options (15s connect timeouts, minimal retries) plus hard Dart timeouts — the real provider error (e.g. `couldn't login …`) is extracted from error details and shown clearly instead of eternal loading states.

### 6. Apple-Minimalist UI/UX Design
- **Progressive disclosure:** Popular providers get prioritized quick-access cards; complex parameters (S3 endpoints, ports, SSH keys) stay collapsed.
- **Platform adaptive:**
  - **Windows:** Fluent UI (Mica, Acrylic, Fluent icons)
  - **iOS:** Cupertino design (blur effects, SF Symbols, Cupertino navigation)
  - **Android:** Material 3 (dynamic color, elevation, floating bars)
- **Accessibility:** 44 pt minimum touch targets, theme-driven text colors verified to stay readable in light **and** dark mode (no static label colors), WCAG-AA-friendly contrasts, Sanzo Wada palettes.
- **Live theme switching:** System light/dark changes are applied instantly (WidgetsBindingObserver → `appThemeProvider`), no app restart needed.

### 7. Real rclone Behaviour in the Wizard & Cloud Drive List
- **Real connection test:** "Test connection" creates a temporary remote, lists its root, and deletes it again — errors (invalid credentials, unreachable host, bad S3 keys) surface *before* anything is saved. Adding a remote is **locked until the test passes** (or OAuth authorization completed); editing any credential field re-arms the test.
- **iCloud Keychain autofill (iOS):** `AutofillGroup` with `AutofillHints.username`/`password` gives native QuickType suggestions; after a successful add, iOS offers to save the credentials.
- **Provider-scoped credential suggestions:** Fibu additionally remembers credentials per rclone type (MEGA, S3, WebDAV, SFTP/FTP …) in the Keychain (via `flutter_secure_storage`) and offers them as tappable chips when adding another remote of the same provider.
- **Per-remote storage info:** total quota from `getQuota` ("x of y used", "n/a" for providers without `about` support) **plus** the space Fibu itself occupies in the `fibu-backup` folder (computed recursively).

### 8. Convenience & Integrations (iOS)
- **Home-screen context menu:** Long-press the app icon → **"Sync Now"** (quick action, SF symbol) starts the sync queue immediately — works from cold start as well.
- **Diagnostics log:** Settings → "Sync Log & Diagnostics" shows every action with timestamps and severity (engine, rclone RPCs, remotes, media staging, syncs, offline events) — copyable for support. Everything is also appended to a persistent log file at `Documents/fibu.log` (next to `rclone.conf`, visible in the Files app under "On My iPhone").

---

## Project Structure

```text
fibu win/
├── lib/
│   ├── core/
│   │   ├── localization/         # Bilingual (German & English) via AppStrings
│   │   ├── services/             # RcloneService (timeouts/logging), RcloneProviderRegistry,
│   │   │                         # SyncManifestService, AppLog, CredentialVault (Keychain),
│   │   │                         # NetworkStatus, QuickActions, MirrorSyncEngine
│   │   └── utils/                # File handlers, byte formatting
│   ├── features/
│   │   ├── dashboard/            # Overview, hero status, storage cards, explorer
│   │   ├── tasks/                # Task manager, one-tap presets, wizard
│   │   ├── settings/             # 70+ cloud drive wizard, Wi-Fi-only, palettes, debug log
│   │   ├── onboarding/           # First-run assistant (media & files quick start)
│   │   └── shell/                # Platform-adaptive navigation frame
│   └── theme/                    # 4pt design tokens, palettes, typography
├── test/
│   ├── unit/                     # Unit tests for the provider registry, manifest, RcloneService
│   ├── widget/                   # Widget and interaction tests
│   └── e2e/                      # End-to-end test scripts
├── ios/                          # iOS Runner (PhotoKit permissions, file sharing)
├── android/                      # Android app (storage & media permissions)
└── windows/                      # Windows desktop runner
```

---

## Installation & Running

### Prerequisites
- Flutter SDK `>=3.0.0 <4.0.0`
- Dart SDK `>=3.0.0`
- For iOS builds: Go + gomobile for the `Rclone.xcframework` (built automatically by `ios/scripts/build_librclone.sh`)

### Install dependencies
```bash
flutter pub get
```

### Run tests
```bash
flutter test
```

### Static analysis
```bash
flutter analyze
```

### Run the app
```bash
# Windows desktop
flutter run -d windows

# iOS simulator / device
flutter run -d ios

# Android emulator / device
flutter run -d android
```

---

## License
MIT License. Built for secure, decentralized, and independent data backups.
