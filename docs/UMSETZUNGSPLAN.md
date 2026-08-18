# Fibu — Umsetzungsplan (iOS-fokussiert)

**Stand:** 2026-08-17 (aktualisiert nach Merge von `main` @ `3c3925f` "feature/ios-native-rclone") · **Fokus:** iOS-App
**Ergebnis der Analyse:** Die App ist eine Flutter-App mit 3 Plattform-Zweigen. Der Fokus dieses Plans liegt auf der **iOS-App**, die **vollständig nativ (Apple-ähnlich)** wirken und zu 100 % funktionieren soll. Die Farbvarianten (Sanzo Wada Paletten) bleiben erhalten.

---

## 0. Zusammenfassung der Entscheidungen (aus der Abstimmung)

| Thema | Entscheidung |
|---|---|
| **Sync** | Echter Cloud-Sync über **rclone als Mobile-Library (gomobile/XCFramework) + OAuth-Flow** — wird als **Architektur-Spezifikation** geliefert (in dieser Umgebung nicht baubar/testbar). |
| **Design** | Nur **iOS komplett nativ** (SF Pro, grouped Lists, Large Titles, native Sheets/Alerts, Haptik). Windows/Android bleiben unberührt. |
| **Priorität** | **Screen für Screen** — Design + Funktion gemeinsam: Onboarding → Dashboard → Tasks → Settings → Explorer/Vorschau. |
| **Onboarding** | **1 Schritt**: Willkommensseite mit „Loslegen" + Berechtigungsanfragen. Alles Weitere in der App. |

---

## 0.5 STAND NACH `main`-MERGE (Commit `3c3925f` — PR #3 „feature/ios-native-rclone")

> **Der Branch/Repo wurde auf den neuesten Stand von `main` gebracht.** PR #3 hat bereits einen großen Teil der echten rclone-Sync-Engine (Plan-Phase 7) eingebracht. **Bereits erledigt:**

- ✅ **Echte rclone-Engine auf iOS/Android** (`lib/core/services/ios_rclone_service.dart`, 450 Z.). `IosRcloneService` implementiert `RcloneService` mit echten rclone-Remote-Control-Aufrufen: `config/listremotes`, `config/create`, `operations/about` (Quota), `operations/list` (echte Cloud-Listing), `operations/copyfile`/`sync/copy` (echte Transfers), `operations/deletefile`, `core/stats` + `job/status` für **echten Fortschritt**.
- ✅ **Media-Staging mit echter 1:1-Hierarchie**: PhotoKit-Assets werden in einen Temp-Ordner (`Photos/<Album>/<file>`) exportiert und per rclone synchronisiert (`_stageMediaLibrary`).
- ✅ **`LibrcloneChannel`** (`lib/core/services/librclone_channel.dart`): MethodChannel `fibu/rclone` mit `initialize` + `rpc`; wirft `RcloneRpcException` bei echten Fehlern.
- ✅ **Native Swift-Bridge** (`ios/Runner/AppDelegate.swift`, +94): `RcloneBridge` verlinkt `librclone` (gomobile `Rclone.xcframework`), läuft off the main thread.
- ✅ **Build-Skript** (`ios/scripts/build_librclone.sh`): baut `librclone` (rclone v1.68.2) als XCFramework via `gomobile bind` → `ios/Frameworks/Rclone.xcframework`.
- ✅ **`rclone_provider.dart`** nutzt auf iOS/Android jetzt `IosRcloneService` statt der Attrappe `MobileRcloneService`.
- ✅ **`FileViewerService`** lädt jetzt echte Dateien herunter (`downloadToCache`) und öffnet sie per `open_filex` (Quick Look auf iOS); `getPreviewText` nutzt echtes `catFile`.
- ✅ **Neue Dependencies:** `open_filex`, `flutter_web_auth_2` (OAuth).
- ✅ **Onboarding massiv vereinfacht** (1326 → ~290 Z.): jetzt **3 kurze Apple-ähnliche Schritte** (Willkommen → Cloud verbinden → Zugriff erlauben) statt der früheren Überladung.

### 🟠 Noch offen / zu prüfen nach dem Merge

- ✅ **Datei-Vorschau** ist an die echte Engine angeschlossen (Commit `cc0ce9f`): `file_preview_dialog.dart` lädt das echte Bild via `getLocalFile`/`downloadToCache` und zeigt es mit `Image.file`; Fake-Metadaten (`4032 × 3024`) und Fake-Audio-Wellenform entfernt. → Plan-Phase 6 (Vorschau) umgesetzt.
- ✅ **rclone-Framework im Xcode-Projekt eingebettet + in CI gebaut** (Commit `cc0ce9f`): Link/Embed/`FRAMEWORK_SEARCH_PATHS`, Auto-Build-Phase „Build librclone (if missing)" **und** Go/gomobile-Steps in `.github/workflows/build-ios.yml` → kein `librclone_missing`-Fehler mehr.
- ✅ **Echtes Hintergrund-Scheduling** (Plan-Phase 8) umgesetzt: `workmanager`/`BGTaskScheduler`, `SchedulerService` + `main()`-Init + `AppDelegate` + Info.plist `UIBackgroundModes` (`fetch`,`processing`) + `BGTaskSchedulerPermittedIdentifiers`.
- ✅ **OAuth-Verdrahtung** (Plan-Phase 5, OAuth-Teil) umgesetzt: `OAuthService` (`flutter_web_auth_2` + `flutter_secure_storage`/Keychain), Add-Remote-Button startet echten Browser-Flow, `fibuoauth://`-Scheme. Die OAuth-URL nutzt jetzt **rclones eingebaute Standard-Credentials** (`getProviderClientCredentials()` → `config/providers`-Defaults, z. B. Google Drive) statt eines Platzhalters.
- ✅ **Natives iOS-Design** (Plan-Phase 3/4/5, Design-Teil) umgesetzt: zentrale `IosTheme` (SF Pro, Large Title), `IosHaptics`, Large Titles + Haptik auf Dashboard/Tasks/Settings. Die übrigen Plan-Phasen-3/4/5-Aufgaben (Explorer-Vollumbau, Wizards in grouped Sheets, Leerzustände) können iterativ folgen.

---

## 1. Ist-Zustand & Kernbefunde (Review-Ergebnis)

### 1.1 Funktionslücken
- **Sync (iOS/Android) ist eine Attrappe.** `MobileRcloneService` (`lib/core/services/mobile_rclone_service.dart`) verbindet sich nicht mit einer Cloud. `addRemote` schreibt nur lokale `rclone.conf`/`remotes.json`. `_executeMobileJob` scannt lokale Medien, schreibt Logs und **simuliert** Fortschritt (`Future.delayed(60ms)`, hartkodierte 5 MB/s). Kein Upload.
- **Fortschritt** hängt am nicht-funktionierenden Sync → simuliert, ETA erfunden.
- **Aufgaben-Zeitplan „iOS System" ist nur ein Label.** Kein echtes Hintergrund-Scheduling (kein `background_task`/`workmanager`-Plugin im `pubspec.yaml`). Aufgaben werden nie automatisch ausgelöst.
- **Datei-Vorschau funktioniert nicht.** `FilePreviewDialog` zeigt für Bilder ein Platzhalter-Icon mit erfundenen Metadaten („4032 × 3024 Pixel"), lädt nie das echte Bild. `FileViewerService.getPreviewText` liefert immer `'File content not found.'`; `openInDefaultApp` lädt die Datei nie herunter (gibt `false` zurück).
- **Cloud-Explorer (iOS) listet lokale Dokumente statt Cloud-Dateien** — `MobileRcloneService.listFiles` liest `getApplicationDocumentsDirectory()`.

### 1.2 Design-Lücken (iOS)
- iOS-Shell-Tab ist Cupertino (`CupertinoTabScaffold`), aber viele iOS-Screens mischen `material.*`-Widgets (z. B. `material.Divider`, `material.Material` in der Preview) und nutzen Custom-Container statt nativer Cupertino-Patterns.
- Keine konsequente SF-Pro-Typografie, keine grouped `CupertinoListSection`, teils fehlende native Sheets/Alerts/Haptik, kein `.insetGrouped`-Look.

### 1.3 Rahmenbedingungen & Risiken
- **In der Sandbox ist kein Flutter/Dart/Xcode installiert.** Code kann geschrieben, aber hier **nicht** kompiliert/getestet werden. Verifikation (Analyse, Widget-Tests, iOS-Build) läuft auf dem Rechner des Entwicklers (siehe §9).
- Echter Cloud-Sync über rclone als native Mobile-Library ist ein **großer nativer Aufwand** (XCFramework-Build, OAuth-Callbacks, Keychain, BackgroundTasks) und ist hier **nicht baubar**. Er wird als vollständige Spezifikation geliefert (Phase 7).

---

## 2. Leitprinzipien für „nativ Apple-ähnlich" (iOS)

Diese Prinzipien gelten **für alle iOS-Screens**:

1. **Ausschließlich Cupertino-Widgets** im iOS-Zweig. Kein `material.*` im iOS-Pfad. (Ausnahme: vom Theme gesetzte Basistypen, die Cupertino unterliegen.)
2. **SF-Pro-Systemschrift** über `CupertinoThemeData` (Standard von `CupertinoApp`). Keine manuellen Font-Angaben außer für semantische Gewichte.
3. **Große Titel** (`CupertinoNavigationBar` mit `LargeTitle`-Verhalten bzw. `.largeTitle`-Darstellung) auf den Haupt-Screens; mittlere Titel in Detail-/Formular-Screens.
4. **Grouped Listen** (`CupertinoListSection`/`CupertinoListTile`) mit `.insetGrouped`-Anmutung für Settings, Cloud Drives, Task-Details.
5. **Native Interaktionen:**
   - Alerts: `showCupertinoDialog` (kein `GestureDetector`-Text als Button).
   - Formulare/Modal-Wizards: `showCupertinoModalPopup` mit `CupertinoPageScaffold`/`CupertinoNavigationBar`.
   - Bottom Sheet statt Popup-Dialog für die Aufgaben-Einrichtung.
   - **Haptik** über `HapticFeedback.lightImpact()`/`mediumImpact()` bei Bestätigungen.
   - Übergänge: `CupertinoPageRoute` (inkl. Slide-Back-Geste) überall.
6. **44 pt Mindest-Touch-Targets**, WCAG-AA-Kontraste, `Semantics`-Labels.
7. **Farbvarianten bleiben.** Alle Farben kommen weiter aus `AppThemeData` (Sanzo Wada). Akzentfarbe = `theme.accent`, `primaryColor` in `CupertinoThemeData`.
8. **Leere Zustände & Fehler** als native, klare Zustände mit Handlungs-CTA, kein Roh-Text.

---

## 3. Gemeinsames iOS-Fundament (Phase 0)

**Ziel:** Eine wiederverwendbare Cupertino-Basisschicht, auf der alle iOS-Screens aufbauen — damit der Umbau konsistent und wartbar ist.

### Neue Dateien
- `lib/theme/ios_theme.dart` — `CupertinoThemeData`-Factory (Brightness hell/dunkel, Akzent aus `AppThemeData`, SF Pro, `textTheme` mit semantischen Styles, `barBackgroundColor` = `theme.surface`, `scaffoldBackgroundColor` = `theme.canvas`). Wird in `main.dart` im iOS-Zweig verwendet.
- `lib/features/shell/presentation/ios_components.dart` — gemeinsame iOS-Bausteine:
  - `IosLargeTitleBar` (NavigationBar mit großem Titel + trailing Actions)
  - `IosGroupedListSection` (Wrapper um `CupertinoListSection` mit Theme-Farben)
  - `IosEmptyState` (Icon + Titel + Text + CTA-Button, native Optik)
  - `IosStatusBanner` (gruppierter Sync-Status, ersetzt das Custom-Container-Banner)
  - `IosPrimaryButton` / `IosSecondaryButton` (44 pt, `theme.accent`)
  - `IosSectionCard` (für Kartensektionen mit `.insetGrouped`-Anmutung)

### Änderungen
- `lib/main.dart` — iOS-Zweig nutzt `iosTheme` und setzt `textTheme`/`primaryColor` zentral.
- Entfernen von `material.*`-Aufrufen im iOS-Pfad (Beispiel: `dashboard_screen.dart` `_buildIOS`, `file_preview_dialog.dart`).

### Akzeptanzkriterien
- `flutter analyze` fehlerfrei.
- Kein `material.*` mehr im iOS-Build-Pfad (durch Review + `grep` verifiziert).
- Alle iOS-Screens nutzen die gemeinsamen Bausteine.

---

## 4. Phase 1 — Onboarding (1 Schritt)

**Datei:** `lib/features/onboarding/presentation/onboarding_screen.dart` (auch `onboarding_controller.dart`, `app_strings.dart`).

### Design (native)
- **1 Seite** statt 3-Seiten-PageView: großes App-Icon/Logo, Titel („Willkommen bei Fibu"), kurzer Untertitel, eine prägnante Erklärung („Sichern Sie Ihre Fotos, Videos und Dateien automatisch in Ihrer Cloud.").
- **Eine klare CTA:** „Jetzt loslegen" (`CupertinoButton.filled`, `theme.accent`).
- Sekundär: „Cloud-Anbieter später verbinden" (dezent, als `CupertinoButton`-Text).
- SF Pro, Large Title, native `CupertinoPageScaffold`.

### Funktion (1 Schritt)
- „Loslegen" → Berechtigungen anfragen (Fotos via `PhotoManager.requestPermissionExtend()`, ggf. Benachrichtigungen), Onboarding abschließen (`onboardingControllerProvider`).
- „Cloud später verbinden" → nur Onboarding abschließen, ohne Berechtigungen.
- **Kein** automatisches Erstellen von Preset-Tasks mehr im Onboarding (das wird in den Dashboard/Task-Flow verschoben, damit der Erststart schnell ist).
- Sprach-/Design-Texte in `app_strings.dart` anpassen.

### Entfernen
- `_buildStep1/2/3`, `_buildFeatureCard`, `_buildWorkflowStepRow`, `_buildProviderBadge`, `_buildPrimaryButton`/`_buildAccentFinishButton` (Windows/Android können weiter eigene Builder behalten, falls gewünscht — Fokus iOS: iOS-Pfad nutzt nur den 1-Schritt-View).

### Akzeptanzkriterien
- Onboarding auf iOS = 1 Bildschirm, abschließbar mit 1 Tipp.
- Nach Abschluss gelangt man in die Shell (Dashboard).
- Berechtigungen werden korrekt angefragt und abgelehnt wird sauber behandelt.

---

## 5. Phase 2 — Shell & Navigation (iOS)

**Datei:** `lib/features/shell/presentation/shell_screen.dart`.

### Design (native)
- `CupertinoTabScaffold` bleibt, aber verfeinern:
  - `CupertinoTabBar` mit SF-Symbolen, `activeColor = theme.accent`, Blur-Hintergrund (`CupertinoTabBar` setzt nativen Blur automatisch).
  - Tab-Items: **Dashboard**, **Backups (Tasks)**, **Einstellungen**. (Label „Aufgaben" → „Backups" wirkt nativer.)
  - Richtige aktive/leere Symbolvarianten (z. B. `square_grid_2x2` / `square_grid_2x2_fill`).
- Jeder Tab bekommt seinen eigenen `CupertinoPageScaffold` mit Large Title (in den jeweiligen Screens).

### Funktion
- Shell bleibt Index-basiert; Tab-Wechsel persistiert via `shellIndexProvider`.
- Keine Material-Abhängigkeiten im iOS-Zweig.

### Akzeptanzkriterien
- iOS-TabBar wirkt wie native iOS-Navigation; Blur, SF-Symbole, Akzentfarbe korrekt.

---

## 6. Phase 3 — Dashboard (iOS)

**Datei:** `lib/features/dashboard/presentation/dashboard_screen.dart`, `widgets/storage_card.dart`, `widgets/dashboard_dialogs.dart`, `dashboard_controller.dart`.

### Design (native)
- `CupertinoPageScaffold` mit **Large Title** „Übersicht" + Refresh-Button (SF-Symbol `arrow_clockwise`).
- Sync-Statusbanner: `IosStatusBanner` (gruppierte Section, native Farben: `systemGreen`/`systemRed`/`systemGray`, Status aus `theme`).
- Speicherkarte: native Karte mit Quota, verwendet `StorageCard`, aber in `.insetGrouped`-Optik; Fortschrittsbalken in Cupertino-Stil.
- Aktiver-Job-Panel: native Karte mit `CupertinoActivityIndicator`, echtem Fortschrittsbalken (siehe Funktion).
- Aktionen: „Synchronisieren" (`CupertinoButton.filled`), „Abbrechen" (rot), „Cloud-Dateien durchsuchen" (getönte Fläche).
- Aktivitäts-Logs: native Vollbild-`CupertinoPageRoute` statt Custom-Dialog.

### Funktion
- **Fortschritt echt machen** (auch ohne echten Cloud-Upload, sobald Sync-Engine aktiv ist): Dashboard liest `activeJobProvider`; Prozent/Datei/ETA aus echten `RcloneProgressEvent`s.
- **Leere Zustände:** Keine Remotes → klare Meldung + CTA „Cloud verbinden" (öffnet Cloud-Drive-Manager). Keine aktiven Tasks → CTA „Backup anlegen".
- Trigger-Sync-All via `triggerSyncAll()` mit sauberer Fehler-/Abruchbehandlung.

### Akzeptanzkriterien
- Dashboard zeigt echte Progress-Events, saubere Leerzustände, native Optik.

---

## 7. Phase 4 — Tasks (Liste, Wizard, Detail)

**Dateien:** `tasks_screen.dart`, `task_detail_screen.dart`, `tasks_controller.dart`.

### Design (native)
- **Liste:** `CupertinoListSection` mit `CupertinoListTile` pro Backup (Icon, Name, Zeitplan-Subtitle, `CupertinoSwitch` für Aktiv). Swipe-to-delete via `CupertinoSlidable`/`CupertinoListTile`-Mechanik.
- **Wizard:** `showCupertinoModalPopup` mit `CupertinoNavigationBar` („Neues Backup"), Schritt-Indikator in Cupertino-Optik, `CupertinoListSection`-Formular. Reduzierte Komplexität: 
  - Schritt 1: Name + Quelle (Fotos/Videos/Ordner) — als `CupertinoSegmentedControl` oder Listenwahl.
  - Schritt 2: Ziel-Cloud + Zielordner.
  - Schritt 3: Zeitplan + Modus.
- **Detail:** `task_detail_screen.dart` im `CupertinoPageRoute`, grouped Sections (Status, Quelle, Ziel, Zeitplan, Modus, Exklusionen), native Buttons („Synchronisieren", „Löschen" mit `showCupertinoDialog`-Bestätigung, „Abbrechen").

### Funktion
- **Zeitplan-Eingabe:** Stunden/Minuten über native `CupertinoPicker`/Wheel. „Manuell", „Täglich", „Wöchentlich (Wochentag)".
- **Echte Persistenz:** `TasksListNotifier` speichert `tasks.json` weiterhin (bereits vorhanden); Sicherstellen, dass iOS-Pfad alle Felder (Sync-Mode, Zielordner, WifiOnly) korrekt speichert/lädt.
- **Validierung:** Name/Quelle/Ziel-Cloud mit Cupertino-Fehlermeldungen.
- **Scheduling:** Der ausgewählte Zeitplan wird gespeichert und von der Scheduling-Schicht (Phase 8) übernommen. „iOS System" als Option nur, wenn BackgroundTasks vorhanden (sonst ausblenden und „Automatisch" klarmachen).

### Akzeptanzkriterien
- Backup anlegen/ändern/löschen/aktivieren funktioniert vollständig über den iOS-Wizard.
- Zeitplanwerte werden korrekt gespeichert und geladen.

---

## 8. Phase 5 — Einstellungen, Cloud Drives & Add-Remote (OAuth)

**Dateien:** `settings_screen.dart`, `cloud_drives_screen.dart`, `rclone_provider.dart`, `rclone_service.dart`, `mobile_rclone_service.dart`.

### Design (native)
- **Settings:** `CupertinoListSection`-Gruppen (Darstellung, Cloud-Dienste, Sprache, WLAN-only, Info). `CupertinoSwitch`, `CupertinoSegmentedControl` (Hell/Dunkel/System), Farbpaletten-Auswahl als Cupertino-Zeilen mit Farbpunkten. Native Navigation zu Cloud Drives.
- **Cloud Drives:** `CupertinoListSection` der verbundenen Remotes mit `CupertinoListTile`, `CupertinoButton` „Cloud-Dienst hinzufügen", Swipe-to-delete mit Bestätigung.
- **Add Remote Wizard:** `showCupertinoModalPopup`, gestufte Auswahl (Beliebte Anbieter → Suche über alle rclone-Provider), Credentials-Formular in grouped Sections, OAuth-Button für OAuth-Anbieter (siehe Funktion).

### Funktion
- **OAuth-Flow** (siehe Phase 7-Spezifikation): Für Google Drive, OneDrive, Dropbox, Box, pCloud, MEGA usw. In-App-Browser/Authentifizierung; Token sicher im Keychain ablegen (nicht Klartext in `rclone.conf`).
- **Credential-/Password-Felder:** Werte über `obscurePassword` verschlüsseln; auf iOS in Keychain (`flutter_secure_storage`) speichern.
- `MobileRcloneService.addRemote/listRemotes/removeRemote` an die **echte rclone-Engine** (Phase 7) anbinden.

### Akzeptanzkriterien
- Cloud-Dienst hinzufügen/entfernen funktioniert; OAuth-Anbieter können sich authentifizieren (nach Einbindung der Engine).
- Passwörter/Tokens sicher gespeichert.

---

## 9. Phase 6 — Cloud-Explorer & Datei-Vorschau

**Dateien:** `cloud_explorer_screen.dart`, `file_preview_dialog.dart`, `file_viewer_service.dart`, `file_metadata_helper.dart`.

### Design (native)
- **Explorer:** `CupertinoPageRoute`, `CupertinoNavigationBar` mit Back-Geste, Breadcrumb/Drive-Auswahl, `CupertinoListSection`-Darstellung der Dateien/Ordner, Refresh (`arrow_clockwise`), Pull-to-Refresh.
- **Vorschau:** native Vollbild-Vorschau im Quick-Look-Stil. Bilder wirklich laden und anzeigen; Zoom per Pinch (`InteractiveViewer`); Text-/Code-Dateien als native `CupertinoTextField`-Lesemodus (monospace); Video/Audio über `VideoPlayer`/`audioplayers` (native Player) statt Platzhalter.
- Toolbar: Öffnen in externer App (SF-Symbol `square.and.arrow.up`), Kopieren, Teilen, Löschen (Bestätigung).

### Funktion
- **Echte Downloads:** `FileViewerService.openInDefaultApp` lädt die Datei zuerst herunter (via `rclone copyto`/Stream) in `getTemporaryDirectory()`, dann öffnet sie. `getPreviewText` ruft `rclone cat` auf (echte Datei).
- **Bilder:** über `rclone cat`/Herunterladen in den Cache, mit `Image.file`/`Image.memory` anzeigen — **keine** erfundenen Metadaten.
- **Explorer listet echte Cloud-Dateien** über `MobileRcloneService.listFiles` → echte rclone-`lsjson`-Engine.
- Leere Zustände und Fehler (Offline, keine Remotes) mit CTA.

### Akzeptanzkriterien
- Datei-Vorschau zeigt reale Inhalte (Bild, Text, Video, Audio).
- Explorer zeigt echte Cloud-Struktur; Öffnen/Teilen/Löschen funktioniert.

---

## 10. Phase 7 — Sync-Engine: rclone als Mobile-Library + OAuth (Architektur-Spezifikation)

> **Hinweis:** Diese Phase ist der große native Umbau. Sie ist hier **nicht baubar/testbar** (kein Xcode/rclone-Build) und wird als vollständige Spezifikation + Umsetzungsfahrplan geliefert.

### 10.1 Zielbild
- iOS nutzt **rclone als echte Engine** (nicht die Attrappe `MobileRcloneService`), eingebunden als **XCFramework** via gomobile (`librclone`), angesprochen über eine schlanke FFI-/MethodChannel-Schicht. Dies entspricht dem offenen todo.md-Punkt 1.

### 10.2 Build-Pipeline (iOS)
1. rclone als Go-Modul (`github.com/rclone/rclone`) mit `gomobile bind` zu `librclone.xcframework` kompilieren (arm64 iOS, arm64 Simulator, x86_64 Simulator, ggf. macOS Catalyst).
2. XCFramework in `ios/` einbinden: `Runner.xcodeproj` (Build-Phasen, `OTHER_LDFLAGS`, `FRAMEWORK_SEARCH_PATHS`), `Runner-Bridging-Header.h`.
3. Eine Swift-Bridge `RcloneBridge.swift` kapselt `librclone`-Aufrufe (C-Callbacks) und exponiert sie über einen **MethodChannel** (`fibu/rclone`) bzw. einen **Dart FFI**-Wrapper.
4. Android (später): analog als AAR. Windows nutzt bereits `rclone.exe`.

### 10.3 Dart-Anbindung
- Neue Implementierung `NativeRcloneService` (`lib/core/services/native_rclone_service.dart`) implementiert `RcloneService` und delegiert an den MethodChannel/FFI.
- `rclone_provider.dart` wählt auf iOS `NativeRcloneService` statt `MobileRcloneService` (Feature-Flag `USE_NATIVE_RCLONE`).
- `MobileRcloneService` wird auf die Funktionalität reduziert, die rein lokal bleibt (Scan von Medien/Files) und delegiert Upload/Download/Listing an die Native-Engine.

### 10.4 Konfiguration & sicherer Credential-Speicher
- `rclone.conf` wird in App-Support abgelegt, aber **Passwörter/Tokens nicht im Klartext**: Tokens über `flutter_secure_storage` (Keychain) speichern; rclone nutzt `obscure` bzw. `--password-command`/Keychain-Referenz.
- `addRemote`/`removeRemote/listRemotes/getQuota/listFiles/deleteFile/catFile/copyFileToRemote/downloadDirectory` reiten auf echten rclone-Kommandos (`config create/delete`, `about`, `lsjson`, `deletefile`, `cat`, `copyto`, `copy`).

### 10.5 OAuth-Flow
1. Provider-Typen mit OAuth (Drive, OneDrive, Dropbox, Box, pCloud, MEGA …) über rclone `config` mit `client_id/client_secret` initialisieren.
2. **In-App-Autorisierung:** `flutter_web_auth_2`/`ASWebAuthenticationSession` (nativ auf iOS) öffnet die Autorisierungs-URL.
3. Rückkehr-URL (Custom Scheme, z. B. `fibu://oauth2`) in `Info.plist` (`CFBundleURLTypes`) registrieren.
4. rclone tauscht Code gegen Token; Token in Keychain speichern; `rclone.conf` mit verweisenden, verschleierten Werten aktualisieren.
5. Refresh-Token-Handling in der Bridge.

### 10.6 Fortschritt & Status (echt)
- rclone mit `--use-json-log --stats 1s` (wie in `WindowsRcloneService`) aufrufen; JSON-Stats in `RcloneProgressEvent` parsen (echte `bytes`, `speed`, `eta`, `totalBytes`, aktueller Dateiname).
- `watchJobStatus`/`watchJobProgress` streamen echte Events an Dashboard/Tasks.

### 10.7 Zustands-/Fehlermaschine
- Netzwerk-`connectivity_plus`-Guard bleibt; bei Offline → sauberer „Pausiert"-Status.
- Fehler (Auth abgelaufen, Quota voll, Netzwerk) mit Klartext + Wiederholen-CTA in der UI.

### 10.8 Deliverables dieser Phase
- Go-`bind`-Setup + CI-Workflow (GitHub Actions, macOS-Runner) zum Bauen des XCFrameworks.
- `NativeRcloneService` + Bridge (Swift/Dart FFI).
- OAuth-Integration + Keychain.
- Mapping-Tabelle: jede `RcloneService`-Methode → rclone-Kommando + Quellcode-Referenz.
- Umsetzungs-Roadmap mit Meilensteinen und Verifikation auf einem echten Gerät.

---

## 11. Phase 8 — Hintergrund-Scheduling (BackgroundTasks)

- Plugin `flutter_background_task` bzw. iOS `BackgroundTasks` (`BGTaskScheduler`) ergänzen.
- Zeitpläne aus `BackupTask.schedule*` (Täglich/Wöchentlich/Manuell) in `BGAppRefreshTask`/`BGProcessingTask` überführen.
- „iOS System"-Option nur anbieten, wenn dieses Modul verfügbar ist; sonst ausblenden.
- WLAN-only-Guard im Hintergrund einhalten.

---

## 12. Phase 9 — QA, Tests & Doku

### Statische Analyse
- `flutter analyze` → 0 Issues.
- `grep -rn "material\." lib/features/*/presentation/*ios*` etc.: kein Material im iOS-Pfad.

### Tests
- **Unit:** `tasks_controller` (Persistenz rund), `rclone_service`-Mocks (Status/Progress-Events), `sync_manifest_service`.
- **Widget:** iOS-Dashboard (Fortschritt), iOS-Task-Wizard (Validierung/Speichern), Onboarding (1-Schritt), Settings (Palette/Sprache), Explorer/Vorschau (leere/Fehlerzustände).
- **Integration (manuell auf Gerät):** OAuth-Anmeldung, echter Upload, Datei-Vorschau, Hintergrund-Sync.
- Bestehende `test/widget_test.dart` aktualisieren.

### Doku
- README/`todo.md` aktualisieren: neue Phasen abhaken, offene Punkte (rclone gomobile) präzisieren.
- `docs/UMSETZUNGSPLAN.md` als Referenz behalten.

---

## 13. Umsetzungs-Reihenfolge & Aufwand (groß)

| # | Phase | Aufwand (rel.) | Abhängigkeit |
|---|---|---|---|
| 0 | iOS-Fundament | M | — |
| 1 | Onboarding (1 Schritt) | S | 0 |
| 2 | Shell/Navigation | S | 0 |
| 3 | Dashboard + echter Fortschritt | M | 0 |
| 4 | Tasks (Liste/Wizard/Detail) | L | 0 |
| 5 | Einstellungen + Cloud Drives + OAuth | L | 0 (UI), 7 (OAuth) |
| 6 | Explorer + Datei-Vorschau | L | 7 (echte Inhalte) |
| 7 | Sync-Engine (rclone gomobile + OAuth) | XL | — |
| 8 | Hintergrund-Scheduling | M | 7 |
| 9 | QA & Doku | M | alle |

> **Empfehlung zur Reihenfolge:** Phase 0–4 sind in reinem Dart auf iOS umsetzbar (natives Design + Fortschritt + Wizard) und sofort wirksam. Phase 5 (OAuth-UI) und 6 (Vorschau/Explorer) brauchen die echte Engine (Phase 7), um vollständig zu funktionieren; die UI kann aber schon gebaut werden, mit klaren „verbindungsabhänge" Zuständen.

---

## 14. Offene Punkte / Annahmen
- Aufwand & Build der rclone-gomobile-Phase setzt macOS/Xcode + ein Apple-Entwicklerkonto voraus (außerhalb dieser Sandbox).
- Benennung „Aufgaben" → „Backups" im iOS-Pfad wird vorgeschlagen; bitte bestätigen.
- Automatische Preset-Erstellung entfällt aus dem Onboarding (wird in Dashboard/Tasks verschoben).
