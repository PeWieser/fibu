# Fibu — Multi-Cloud-Backup & Mediathek-Spiegelung

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![rclone](https://img.shields.io/badge/rclone-70%2B%20Clouds-1C6BBA?logo=rclone)](https://rclone.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20iOS%20%7C%20Android-green)](#unterstützte-plattformen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Fibu** ist eine moderne, plattformadaptive Multi-Cloud-Backup-App für iOS, Android und Windows. Sie verbindet die Leistungsfähigkeit und Protokollvielfalt von **[rclone](https://rclone.org)** mit einer eleganten, an **Apple Human Interface Guidelines (HIG)** angelehnten Benutzeroberfläche.

---

## Highlights & Kernfunktionen

### 1. 70+ Cloud-Anbieter & Protokolle
Unterstützung für alle Cloud-Speicher und Protokolle aus dem Rclone-Ökosystem:
- **Cloud-Speicher (OAuth & Web-Login):** Google Drive, Google Photos, Microsoft OneDrive, Dropbox, Box, pCloud, MEGA, Yandex Disk, STRATO HiDrive, Zoho WorkDrive, Proton Drive, PikPak, Put.io, Mail.ru uvm.
- **S3 & Object Storage:** Amazon S3, Wasabi Hot Cloud, Backblaze B2, Cloudflare R2 (Null Egress), DigitalOcean Spaces, MinIO, Synology C2, IDrive e2, Ceph RADOS.
- **Native Enterprise APIs:** Google Cloud Storage (GCS), Azure Blob Storage, Azure Files, Storj DCS, OpenStack Swift.
- **Protokolle & Server:** SFTP (mit SSH-Key-Support), WebDAV (Nextcloud, ownCloud, Synology), FTP/FTPS, SMB/CIFS (Windows Freigaben), HTTP Read-Only.
- **Verschlüsselung & Virtuelle Laufwerke:** Crypt (Ende-zu-Ende-Verschlüsselung mit eigenem Master-Passwort), Chunker (Datei-Splitting), Union (Speicher-Pools), Combine & Kompression.

### 2. Echte 1:1 Mediathek-Spiegelung (iOS & Android)
- Liest über native APIs (`PhotoKit` / `PHAsset` / `photo_manager`) die reale Albenstruktur aus.
- Spiegelt Medien mit exakter Hierarchie in die Cloud:
  ```text
  fibu-backup/
  └── Photos/
      ├── Camera Roll/
      │   ├── IMG_0001.HEIC
      │   └── IMG_0002.MOV
      ├── Favoriten/
      │   └── IMG_0042.HEIC
      └── WhatsApp/
          └── IMG_1337.JPG
  ```
- **2-Wege-Spiegelung (Echo):** Synchronisiert Löschungen und Änderungen sauber zwischen lokalem Gerät und Cloud.

### 3. Dateisystem- & Ordner-Sicherung (Files App)
- Volle Integration mit der iOS Dateien-App und Android Storage Access Framework.
- Ordnerhierarchien bleiben 1:1 erhalten: `fibu-backup/Dateien/<Projekt>/...`

### 4. Fibu Manifest & DB-Katalog (`.fibu/manifest.json`)
- Nach jeder Synchronisation wird ein Snapshot-Katalog mit Checksummen, Dateigrößen, Zeitstempeln und Sync-Status lokal und remote abgelegt.
- Ermöglicht blitzschnelle inkrementelle Backups und Offline-Durchsuchen des Cloud-Explorers.

### 5. Resiliente Offline- & Netzwerk-State Machine
- Kontinuierliche Netzwerkprüfung über `connectivity_plus`.
- Bei Verbindungsabbruch oder fehlender Berechtigung schaltet die App sofort in einen sauberen "Pausiert"- bzw. "Fehler"-Status mit Klartext-Hinweisen.
- **WLAN-Only Option:** Verhindert ungewollten Datenverbrauch über mobile Netze.

### 6. Apple Minimalist UI/UX Design
- **Progressive Disclosure:** Beliebte Provider erhalten priorisierte Schnellzugriffskarten; komplexe Parameter (S3-Endpoints, Ports, SSH-Keys) sind aufgeräumt eingeklappt.
- **Plattform-Adaptiv:**
  - **Windows:** Fluent UI (Mica, Acrylic, Fluent Icons)
  - **iOS:** Cupertino Design (Blur-Effekte, SF Symbols, Cupertino Navigation)
  - **Android:** Material 3 (Dynamic Color, Elevation, Floating Bars)
- **Barrierefreiheit:** 44pt Mindest-Touch-Targets, WCAG AA Kontraste, Sanzo Wada Farbpaletten.

---

## Projektstruktur

```text
fibu win/
├── lib/
│   ├── core/
│   │   ├── localization/         # Zweisprachig (Deutsch & Englisch) via AppStrings
│   │   ├── services/             # RcloneService, RcloneProviderRegistry, SyncManifestService
│   │   └── utils/                # Dateihandler, Formatierer
│   ├── features/
│   │   ├── dashboard/            # Übersicht, Hero-Status, Speicher-Karten, Explorer
│   │   ├── tasks/                # Aufgaben-Manager, 1-Klick-Presets, Wizard
│   │   ├── settings/             # 70+ Cloud Drives Wizard, WLAN-Only, Farbpaletten
│   │   ├── onboarding/           # Erststart-Assistent (Mediathek & Dateien Schnellstart)
│   │   └── shell/                # Plattformadaptiver Navigations-Rahmen
│   └── theme/                    # 4pt Design-Tokens, Farbpaletten, Typografie
├── test/
│   ├── unit/                     # Unit Tests für Provider-Registry, Manifest, RcloneService
│   ├── widget/                   # Widget- und Interaktionstests
│   └── e2e/                      # End-to-End Testskripte
├── ios/                          # iOS Runner (PhotoKit Berechtigungen, File Sharing)
├── android/                      # Android App (Storage & Media Berechtigungen)
└── windows/                      # Windows Desktop Runner
```

---

## Installation & Ausführung

### Voraussetzungen
- Flutter SDK `>=3.0.0 <4.0.0`
- Dart SDK `>=3.0.0`

### Abhängigkeiten installieren
```bash
flutter pub get
```

### Tests ausführen
```bash
flutter test
```

### Statische Codeanalyse
```bash
flutter analyze
```

### App starten
```bash
# Windows Desktop
flutter run -d windows

# iOS Simulator / Gerät
flutter run -d ios

# Android Emulator / Gerät
flutter run -d android
```

---

## Lizenz
MIT License. Erstellt für sichere, dezentrale und unabhängige Datensicherung.
