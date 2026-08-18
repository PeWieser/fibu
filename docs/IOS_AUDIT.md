# Fibu — iOS-Audit (Funktion · Design · Accessibility)

**Datum:** 2026-08-17
**Umfang:** Kompletter iOS-Pfad (Onboarding, Shell, Dashboard, Tasks inkl. Wizard/Detail, Einstellungen, Cloud Drives, Cloud Explorer, Datei-Vorschau).
**Methode:** Statische Code-Prüfung der iOS-Build-Pfade. Kein Compile/Simulator in dieser Umgebung möglich → Verifikation läuft über GitHub-Actions-CI (macOS).

**Bewertungsskala:** 🟥 Kritisch · 🟧 Hoch · 🟨 Mittel · 🟩 Niedrig.

---

## Zusammenfassung

Die iOS-App ist **weitgehend nativ und konsistent aufgebaut**: Cupertino-Screens, grouped `CupertinoListSection`, `IosTheme` (SF Pro, Large Titles), `IosHaptics`, viele 44-pt-Touch-Targets, `Semantics`-Labels, Bestätigungsdialoge für destruktive Aktionen. Die rclone-Engine ist echt verdrahtet (Config, Listing, Transfers, Quota, Fortschritt). Es gibt aber einige **relevante Befunde** — v. a. ein **Desktop-Dialog-Fehler in der Datei-Vorschau**, eine **simulierte Download-Aktion** und ein **behobener Swipe-to-Delete-Bug in Cloud Drives**.

---

## A) Funktionale Abläufe

### 🟥 1. Datei-Vorschau ist ein Desktop-Dialog und läuft auf dem iPhone über
**Datei:** `lib/features/dashboard/presentation/widgets/file_preview_dialog.dart`
- Fester `Container(width: 720, height: 600)` → auf jedem iPhone (≤ ~430 pt Breite) **Overflow**.
- Auf iOS wird der Dialog zwar per `CupertinoPageRoute(fullscreenDialog: true)` geöffnet (aus `cloud_explorer_screen.dart`), rendert aber eine Desktop-Box.
- **Empfehlung:** iOS-Variante als natives, vollflächiges `CupertinoPageScaffold` mit SafeArea + scrollbarem Inhalt; Desktop bleibt bei `width:720/height:600`.

### 🟧 2. „Download" im Cloud-Explorer ist simuliert
**Datei:** `lib/features/dashboard/presentation/cloud_explorer_screen.dart` (`_simulateDownload`)
- Die Aktion zeigt nur „Erfolgreich" an, lädt aber **nichts** herunter. Echte Datei gibt es bereits via `IosRcloneService.downloadToCache`/`downloadDirectory`.
- **Empfehlung:** `_simulateDownload` durch `downloadDirectory`/`downloadToCache` ersetzen (auf iOS z. B. in die Files-App bzw. Cache speichern und öffnen).

### 🟧 3. „Jetzt synchronisieren" (Task-Detail) synchronisiert ALLE aktiven Tasks
**Datei:** `lib/features/tasks/presentation/task_detail_screen.dart` (`_handleSyncNow`)
- Ruft `triggerSyncAll()` auf → startet die komplette aktive Queue, nicht nur die geöffnete Aufgabe. Auf der Detail-Seite eines einzelnen Backups ist das irreführend.
- **Empfehlung:** `startBackupJob` für genau diesen Task direkt aufrufen (oder `triggerSync` mit taskId).

### 🟨 4. Leere Album-Auswahl = „alle Alben"
**Datei:** `lib/features/tasks/presentation/tasks_screen.dart`
- Im Wizard: Wer alles abwählt, bekommt `all` (alle Alben) — semantisch überraschend.
- **Empfehlung:** Expliziter Zustand „Keine Auswahl" mit Hinweis oder Default „alle" klar beschriften.

### 🟨 5. Zielordner „Vorhandener Ordner" listet nur die Root-Ebene
**Datei:** `lib/features/tasks/presentation/tasks_screen.dart` (`_loadRemoteTargetFolders`)
- Ruft `listFiles(remote, '')` → nur Top-Level-Ordner. Kein Drill-down in Unterordner.
- **Empfehlung:** Navigation in Unterordner (wie im Explorer) oder Breadcrumb einbauen.

### 🟨 6. Hintergrund-Scheduler ignoriert den gewählten Zeitplan granular
**Datei:** `lib/core/services/scheduler_service.dart`
- Periodischer Task (alle 2 h) läuft, prüft nur `isActive`, nicht `scheduleDay/Time`. „Täglich 02:00" / „Wöchentlich Mo" werden nicht exakt eingehalten.
- **Empfehlung:** Zeitplan-Felder im Background-Task auswerten bzw. echte `BGProcessingTask`-Intervalle nutzen.

### ✅ Positiv
- Echte rclone-Engine (Config/Listing/Transfers/Quota/Fortschritt) korrekt verdrahtet.
- Swipe-to-Delete (Tasks) nach Fix sauber über `onDismissed`.
- Cloud-Explorer listet Remote (nie lokal); Datei-Vorschau lädt echte Bilder.

---

## B) Design-Konsistenz

### 🟥 7. Datei-Vorschau bricht den iOS-Look (Fluent/Material im iOS-Pfad)
- `file_preview_dialog.dart` nutzt `fluent.FluentIcons` (Windows-Glyphen), `material.Material`/`material.Divider`, `fluent.Tooltip`/`fluent.IconButton`/`fluent.FilledButton`. Das ist auf iOS **nicht nativ** und sticht heraus.
- **Empfehlung:** Cupertino-Variante (SF-Symbole, `CupertinoButton`, native Toolbar); `IosHaptics` für Zoom/Close.

### 🟨 8. Onboarding ist hartcodiert Deutsch (ignoriert AppStrings)
**Datei:** `lib/features/onboarding/presentation/onboarding_screen.dart`
- Alle Texte (`'Willkommen bei Fibu'`, `'Loslegen'`, `'Fotos erlauben'`, …) sind deutsch hardcodiert. Das App-i18n-System (`AppStrings`/`AppLocale`) wird hier umgangen → englische Nutzer sehen Deutsch.
- **Empfehlung:** Texte in `AppStrings` auslagern und `context.strings` verwenden.

### 🟩 9. Shell-Tab erstellt `CupertinoTabController` bei jedem Build neu
**Datei:** `lib/features/shell/presentation/shell_screen.dart`
- `CupertinoTabController(initialIndex: activeIndex)` wird pro Rebuild neu erzeugt → Tab-Inhalte (via `tabBuilder`) werden neu gebaut, Scroll-Positionen können verloren gehen.
- **Empfehlung:** `CupertinoTabController` in einem `StatefulWidget` halten.

### 🟩 10. Leerzustände nicht durchgängig mit CTA
- Dashboard (nach meinem Fix) und Settings sind in Ordnung; **Cloud Drives** Leerzustand ist nur Text+Icon, ohne „Cloud-Dienst hinzufügen"-Aktion (der Add-Button ist nur in der Navbar).
- **Empfehlung:** Leerzustand mit CTA ergänzen (HIG).

---

## C) Accessibility

### 🟨 11. Dynamische Typografie / Overflow bei großen Accessibility-Schriften
- Viele feste Schriftgrößen + **fixe Container** (v. a. die 720×600-Vorschau). Flutter skaliert Text per `textScaler`, aber fixe Höhen/Breiten können bei großen Fonts überlaufen.
- **Empfehlung:** Vorschau responsiv; scrollbare/stackende Layouts statt fixer Größen.

### 🟨 12. Onboarding-Touch-Targets nicht explizit 44 pt
- Der „Weiter/Loslegen"-Button (`CupertinoButton` in `SizedBox(width: double.infinity)`) garantiert keine `minHeight:44`. HIG verlangt ≥ 44 pt.
- **Empfehlung:** `ConstrainedBox(minHeight: 44)` bzw. `minimumSize` setzen.

### 🟩 13. Album-/Ordner-Listen im Wizard ohne Auswahl-`Semantics`
- `CupertinoListTile` mit Häkchen sind tappbar und lesbar, aber VoiceOver meldet nicht „ausgewählt". 
- **Empfehlung:** `Semantics(checked: ..., toggled: ...)` auf den Tiles.

### 🟩 14. Kontrast hängt von Sanzo-Wada-Paletten ab
- `textSecondary` auf `canvas` ist aus den Paletten abgeleitet; WCAG-AA ist nicht in allen Paletten garantiert. Farbvarianten bleiben (Wunsch), Kontrast sollte je Palette geprüft werden.

### ✅ Positiv
- `Semantics`-Labels, `semanticLabel` auf Icons, Bestätigungsdialoge, 44-pt-Konstraints an vielen Buttons, `IosHaptics` an Schlüsselaktionen, native Cupertino-Switches/Sheets.

---

## D) In dieser Session bereits behoben

### 🟧 Cloud Drives Swipe-to-Delete-Bug (behoben)
**Datei:** `lib/features/settings/presentation/cloud_drives_screen.dart`
- **Problem:** `confirmDismiss` rief die asynchrone Löschung auf UND gab `true` zurück (kein `onDismissed`), während der State per Provider-Invalidierung erst später aktualisiert wird → „dismissed Dismissible still part of the tree"-Fehler/Wackeln.
- **Fix:** `confirmDismiss` gibt nach Bestätigung jetzt `false` zurück und stößt `_performDelete` selbst an; das `Dismissible` animiert die Zeile nicht selbst, die Zeile verschwindet sauber über den Provider-Rebuild.

---

## E) Priorisierte Empfehlungen

| Prio | Maßnahme |
|---|---|
| 1 | Datei-Vorschau auf iOS nativ + responsiv umbauen (Behebt #1 und #7) |
| 2 | Echten Download im Cloud-Explorer implementieren (#2) |
| 3 | Task-Detail „Sync now" auf den einzelnen Task begrenzen (#3) |
| 4 | Onboarding-Texte in AppStrings auslagern (#8) |
| 5 | Zielordner-Unterordner + Leere-Auswahl-Hinweis im Wizard (#4, #5) |
| 6 | Scheduler-Zeitpläne granular auswerten (#6) |
| 7 | Touch-Targets/`Semantics`/Dynamische Typo in Vorschau & Onboarding (#11–13) |

---

## F) Nächste Schritte
- Da hier kein Flutter/Xcode installiert werden kann, sollten die empfohlenen Fixes in der CI (GitHub Actions) über `flutter analyze` + Widget-/Unit-Tests verifiziert werden.
- Für die Vorschau-Umbau (Prio 1) und den echten Download (Prio 2) sind Tests auf einem echten Gerät sinnvoll.
