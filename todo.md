# Fibu — Offene Aufgaben

Stand: 2026-08-08

---

## Sofort (Blocker)

- [ ] **rclone als Mobile-Library integrieren**
  - Android: `librclone/gomobile` als AAR bauen und im lokalen Expo-Modul aufrufen.
  - iOS: `librclone/gomobile` als XCFramework bauen und im Pod verlinken.
  - Keine ausführbaren Desktop-/Linux-Binaries in beschreibbaren App-Speicher kopieren.
  - Bis dahin baut die App-Shell für beide Plattformen; native rclone-Aufrufe liefern bewusst `NotImplemented`.

---

## Native Module — Android

- [x] **Expo Module registrieren**
  - Moderne Expo-Autoverlinkung über `expo-module.config.json`.
  - Kein manuelles `RclonePackage.kt` erforderlich.
  - Mit `expo-modules-autolinking resolve --platform android` geprüft.

- [ ] **librclone-AAR integrieren**
  Der nicht mobilefähige Asset-/`ProcessBuilder`-Ansatz wurde entfernt. Der aktuelle Android-Stub lehnt rclone-Aufrufe explizit ab, bis das AAR verlinkt ist.

- [ ] **Foreground-Service für laufende rclone-Syncs** implementieren
  (Verhindert, dass Android einen aktiven librclone-Job im Hintergrund beendet.)

---

## Native Module — iOS

- [x] **`RcloneModule.swift` automatisch einbinden**
  - `Rclone.podspec` und Apple-Moduldeklaration ergänzt.
  - Mit `expo-modules-autolinking resolve --platform apple` geprüft.

- [ ] **Prozess-Prototyp durch librclone-XCFramework ersetzen**
  `Foundation.Process` und ein macOS-rclone-Binary sind auf iOS nicht verfügbar. Der aktuelle iOS-Bridge-Stub lehnt daher jeden Aufruf explizit ab, bis ein echtes Mobile-Framework verlinkt ist.

---

## OAuth-Flow

- [ ] **OAuth-Flow vollständig implementieren**
  - `startOAuthFlow(provider)` → öffnet Authorize-URL im In-App-Browser (`expo-web-browser`)
  - Callback-URL wird von `expo-auth-session` abgefangen
  - `exchangeOAuthCode(provider, code)` speichert Token via `config/create`
  - Betrifft: Google Drive, OneDrive, Dropbox, Box, pCloud, Yandex, Jottacloud, Koofr, Zoho, HiDrive, Proton Drive, Mail.ru

---

## Features

- [ ] **Sync-Regeln UI** — Screen zum Anlegen/Bearbeiten von Sync-Regeln (Quellordner → Remote-Pfad, Zeitplan)
- [ ] **Background-Sync** — `expo-task-manager` + `expo-background-fetch` für automatische Hintergrund-Syncs verdrahten
- [ ] **Sync-Fortschritt** — `subscribeToProgress` / `subscribeToJobStatus` in der UI anzeigen (Progress-Bar, Logs)
- [ ] **Konflikt-Strategie** — UI für `--conflict-resolve` Option (winner: newer, larger, etc.)
- [ ] **Offline-Handling** — `expo-network` nutzen um Sync bei fehlendem Netz zu pausieren
- [ ] **Crypt-Remote einrichten** — UI-Flow für verschlüsselten Remote (Passwort-Eingabe, Salt)

---

## Qualität

- [x] **App- und Test-Typecheck auf 0 Fehler bringen** — inklusive NativeWind-CSS-Deklaration
- [x] **Jest-Tests für RcloneService** — Native-Initialisierung und alle RPC-/OAuth-Pfade gemockt
- [ ] **Maestro E2E** — Flows für AddRemote-Screen, Provider-Suche, Remote löschen
- [ ] **App-Icon + Splash Screen** — Assets für "Fibu" erstellen (ersetzt Expo-Platzhalter)

---

## Später

- [ ] **Git LFS** für rclone-Binaries einrichten (Binaries nicht direkt ins Repo commiten)
- [ ] **CI: rclone download cachen** — Binary in GitHub Actions-Cache legen statt immer neu laden
- [ ] **Android x86_64** — zweite ABI für Emulator-Tests (aktuell nur arm64-v8a)
- [ ] **Fastlane / EAS Build** — automatisiertes Build + Submit für iOS und Android
