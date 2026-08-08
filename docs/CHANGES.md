# Fibu — Änderungsprotokoll (Session 2026-08-08)

Vollständige Dokumentation aller Änderungen, die in dieser Session vorgenommen wurden.

---

## 1. CI-Fix: ESLint-Peer-Dependency-Konflikt

**Problem:** `eslint-plugin-react-native-a11y@3.5.1` deklariert `peer eslint@"^3||…||^8"`.
Das Projekt nutzt ESLint 10 → `npm ci` scheitert mit Peer-Dependency-Fehler.

**Lösung:** Plugin vollständig entfernt. Die App setzt `accessibilityRole`, `accessibilityLabel`
und 44pt Touch-Targets bereits manuell korrekt um.

**Dateien:**
- `package.json` — `eslint-plugin-react-native-a11y` aus `devDependencies` entfernt
- `eslint.config.mjs` — Import, Plugin-Registrierung und alle `react-native-a11y/*`-Regeln entfernt

---

## 2. Dependency-Cleanup

| Entfernt | Grund |
|---|---|
| `eslint-plugin-react-native-a11y@^3.5.1` | ESLint 10 inkompatibel |
| `react-native-worklets@^0.11.3` | Deprecated; `react-native-worklets-core@^1.6.3` bereits vorhanden |
| `autoprefixer@^10.5.4` | Nicht benötigt in React Native |
| `postcss@^8.5.25` | Nicht benötigt in React Native |

**Datei:** `package.json`

---

## 3. ESLint-Konfiguration bereinigt

**Datei:** `eslint.config.mjs`

- A11y-Plugin-Referenz vollständig entfernt
- Typo gefixt: `'@typescript-eslint/explicit-module-boundary_types'` (Underscore) →
  `'@typescript-eslint/explicit-module-boundary-types'` (Bindestrich)
- Konfiguration vereinfacht auf `@typescript-eslint`-Regeln

---

## 4. TypeScript-Konfiguration verbessert

**`tsconfig.json`**
- Explizite `include`-Pfade: `src`, `modules`, `App.tsx`, `index.ts`, `app.config.ts`,
  `babel.config.js`, `metro.config.js`, `nativewind-env.d.ts`
- `exclude`: `node_modules`, `.expo`, `__tests__`, `e2e`
- `"types": ["jest", "node"]` aus dem globalen Scope entfernt (verhindert Typ-Pollution)

**`tsconfig.test.json`** (neu)
- Erbt von `tsconfig.json`
- Setzt `"types": ["jest", "node"]` nur für Test-Dateien
- Verhindert, dass Node/Jest-Globale in App-Code sichtbar werden

---

## 5. Provider-Typen erweitert

**`src/types/index.ts`**

`Provider`-Union von 6 auf 50+ rclone-Backend-IDs erweitert:
- Consumer Cloud: `drive`, `onedrive`, `dropbox`, `mega`, `box`, `pcloud`, `yandex`,
  `jottacloud`, `koofr`, `mailru`, `zoho`, `hidrive`, `proton`, `filen`, `premiumizeme`,
  `putio`, `opendrive`, `sugarsync`, `linkbox`, `pikpak`, `ulozto`, `seafile`,
  `sharefile`, `quatrix`, `filefabric`, `googlephotos`, `internetarchive`
- Object Storage: `s3`, `b2`, `storj`, `idrive`, `azureblob`, `azurefiles`,
  `googlecloudstorage`, `swift`, `oracleobjectstorage`, `sia`, `hdfs`
- Server-Protokolle: `sftp`, `ftp`, `ftps`, `webdav`, `smb`, `nfs`
- Virtuelle Remotes: `union`, `crypt`, `alias`, `chunker`, `compress`, `cache`,
  `combine`, `hasher`
- Forward-compat escape hatch: `(string & {})`

---

## 6. Provider-Daten: vollständige rclone-Liste

**`src/data/rcloneProviders.ts`** (neu)

60+ Provider mit vollständigen Metadaten:
```typescript
interface RcloneProvider {
  id: string;           // UI-ID (S3-compat: 's3_wasabi', 's3_cloudflare', …)
  rcloneType: Provider; // Echter rclone config type
  name: string;
  category: RcloneCategory;
  description: string;
  requiresOAuth: boolean;
  s3Provider?: string;  // Nur für S3-kompatible Anbieter
}
```

Kategorien: `Google`, `Microsoft`, `Consumer Cloud`, `Object Storage`,
`S3 Compatible`, `Decentralised`, `Server Protocol`, `Virtual Remote`, `Other`

Exportiert: `RCLONE_PROVIDERS`, `PROVIDER_CATEGORIES`, `filterProviders(query)`

---

## 7. AddRemoteScreen — Suchfunktion + alle Provider

**`src/screens/AddRemoteScreen.tsx`** (vollständig neu geschrieben)

- Suchfeld mit Live-Filterung via `filterProviders(search)` + `useMemo`
- Kategorie-Gruppierung in einer `Map<RcloneCategory, RcloneProvider[]>`
- "Selected"-Pill zeigt gewählten Provider
- S3-Provider-Hint im Config-Platzhalter
- Korrekte Trennung: `provider.id` nur für UI-State, `provider.rcloneType` beim Speichern

---

## 8. RcloneService — vollständig implementiert

**`modules/rclone/src/RcloneService.ts`**

Alle 11 Methoden via `rclone rcd` HTTP-API implementiert (statt `throw new Error('NotImplemented')`):

| Methode | rcd-Endpunkt |
|---|---|
| `getConfig()` | `config/dump` |
| `addRemote()` | `config/create` (mit `obscure: true`) |
| `deleteRemote()` | `config/delete` |
| `createUnionRemote()` | `config/create` mit `type: 'union'` |
| `createCryptRemote()` | `config/create` mit `type: 'crypt'` |
| `sync()` | `sync/sync` mit `_async: true` → gibt `jobid` zurück |
| `about()` | `operations/about` → `QuotaInfo` |
| `deleteRemotePath()` | `operations/purge` |
| `startOAuthFlow()` | `nativeModule.startOAuthFlow()` |
| `exchangeOAuthCode()` | `nativeModule.exchangeOAuthCode()` |
| `subscribeToProgress/JobStatus/AuthCallback` | `eventEmitter.addListener()` |

Hilfsfunktion `rpc<T>(method, params)` kapselt HTTP POST + JSON-Parsing.

---

## 9. Android Native Module

**`modules/rclone/android/build.gradle`** (neu)
- Expo-Module Gradle-Config
- `namespace`: `expo.modules.rclone`
- `compileSdk`: 35, `minSdk`: 26
- Java-Kompatibilität: 17
- ABIs: `arm64-v8a`, `x86_64`

**`modules/rclone/android/src/main/java/expo/modules/rclone/RcloneModule.kt`** (neu)
- Kotlin Expo Module
- Extrahiert rclone-Binary aus `assets/rclone/` nach `filesDir` (mit Versions-Check)
- Startet `rclone rcd --rc-no-auth` auf `127.0.0.1:5572` via `ProcessBuilder`
- Exponiert `initialize()`, `rpcCall()`, `startOAuthFlow()`, `exchangeOAuthCode()`
- HTTP-Proxy via `HttpURLConnection` an den rcd-Prozess
- `OnDestroy`: terminiert den rclone-Prozess

---

## 10. iOS Native Module

**`modules/rclone/ios/RcloneModule.swift`** (neu)
- Swift Expo Module
- Extrahiert rclone-Binary aus dem App-Bundle nach `Documents/rclone/` (mit Versions-Check)
- Setzt POSIX-Permissions (`0o755`) auf die extrahierte Binary
- Startet `rclone rcd --rc-no-auth` via Foundation `Process`
- HTTP-Proxy via `URLSession` (synchron per `DispatchSemaphore`)
- Gleiche API wie Android: `initialize()`, `rpcCall()`, `startOAuthFlow()`, `exchangeOAuthCode()`

---

## 11. Binary-Download-Script

**`scripts/download-rclone.sh`** (neu)
- Lädt aktuelle (oder gepinnte) rclone-Version von `downloads.rclone.org`
- Android arm64 → `modules/rclone/android/src/main/assets/rclone/`
- iOS arm64 (macOS-Build) → `modules/rclone/ios/Resources/rclone/`
- Schreibt `version.txt` für den Versions-Check im Native Module
- Konfigurierbar via `RCLONE_VERSION`-Env-Variable

---

## 12. Rename: EchoVault → Fibu

| Datei | Änderung |
|---|---|
| `app.config.ts` | `bundleIdentifier`: `com.echovault.app` → `com.fibu.app`; Android `package` ebenso; alle Permission-Strings |
| `src/db/crypto.ts` | `KEY_ALIAS = 'echovault_db_key'` → `'fibu_db_key'` |
| `src/screens/OnboardingScreen.tsx` | "Welcome to EchoVault" → "Welcome to Fibu" |
| `.agents/AGENTS.md` | Titel "# EchoVault — Projektregeln" → "# Fibu — Projektregeln" |

---

## Was noch manuell erledigt werden muss

1. **`.github/workflows/ci.yml`**: Node 22 + Java 21 (braucht `workflows`-OAuth-Scope)
2. **`scripts/download-rclone.sh`** einmalig ausführen vor dem ersten Build
3. **`RclonePackage.kt`** anlegen (Expo-Module-Registrierung für Android)
4. **iOS**: Xcode-Target um Binary-Resources und Swift-Datei ergänzen nach `expo prebuild`
5. **OAuth-Flow**: `expo-web-browser` + `expo-auth-session` verdrahten
