# Fibu — Apple-Konformitäts-Audit (Backend & Frontend)

**Datum:** 2026-08-17
**Rolle:** Apple Backend- & Frontend-Auditor
**Fokus:** „Apple-nativ" in jeder Hinsicht (Look & Feel, Verhalten, Plattform-Konventionen, Backend-Integration), bei erhaltenen Farbvarianten (Sanzo Wada).
**Bewertung:** 🟥 kritisch · 🟧 verbesserungswürdig · 🟩 konform.

---

## Frontend / UI

### 🟩 Cupertino-Grundlage & Shell
- iOS nutzt `CupertinoTabScaffold` + `CupertinoTabBar` mit SF-Symbolen und Blur (native iOS-Navigation). ✅
- `CupertinoTabController` wird einmal erzeugt (StatefulWidget) → Tab-Zustand/Scroll-Positionen bleiben erhalten. ✅
- `IosTheme` (SF Pro, Large Titles, `primaryColor` aus Sanzo-Wada) zentral in `main.dart`. ✅
- `SafeArea` auf den Haupt-Screens (Dashboard, Tasks, Settings, Explorer, Detail). ✅

### 🟩 Formulare & Listen
- Einstellungen/Detail/Cloud-Drives: grouped `CupertinoListSection.insetGrouped`. ✅
- Native `CupertinoSwitch`, `CupertinoSlidingSegmentedControl`, `CupertinoActionSheet`, `CupertinoAlertDialog`, `CupertinoModalPopup`, `CupertinoPageRoute`. ✅

### 🟩 Datei-Vorschau (nach Fix)
- iOS rendert ein vollflächiges `CupertinoPageScaffold` (keine Desktop-Box), mit Cupertino-Navbar, `SelectableText`, `CupertinoActivityIndicator`, `InteractiveViewer`. ✅
- Desktop-Zweige (Fluent/Material) bleiben getrennt — korrekt bei adaptiver App. ✅

### 🟧 Aufgeräumt, aber Punkte offen
- **Dark Mode / Farbkontrast:** Farben kommen aus den Sanzo-Wada-Paletten (`AppThemeData`). Kontrast (WCAG AA) ist nicht für jede Palette garantiert — bewusst erhaltene Farbvarianten, aber pro Palette zu prüfen.
- **Dynamische Typografie:** Feste Schriftgrößen sind durchgängig; die Vorschau ist jetzt responsiv/scrollbar. Andere Screens sollten bei sehr großen Accessibility-Fonts getestet werden.
- **`Semantics`/VoiceOver:** Viele `semanticLabel`/`Semantics` vorhanden; Album-/Ordner-Tiles haben `checked/toggled`. Empfehlung: VoiceOver-Durchlauf auf Gerät.

---

## Backend / Plattform-Integration

### 🟩 Berechtigungen (Info.plist)
- `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` vorhanden (Mediathek lesen + hinzufügen). ✅
- `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` (Dateien in Files-App). ✅
- `UIBackgroundModes` (`fetch`, `processing`) + `BGTaskSchedulerPermittedIdentifiers` für Hintergrund-Sync. ✅
- `CFBundleURLTypes` mit `fibuoauth://` für OAuth. ✅

### 🟩 rclone-Integration (echte Engine)
- iOS nutzt `IosRcloneService` (rclone `librclone`) — professionell, Passwörter via `config/create` + `obscure`. ✅
- Config/Manifest/Tombstones sind als JSON strukturiert und werden korrekt gehandhabt. ✅
- `librclone_missing`-Fehler behoben (Framework in Xcode + CI-Build). ✅

### 🟧 App-Architektur / Apple-Konventionen
- **Haptik:** `IosHaptics` an Schlüsselaktionen — gut. Fehlt an einigen Stellen (z. B. Tab-Wechsel, einzelne Listen-Auswahlen). Empfehlung: konsequent an Touch-Ende anwenden.
- **Navigation & Back:** Cupertino-Slide-Back-Geste über `CupertinoPageRoute` vorhanden. ✅
- **Fehlerbehandlung:** Netzwerk-/Offline-Guard + `RcloneRpcException` → Klartext-Fehler. Einige Fehler landen noch als roher Text in der UI (niedrige Priorität, User-facing-Fehlerstring).
- **Datenschutz:** OAuth-Token in Keychain (`flutter_secure_storage`). ✅

---

## Konformität gesamt

| Bereich | Status |
|---|---|
| Navigation (TabBar, Slide-Back, Push) | 🟩 |
| Listen/Formulare (grouped, native Controls) | 🟩 |
| Systemschrift (SF Pro), Large Titles | 🟩 |
| Berechtigungen & Hintergrundmodi | 🟩 |
| Datei-Vorschau nativ & responsiv | 🟩 |
| Haptik | 🟧 (ausbauen) |
| Dynamische Typografie / Kontrast | 🟧 (pro Palette/Gerät testen) |
| VoiceOver-Semantics | 🟧 (Geräte-Durchlauf) |
| Backend (rclone, Keychain, JSON-Config) | 🟩 |

---

## Empfohlene nächste Schritte (Apple-Polish)
1. **Haptik vervollständigen** (Tab-Wechsel, Listen-Auswahl) — kleiner, sofortiger Gewinn.
2. **Fehler-Strings zentralisieren** (statt roher `$e`) für konsistente, freundliche Meldungen.
3. **VoiceOver- und Dynamic-Type-Test** auf echten Geräten (automatisierbar teils via Integration-Tests).
4. **Kontrast je Sanzo-Wada-Palette prüfen** (WCAG AA), ohne Farben zu verlieren.

---

*Hinweis: Verifikation (Compile, `flutter analyze`, iOS-Build, Geräte-Tests) läuft über die GitHub-Actions-CI / ein echtes iOS-Gerät; in dieser Umgebung ist kein Flutter/Xcode installierbar.*
