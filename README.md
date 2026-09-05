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

### 2. True Two-Way Mirror (Media Library on iOS/Android, Folders on Windows)
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
- **Two-way mirroring (echo, manifest-only):** Synchronizes changes and deletions in both directions without keeping permanent local copies — only metadata and a tombstone deletion log are stored (hidden in Application Support). Assets are exported on demand for upload and removed right after.
- **Cloud deletions propagate to the device:** files deleted directly in the cloud (e.g. in the MEGA web app) are detected via listing-diff against the last provably-synced state and removed locally through the iOS system confirmation sheet (one batched dialog per run; declines are remembered). Safety brakes prevent an outage from ever wiping the library.
- **Album-correct downloads:** files added in the cloud under `Photos/<Album>/…` are imported into the matching photo album (created if needed) instead of landing in Recents only.
- **Collision-free staging filenames:** Empty or duplicated asset titles (iOS often returns null titles), screen recordings, live photos, and `/L0/001`-style asset IDs are deterministically uniquified per asset — target paths never resolve to directories.
- **Incremental mode without duplicate storage:** Pure upload tasks stage into a transient cache folder that is deleted right after the upload — no permanent local copies of your photos. Uploads stay incremental on the remote (rclone skips identical size/modtime files).
- **Album picker shows photo/video counts** per album (plus a grand total), loaded asynchronously via `assetCountAsync`.
- **Windows mirrors folders two-way:** the filesystem is the source (`FilesystemMirrorSource` → `VirtualMirrorSyncEngine`), so Windows gets the same tombstones, conflict handling and safety brakes as mobile — not a one-way `rclone sync` with delete rights. Local deletes go to a `.fibu-trash` folder (30 days) instead of being hard-deleted.
- **Conflicts are kept, not overwritten:** local and cloud are compared three-way against the last known state; if both sides changed a file, the local version is preserved under a timestamped name (`IMG_0001 (Konflikt 2026-09-04 14-03).HEIC`) and the cloud version stays put.
- **Renames are detected** (size + mtime) and applied server-side as a move instead of delete + re-upload.
- **Two devices, one target folder:** a cloud-side sync lock (`SyncLockService`) makes sure only one device mirrors into a folder at a time — for manual runs and scheduled runs alike — and a per-device journal (`.fibu/journal/`) lets each device see what the others did.

### 3. Filesystem & Folder Backup (Files app)
- Full integration with the iOS Files app and Android's Storage Access Framework.
- Folder hierarchies are preserved 1:1: `fibu-backup/Dateien/<Project>/...`

### 4. Fibu Manifest & DB Catalog (`.fibu/manifest.json`)
- After every sync, a snapshot catalog with checksums, file sizes, timestamps and sync state is written locally and remotely.
- Enables fast incremental backups and offline browsing in the Cloud Explorer.

### 5. Resilient Offline & Network State Machine
- **One calm status banner:** the dashboard shows exactly one line — grey (offline), accent (syncing), red (failed), amber (changes found — sync needed), green (up to date). It never claims success while nothing is configured.
- **Auto-refresh, no refresh buttons:** remotes, quota and sync-needed state refresh automatically every 10 s (20 s in Low Power Mode), foreground-only, online-only, never during a sync. Opening the dashboard triggers an immediate check.
- **Sync blocker & global Wi-Fi-only:** Sync and cloud-explorer actions are disabled while offline; Wi-Fi-only is a single **global** setting that applies to the dashboard queue, single-task syncs, and the background scheduler.
- **Clear errors instead of hangs:** rclone calls use fast-fail connection options (15s connect timeouts, minimal retries) plus hard Dart timeouts — the real provider error (e.g. `couldn't login …`) is extracted from error details and shown clearly instead of eternal loading states.

### 6. Apple-Minimalist UI/UX Design
- **Progressive disclosure:** Popular providers get prioritized quick-access cards; complex parameters (S3 endpoints, ports, SSH keys) stay collapsed.
- **Platform adaptive:**
  - **Windows:** Fluent UI (Mica, Acrylic, Fluent icons)
  - **iOS:** Cupertino design (blur effects, SF Symbols, Cupertino navigation)
  - **Android:** Material 3 (dynamic color, elevation, floating bars)
- **Accessibility:** 44 pt minimum touch targets, theme-driven text colors verified to stay readable in light **and** dark mode (no static label colors), WCAG-AA-friendly contrasts, Sanzo Wada palettes.
- **One appearance choice:** a single row of palettes (Sanzo Wada, plus a neutral default). Each palette carries a light **and** a dark colour set, and light/dark follows the system automatically — there is no in-app mode switch. Contrast for all 8 palettes × 2 modes is pinned by an automated WCAG AA test.
- **Live theme switching:** System light/dark changes are applied instantly (WidgetsBindingObserver → `appThemeProvider`) across every screen and dialog — text and object colors included — no app restart needed.
- **Sticky page titles (iOS):** Dashboard, Tasks and Settings use native large titles that collapse into a fixed navigation bar while scrolling, so the page title stays visible at all times (HIG-compliant).

### 7. Real rclone Behaviour in the Wizard & Cloud Drive List
- **Real sign-in:** "Sign In" creates a temporary remote, lists its root, and deletes it again — errors (invalid credentials, unreachable host, bad S3 keys) surface *before* anything is saved. Adding a remote is **locked until sign-in succeeds** (or OAuth authorization completed); editing any credential field re-arms it.
- **iCloud Keychain autofill (iOS):** `AutofillGroup` with `AutofillHints.username`/`password` gives native QuickType suggestions; the keyboard dismisses automatically once AutoFill has filled the password. Credentials are stored through a native Security.framework channel (no third-party storage plugin).
- **Detected task import:** tasks stored on a remote (`.fibu/config.json`) are offered right after connecting — and any time later via the “+” menu on the Tasks tab (multi-select import). Remote references resolve dynamically: id → display name → provider type → the remote the config was found on.
- **Per-remote storage info:** total quota from `getQuota` ("x of y used", "n/a" for providers without `about` support) **plus** the space Fibu itself occupies in the `fibu-backup` folder (computed recursively).

### 8. Convenience & Integrations (iOS)
- **Home-screen widgets (3 sizes):** live sync state per task (ok / pending / never / error), last sync time, and a sync-needed indicator. Data flows through an App Group whose ID is resolved at runtime from the signing profile — so widgets keep working with sideload tools that rename app groups. Refreshed on app start/resume, after every task change, and by the 2-hour background run.
- **Home-screen context menu:** Long-press the app icon → **"Sync Now"** (quick action, SF symbol) starts the sync queue immediately — works from cold start as well.
- **Open-source licenses:** Settings → Legal presents a structured overview — a short classification, the core components (rclone, gomobile, Flutter) with descriptions, and the full list of bundled libraries; each entry opens its complete license text in a dedicated detail view.
- **Legal in-app:** Settings → Legal also carries the full privacy notice and imprint, so the App Store / Play Store requirement for an in-app privacy policy is met without a website ([`docs/DATENSCHUTZ.md`](docs/DATENSCHUTZ.md), [`docs/IMPRESSUM.md`](docs/IMPRESSUM.md)).
- **Diagnostics log:** Settings → "Sync Log & Diagnostics" shows every action with timestamps and severity (engine, rclone RPCs, remotes, media staging, syncs, offline events) — copyable for support. Everything is also appended to a persistent log file in the private app-support folder (next to `rclone.conf`). It is deliberately **not** in the documents folder: the log contains file names, album names and remote paths, which are personal data and must not sit in a folder the Files app exposes for export.

### 9. Device-to-Device Configuration Transfer

Set up a second device in one tap — no account, no server, no typing:

- The receiving device starts **Receive** and becomes discoverable on the local
  network (UDP beacon, port 47831).
- The sending device finds it **by name** and transfers with a single tap:
  drives **with** credentials, plus tasks. Encrypted with AES-256-GCM using a
  random per-session key; direct device-to-device, no relay.
- The receiver shows what arrived (device name, number of drives and tasks) and
  applies it only after you confirm. Rejecting changes nothing.
- Tasks that point at the other device's photo library have their source
  cleared and need a folder again — a library from another device does not
  exist here.

---

## Project Structure

```text
fibu/
├── lib/
│   ├── core/
│   │   ├── localization/         # Bilingual (German & English) via AppStrings
│   │   ├── navigation/           # AppNav — one push helper for Fluent / Cupertino / Material
│   │   ├── services/             # RcloneService (timeouts/logging), RcloneProviderRegistry,
│   │   │                         # SyncManifestService, AppLog, SecureStore (native Keychain channel),
│   │   │                         # NetworkStatus, AutoRefresh, QuickActions, DevicePairing,
│   │   │                         # SyncLock, ChangeJournal, mirror engines
│   │   ├── widgets/              # Win.* Fluent building blocks, Liquid Glass
│   │   └── utils/                # File handlers, byte formatting
│   ├── features/
│   │   ├── dashboard/            # Overview, hero status, storage cards, explorer
│   │   ├── tasks/                # Task manager, one-tap presets, wizard
│   │   ├── settings/             # 70+ cloud drive wizard, Wi-Fi-only, palettes, debug log
│   │   └── shell/                # Platform-adaptive navigation frame
│   └── theme/                    # 4pt design tokens, palettes, typography
├── test/
│   ├── unit/                     # Provider registry, manifest, RcloneService, theme contrast, pairing
│   └── widget/                   # Widget and interaction tests (all three platforms)
├── integration_test/             # On-device end-to-end flows (cloud drives, tasks, MEGA sync)
├── maestro/                      # Maestro UI flows
├── ios/                          # iOS Runner (PhotoKit + local network permissions, file sharing)
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

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the pieces fit together (sync engines, remote identity model, widget pipeline, background scheduling, CI).
- [`docs/ARBEITSLOG.md`](docs/ARBEITSLOG.md) — chronological work log of the ongoing development sessions (German).
- [`docs/RECHTS_AUDIT.md`](docs/RECHTS_AUDIT.md) — legal/compliance audit: copyright and OSS obligations, GDPR, App Store and Play Store requirements, distribution, trademarks (German, with file/line evidence).
- [`docs/DATENSCHUTZ.md`](docs/DATENSCHUTZ.md) / [`docs/IMPRESSUM.md`](docs/IMPRESSUM.md) — publishable privacy notice and imprint; the same text ships in-app under Settings → Legal.
- [`docs/TESTMATRIX_IOS_WINDOWS.md`](docs/TESTMATRIX_IOS_WINDOWS.md) — iOS/Windows test matrix: which cross-device scenarios hold, which are risky, with file/line evidence (German).
- [`docs/VEREINFACHUNG.md`](docs/VEREINFACHUNG.md) — simplification pass: what was removed, what was deliberately kept, and why (German).
- [`docs/STRESSTEST_DAU.md`](docs/STRESSTEST_DAU.md) — stress-test scenario catalogue with a verdict per case (German).
- [`docs/ZEITPUNKT_WIEDERHERSTELLUNG.md`](docs/ZEITPUNKT_WIEDERHERSTELLUNG.md) — point-in-time restore: what can be recovered as of when (German).

## Continuous Integration

Two GitHub Actions workflows run on every push to `main` (and to `arena/**`,
the working branches of agent sessions):

- **Build iOS App** (macOS) — analyze, `Rclone.xcframework`, unsigned release
  IPA, verifies the privacy manifest is bundled, then runs the test suite.
  Artifact: `ios-app-release`.
- **Build Windows App** (Windows) — analyze, release build, bundles
  `rclone.exe` next to the app, verifies the bundle, then runs the test suite.
  Artifact: `windows-app-release`.

`flutter analyze` must report **0 errors and 0 warnings**; info-level lints fail
the run as well. On failure, each workflow posts the tail of its logs as a
commit comment, so a red run can be read without opening the web UI:

```bash
gh api repos/PeWieser/fibu/commits/<sha>/comments --jq '.[].body'
```

---

## License
MIT License, © PeWieser (Fibu). Built for secure, decentralized, and independent data backups.
Bundled open-source components are listed in-app under Settings → Legal → Open-Source Licenses.

Fibu is an independent project. It is not affiliated with, endorsed by, or
sponsored by the rclone project, Apple, Google, Microsoft or any other cloud
provider mentioned here. Third-party names and marks are used solely to
identify the supported services.
