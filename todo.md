# Fibu — Offene Aufgaben

Stand: 2026-08-08

---

## Sofort (Blocker)

- [ ] **`.github/workflows/ci.yml` manuell editieren** (GitHub MCP-Token hat kein `workflows`-Scope)
  - `node-version: '24'` → `'22'`
  - Java-Setup-Schritt **vor** dem Node-Setup einfügen:
    ```yaml
    - uses: actions/setup-java@v4
      with:
        distribution: 'temurin'
        java-version: '21'
    ```

- [ ] **`scripts/download-rclone.sh` einmalig ausführen** bevor der erste Build läuft:
  ```bash
  chmod +x scripts/download-rclone.sh
  ./scripts/download-rclone.sh
  ```
  Legt die rclone-Binaries ab in:
  - `modules/rclone/android/src/main/assets/rclone/rclone` (arm64-v8a)
  - `modules/rclone/ios/Resources/rclone/rclone` (arm64)

---

## Native Module — Android

- [ ] **Expo Module in `modules/rclone/android/` registrieren**
  Sicherstellen, dass `RcloneModule` in der `ExpoModulesCore`-Packages-Liste steht.
  Anlegen: `modules/rclone/android/src/main/java/expo/modules/rclone/RclonePackage.kt`
  ```kotlin
  class RclonePackage : ExpoModulesPackage() {
    override fun createModules(context: ReactApplicationContext) = listOf(RcloneModule())
  }
  ```

- [ ] **Assets-Ordner in Android-Gradle-Build einbinden** (falls `expo prebuild` ihn nicht automatisch übernimmt):
  In `modules/rclone/android/build.gradle` prüfen ob `sourceSets.main.assets.srcDirs` auf den richtigen Pfad zeigt.

- [ ] **Foreground-Service für laufende rclone-Syncs** implementieren
  (Verhindert, dass Android den `rclone rcd`-Prozess im Hintergrund killt.)

---

## Native Module — iOS

- [ ] **`RcloneModule.swift` in Xcode-Target einbinden**
  Nach `expo prebuild --platform ios` die Datei im Xcode-Projekt dem Target hinzufügen.

- [ ] **Rclone-Binary Bundle Resources**
  `modules/rclone/ios/Resources/rclone/` dem Xcode-Target als „Copy Bundle Resources"-Phase hinzufügen.

- [ ] **Entitlement für ausführbare Dateien** (App Store / TestFlight)
  `com.apple.security.cs.allow-unsigned-executable-memory` oder alternativ rclone via `xcrun codesign` signieren.

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

- [ ] **`tsc --noEmit` auf 0 Fehler bringen** — nach `expo prebuild` generierte Typen prüfen
- [ ] **Jest-Tests für RcloneService** — Mock für `nativeModule.rpcCall`, alle 11 Methoden testen
- [ ] **Maestro E2E** — Flows für AddRemote-Screen, Provider-Suche, Remote löschen
- [ ] **App-Icon + Splash Screen** — Assets für "Fibu" erstellen (ersetzt Expo-Platzhalter)

---

## Später

- [ ] **Git LFS** für rclone-Binaries einrichten (Binaries nicht direkt ins Repo commiten)
- [ ] **CI: rclone download cachen** — Binary in GitHub Actions-Cache legen statt immer neu laden
- [ ] **Android x86_64** — zweite ABI für Emulator-Tests (aktuell nur arm64-v8a)
- [ ] **Fastlane / EAS Build** — automatisiertes Build + Submit für iOS und Android
