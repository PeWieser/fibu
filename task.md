# Task Tracking — EchoVault

## Phase 0: Foundation (🟢 Gemini Flash 3.6) — ABGESCHLOSSEN
- [x] Task-Tracking initialisiert (`task.md`)
- [x] Expo-Projekt initialisieren in `d:\code gemini\fibu\`
- [x] TypeScript strict in `tsconfig.json` konfigurieren und Path Aliases (`@/*`) einrichten
- [x] NativeWind v4 und Tailwind CSS installieren & konfigurieren
- [x] ESLint v10, Prettier & Tooling aufsetzen
- [x] `.env.example` & `.gitignore` anlegen
- [x] `app.config.ts` mit iOS/Android Permissions und Background Modes konfigurieren
- [x] GitHub Actions CI Workflow (`.github/workflows/ci.yml`) anlegen
- [x] Ordnerstruktur (`src/`, `modules/`, `__tests__/`) mit Platzhaltern erstellen
- [x] Validierung: `npx tsc --noEmit` & `npx eslint . --max-warnings 0`
- [x] Phase 0 Walkthrough erstellen & abschließen

---

## Phase 1: Design System (🔵 Gemini Pro 3.1) — ABGESCHLOSSEN
- [x] `src/theme/theme.ts` mit semantischen Tokens (Light + Dark), 4pt Spacing-Grid, Type Scale (5 Stufen), BorderRadius (sm:6, lg:12)
- [x] `ThemeProvider` + `useTheme()` Hook implementiert
- [x] Komponente `Text` — Varianten, Farben, Weights, a11y
- [x] Komponente `Surface` — Elevation-Stufen, Border, Radius via Token
- [x] Komponente `Button` — 5 Varianten, Loading-State, Icons, ≥44pt Touch-Target, Reanimated Press-Feedback
- [x] Komponente `IconButton` — Touch-Target, a11y Label
- [x] Komponente `ListRow` — Title/Subtitle, Icons, Press-Feedback, ≥56pt minHeight
- [x] Komponente `ProgressRing` — Reanimated Half-Circle Trick, `accessibilityValue`
- [x] Komponente `ProgressBar` — Animiert, Track + Fill
- [x] Komponente `Sheet` — Bottom Sheet mit Backdrop, Reanimated Slide-In/Out, `runOnJS`
- [x] Komponente `Toggle` — Reanimated `interpolateColor`, `accessibilityRole="switch"`
- [x] Komponente `EmptyState` — Icon, Titel, Beschreibung, CTA
- [x] Komponente `Badge` — Status-Farben via Token
- [x] `src/components/index.ts` — alle 11 Komponenten exportiert
- [x] `src/components/Preview.tsx` — Design-System-Vorschau-Screen
- [x] Validierung: TypeCheck ✅, Lint ✅

---

## Review Checkpoint 1 (🔴 Claude Opus 4.6) — ABGESCHLOSSEN
- [x] Theme-Architektur geprüft — sauber, erweiterbar
- [x] DB-Schema geprüft — Normalisierung, Indices, FK-Design korrekt
- [x] TypeScript Interfaces geprüft — zukunftssicher
- [x] 5 Findings identifiziert (F1–F5)
- [x] F1: `crypto.ts` XOR-Cipher → Base64-Stub mit TODO Phase 6, Buffer-Fix
- [x] F2: `Toggle.tsx` `borderRadius: 14` → `borderRadius.lg` aus Theme
- [x] F3: `App.tsx` ohne `ThemeProvider` → `<ThemeProvider>` gewrapped
- [x] F4: `updateFileStatus()` inkrementiert immer `attempts` → `incrementAttempts`-Parameter
- [x] F5: `ProgressRing` ohne `segments[]` → Phase 5 (kein sofortiger Fix nötig)
- [x] Nachvalidierung: TypeCheck ✅, Lint ✅, 8/8 Tests ✅

---

## Phase 2: Data Layer (🟢 Gemini Flash 3.6) — ABGESCHLOSSEN
- [x] `expo-sqlite` & `expo-secure-store` installiert
- [x] Migration Runner `src/db/migrations/index.ts` — `PRAGMA user_version`, idempotent, transaktional
- [x] Migration `src/db/migrations/v001.ts` — `CloudRemotes`, `SyncRules`, `FileState` Tabellen + Indices
- [x] Repository `src/db/repositories/CloudRemoteRepo.ts` — CRUD + Encryption/Decryption, `updateSpaceUsage`
- [x] Repository `src/db/repositories/SyncRuleRepo.ts` — CRUD + `toggleSyncRuleEnabled`, `getSyncRulesByRemoteId`
- [x] Repository `src/db/repositories/FileStateRepo.ts` — CRUD + `upsertFileState`, `updateFileStatus(incrementAttempts)`, `getFileStatesByStatus`
- [x] `src/db/repositories/index.ts` — alle Repos exportiert
- [x] `src/db/crypto.ts` — Base64-Stub mit SecureStore-Key (AES-256 TODO Phase 6)
- [x] `src/db/types.ts` — `DBConnection`, `DatabaseLike`, `Migration` Interfaces
- [x] `src/db/seed.ts` — 3 Remotes, 4 Rules, 100 FileStates
- [x] `__tests__/helpers/testDb.ts` — in-memory SQLite via `better-sqlite3`
- [x] `__tests__/unit/db/migration.test.ts` — 3 Tests (Fresh, Idempotent, Indices)
- [x] `__tests__/unit/db/repositories.test.ts` — 5 Tests (CloudRemote, SyncRule, FileState, Seed)
- [x] Validierung: TypeCheck ✅, Lint ✅, 8/8 Tests ✅

---

## Phase 3: Native Bridge (🟡 Claude Sonnet 4.6) — ABGESCHLOSSEN
- [x] `modules/rclone/src/RcloneTypes.ts` — alle RPC-Typen: `RemoteSpec`, `SyncOptions`, `QuotaInfo`, `RcloneConfig`, `AuthorizeResult`, `RcloneProgressEvent`, `RcloneJobEvent`, `ProviderType`
- [x] `modules/rclone/src/RcloneNativeModule.ts` — `requireNativeModule<NativeRcloneModule>('Rclone')`, `EventEmitter<RcloneEventMap>`, `NativeRcloneModule`-Interface
- [x] `modules/rclone/src/RcloneService.ts` — 11 Methoden als `NotImplemented`-Stubs, `subscribeToProgress/JobStatus/AuthCallback` Event-Helpers
- [x] `modules/rclone/src/index.ts` — Re-Exports aller Typen und Services
- [x] `src/native/RcloneModule.ts` — Facade-Singleton über `RcloneService`, stabiles Public API für Phase 4
- [x] `__tests__/unit/native/rcloneService.test.ts` — 20 Tests (NotImplemented, Error-Shape, Subscriptions)
- [x] Nebenfix: `optionator@0.9.3` explizit als devDependency (Node.js 24 + ESLint 10 Kompatibilität)
- [x] Validierung: TypeCheck ✅, Lint ✅, 28/28 Tests ✅

---

## Ausstehend

- [/] Phase 4: Sync Engine (🔵 Gemini Pro 3.1)
  - `src/services/RcloneService.ts` — `JobController` + Preflight Gates (WiFi, Battery)
  - Retry mit Backoff, Cancellation, Crash-Resume
  - Echo Reconciliation + Archive-Logik
  - Unit Tests: WiFi-Gate, Battery-Gate, Retry, Idempotenz, Cancel, Progress Events
- [ ] Phase 5: Screens (🔵 Gemini Pro 3.1)
  - 7 Screens: Dashboard, Cloud Drives, Sync Rules, Settings, Remote Detail, Job History, Onboarding
  - Alle Screens: Empty / Loading / Error / Offline States
  - Destructive Actions confirm-gated (Echo Deletion, Remote Disconnect, Reset)
- [ ] Phase 6: Hardening (🟡 Claude Sonnet 4.6)
  - AES-256-GCM Encryption at Rest (ersetzt Base64-Stub)
  - Crypt Remote Passphrase UX
  - Log-Redaktion (keine Secrets in Logs)
  - Battery/Thermal Throttling, 20k+ Asset Performance
- [ ] Review Checkpoint 2 (🔴 Claude Opus 4.6) — Security-Audit
- [ ] Phase 7: Quality Gates (🔵 Gemini Pro 3.1) — Test-Pyramide, E2E, Accessibility
- [ ] Phase 8: Release (🟢 Gemini Flash 3.6) — EAS Build, Store Listings, Sentry
