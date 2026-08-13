# Fibu — Offene Aufgaben (Flutter/Dart)

Stand: 2026-08-12

---

## 1. Rclone Integration & Bridges

- [ ] **rclone als Mobile-Library (gomobile)**
  - Android: `librclone` als AAR kompilieren und über MethodChannel / FFI in `RcloneService` einbinden.
  - iOS: `librclone` als XCFramework kompilieren, im Xcode-Projekt verlinken und in `RcloneService` einbinden.
  - Desktop (Windows): Bundling von `rclone.exe` im App-Paket optimieren und Pfad-Auflösung in `WindowsRcloneService` stabilisieren.
  - Alle Native-Aufrufe werfen standardmäßig `UnimplementedError` bis das Modul geladen ist (keine stillen No-Ops).

---

## 2. Dashboard Screen (Feature 1)

- [x] **Platform Adaptive Shell**: Fluent (Windows), Cupertino (iOS) und Material 3 (Android).
- [x] **Global Status Banner**: Zeigt den globalen Sync-Status (Syncing, Success, Error, Offline).
- [x] **Storage Card Component**: Zeigt die Belegung des Cloud-Backups bzw. des lokalen Speichers.
- [ ] **Active Tasks List**: Liste der aktuell laufenden Jobs auf dem Dashboard.

---

## 3. Tasks Screen (Feature 2)

- [ ] **Tasks List View**: Übersicht aller erstellten Backup-Jobs mit Schnellstart- und Bearbeitungs-Buttons.
- [ ] **Task Edit Dialog**:
  - Filter: Nur Fotos / nur Videos / beides.
  - Ziel-Cloud(s): Dropdown der verfügbaren Remotes.
  - Sync-Modus: Inkrementell (`rclone copy`) vs. Echo-Modus (`rclone sync`).
  - Zeitplan: Eingabe von Triggern (täglich, wöchentlich, etc.).
- [ ] **Destructive Action Protection**: Bestätigungs-Dialog vor dem Löschen von Tasks im Echo-Modus.

---

## 4. Settings Screen (Feature 3)

- [ ] **Appearance settings**: Wechsel zwischen Light, Dark und System-Theme sowie Aktivierung der Sanzo-Wada-Farbpaletten.
- [ ] **Cloud Drive Manager**: UI zur Verwaltung von rclone-Remotes (`rclone config` Wrapper).
- [ ] **OAuth Authentication Flow**: Einbinden eines In-App-Browsers zur Autorisierung bei Google Drive, OneDrive, etc.
- [ ] **Spracheinstellungen**: Internationalisierung (i18n) vorbereiten (vorerst Englisch).

---

## 5. Background & Network Handler

- [ ] **Background Execution**: Integration von OS-Schedulern (Windows Service / Task Scheduler, Android WorkManager, iOS BackgroundTasks) für automatische Syncs im Hintergrund.
- [ ] **Network State Guard**: Automatisches Pausieren von Sync-Jobs bei Verbindungsverlust (Offline-State) oder Wechsel in mobile Datennetze.

---

## 6. Testing & Quality Assurance

- [x] **Unit Tests**: Testsuite für `RcloneService` (Simulierte Abläufe, Remote-Management, Quota).
- [x] **Widget Tests**: Adaptive Layout-Tests für den Dashboard-Screen (Windows, iOS, Android Visual Verifications).
- [ ] **Integration Tests**: Automatisierte E2E Test-Flows für die Task-Erstellung und Remote-Registrierung.
- [ ] **Test Automation**: Einrichten des JSON-Reporter Parsers für automatische Fehlerbehebungs-Iterationen.
