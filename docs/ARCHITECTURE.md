# Fibu — Architecture

A concise, current map of how Fibu works. For the chronological work log see
[`ARBEITSLOG.md`](ARBEITSLOG.md) (German).

## Layers

```text
UI (platform-adaptive)          lib/features/*  — Cupertino (iOS), Material 3 (Android), Fluent (Windows)
State                           flutter_riverpod providers
Localization                    lib/core/localization/AppStrings — every user-visible string DE/EN;
                                engine layers without a Ref read AppStrings.current
Services                        lib/core/services/* — all business logic
Navigation                      lib/core/navigation/AppNav — one push helper for all three platforms
Shared widgets                  lib/core/widgets/* — Win.* (Fluent settings building blocks), LiquidGlass
Native bridges (iOS)            ios/Runner/AppDelegate.swift — MethodChannels:
                                fibu/rclone (librclone RPC), fibu/widget (App-Group push),
                                fibu/keychain (Security.framework), fibu/system (low-power mode)
Engine                          librclone (gomobile build of rclone) as Rclone.xcframework,
                                built by ios/scripts/build_librclone.sh
```

## Remote identity model

`RemoteRegistryService` (`remotes.json`, Application Support) separates three
things that older builds conflated:

- **id** — stable technical key, also the section name in `rclone.conf`
  (`fibu-<8 hex>`). Never changes; tasks reference remotes by id.
- **name** — user-facing display name, renameable at any time without touching
  rclone or tasks.
- **type** — the real rclone backend (`mega`, `drive`, …), read via
  `config/get` for adopted sections instead of guessing from names.

`.fibu/config.json` written to each remote carries `linkedRemotes` **and**
`linkedProviders` so another device can adopt tasks by resolving
id → display name → **provider type** → the remote the config was found on.
Task import is therefore independent of how remotes are named anywhere.

## Sync engines

Two engines, both driven by `IosRcloneService.startBackupJob`:

1. **VirtualMirrorSyncEngine** (media, echo mode; "manifest-only"):
   no permanent local copies. The photo library is scanned metadata-only
   (`needTitle`), uploads export exactly one asset on demand into a temp dir,
   downloads are imported straight into the photo library **and assigned to
   the album from the cloud path** (`Photos/<Album>/…`, album created if
   needed).
   - State: `Application Support/fibu_state/mirror_state.json` — persists only
     **provably synced** paths (uploaded this run or seen remotely). Failed
     uploads retry next run and can never be mistaken for remote deletions.
   - Deletions, local → cloud: snapshot diff produces tombstones
     (`.fibu/tombstones.json`, local + remote).
   - Deletions, cloud → local: a path that was provably synced and is now
     missing remotely without a tombstone was deleted directly in the cloud.
     It is excluded from re-upload and deleted locally via
     `PhotoManager.editor.deleteWithIds` — iOS shows **one batched system
     confirmation per run** (Apple does not allow silent deletion for
     third-party apps). Declined items are blocked: kept locally, never
     re-uploaded, never asked again.
   - **Safety brakes** (`virtual_mirror_sync.dart`): an empty remote listing is
     treated as an outage and deletes nothing; automatic local deletes stop at
     **20 % of the last known state and at 25 files absolute** — beyond that the
     run reports instead of deleting.
   - **Conflicts are preserved, not overwritten:** local and remote are
     compared three-way against `lastKnown`. If both sides changed the same
     path, the local version is kept under a timestamped name
     (`IMG_0001 (Konflikt 2026-09-04 14-03).HEIC`) and the cloud version stays
     where it is. No content hash — size + mtime decide, which is deliberate
     (see `TESTMATRIX_IOS_WINDOWS.md`, B13).
   - **Renames are detected**, not re-uploaded: same size + mtime under a new
     path becomes a server-side `moveRemoteFile` (rclone `moveto`).
2. **MirrorSyncEngine** (filesystem mirror, folders/files): classic local
   mirror directory with the same tombstone protocol.
3. **Windows** has no photo library, so the filesystem is the source:
   `FilesystemMirrorSource` feeds `VirtualMirrorSyncEngine` and gives Windows a
   real two-way mirror with the same tombstones, conflict preservation and
   brakes (instead of `rclone sync`, which is one-way with delete rights).
   Deletes go to a `.fibu-trash` folder (30 days) rather than being hard
   deleted. `.fibu/` is hidden from the mirror and excluded on the copy path.

**Cross-device coordination.** `SyncLockService` holds one lock per target
folder in the cloud, so two devices cannot mirror into the same folder at the
same time — checked by manual runs *and* by the scheduler.
`ChangeJournalService` publishes per-device journals to
`<target>/.fibu/journal/<deviceId>.jsonl`, so a device can see what the others
did since its own last run.

Incremental (one-way) media uploads use `sync/copy` with case-insensitive
include filters (`IMG_0001.HEIC` matches `*.heic`) and transient staging that
is removed after the upload. A missing remote target folder is treated as an
empty cloud side, not an error.

## Device-to-device configuration transfer

`DevicePairingService` moves `rclone.conf`, `remotes.json` and `tasks.json`
from one device to another. There is exactly **one** path — discover and tap;
a QR code and manual address entry were removed as redundant (`qr_flutter` is
gone from `pubspec.yaml`).

1. **Receiver** starts an HTTP server on an ephemeral port and broadcasts a
   UDP beacon to `255.255.255.255:47831` every 2 s carrying
   `{v: 2, name, host, port, secret}`.
2. **Sender** listens on 47831 (`discover`), shows the found device by name and
   sends with one tap. `targetUrlFor` builds `http://host:port/#secret`; the
   secret travels as a URL **fragment**, so it is never sent on the wire.
3. Bundle is encrypted with **AES-256-GCM** using the 32-byte session key,
   uploaded to `/upload`, decrypted, and the server closes immediately.
4. **The receiver writes nothing until the user confirms** (`_confirmBox`:
   device name, drive count, task count → Apply / Reject). This is the gate
   that replaces the QR scan: the secret is readable by anyone on the LAN, so
   a human on the receiving device decides what lands on disk.

Two traps worth keeping in the tests:

- `_generateSecret` emits base64url **without** padding (32 bytes = 43 chars);
  `base64Url.decode` requires a multiple of four, so `_keyFrom` pads first
  (`_padBase64Url`). Without that, every transfer ever attempted threw
  `FormatException` and the UI only reported "transfer failed".
- Beacons with `v: 1` (no secret) are skipped when discovering — offering a
  target that cannot be authenticated is worse than showing none.

iOS needs `NSLocalNetworkUsageDescription`, otherwise the permission prompt
never appears and broadcast is blocked silently (whether Apple additionally
requires the *Multicast Networking* entitlement is only verifiable on a real
device — `TESTMATRIX_IOS_WINDOWS.md`, D11).

## Appearance

One choice: a Sanzo Wada palette (or the neutral default). Each palette ships
a light **and** a dark set, and `appThemeProvider` picks the set from
`systemBrightnessProvider` — there is no in-app light/dark switch any more.
Contrast for all 8 palettes × 2 modes is pinned by `test/unit/theme_contrast_test.dart`
(WCAG AA ≥ 4.5:1). Old settings files with separate light/dark palettes are
migrated on load (`ThemeNotifier.paletteFromSettings`: the light choice wins).

## Live data & status

- `AutoRefreshService`: refreshes remotes, quota and sync-needed state every
  10 s (20 s in Low Power Mode via `fibu/system`), foreground-only,
  online-only, never during a sync; the expensive fibu-usage tree scan runs
  every 6th cycle. There are no manual refresh buttons.
- The dashboard shows **one** status banner (offline / syncing / failed /
  sync needed / up to date) and hides it entirely while nothing is configured.
- Setup guidance is **staged**: with 0 drives only “Add Cloud Drive” is shown;
  with a drive but 0 tasks only “Add Task”. Never both at once.
- `needsSync` stays true for any task in `pending` / `never` / `error` (not only
  on the `ok → pending` transition), so the yellow “sync needed” banner does not
  flip back to green while local and remote still differ.
- Virtual backends (union, crypt, combine, alias, chunker, compress) pick
  already-connected drives via multiple-choice instead of free-text paths.
- **Liquid Glass (iOS 26+ only):** native `UIGlassEffect` via MethodChannel
  `fibu/liquid_glass` and Platform-View `fibu/liquid_glass_view` (runtime class
  lookup — builds on older Xcode). Tab bar, nav bars, key cards and the home
  screen widget adopt glass when available; iOS 15–25 keep the previous opaque
  Cupertino look. Deployment target stays 15.0.
- Progress messages are simple verbs (Checking, Uploading, Downloading,
  Cleaning up, Deleting); counts arrive separately as `itemsDone/itemsTotal`.

## Widgets (iOS)

`WidgetStatusNotifier` computes per-task state (ok / pending / never / error,
last sync, media-count diff → `needsSync`) and pushes JSON through
`fibu/widget` into `UserDefaults(suiteName: <app group>)`;
`WidgetCenter.reloadAllTimelines()` refreshes the WidgetKit extension
(`ios/FibuWidget`). The App-Group ID is resolved **at runtime from
`embedded.mobileprovision`** in both the app and the extension, because
sideload tools rename app groups during re-signing. If no app group is
provisioned, the channel returns `app_group_unavailable`, visible in
`Documents/fibu.log`. Status is recomputed on app start, on resume, after
every task change, and by the background run.

## Background scheduling

`workmanager` registers a 2-hour BGProcessingTask. The callback runs due
tasks against the real engine and refreshes the widget status. The
AppDelegate registers all custom channels in the Workmanager registrant
callback too — background isolates have full engine access.

## CI

Two workflows, both on every push to `main` **and** to `arena/**` (the working
branches of agent sessions — they cannot dispatch workflows, so the push is the
only trigger):

- `.github/workflows/build-ios.yml` (macOS): `flutter pub get` → `flutter
  analyze` → build `Rclone.xcframework` (Go + gomobile) → unsigned release IPA
  → **verify `PrivacyInfo.xcprivacy` is in the bundle** → package → artifact
  `ios-app-release` → `flutter test`.
- `.github/workflows/build-windows.yml` (Windows): analyze → release build →
  bundle `rclone.exe` next to the app → verify the bundle → artifact →
  `flutter test`.

`flutter analyze` must stay at 0 errors **and** 0 warnings (info-level lints
fail the run too). Swift Package Manager is disabled per project
(`pubspec.yaml → flutter.config.enable-swift-package-manager: false`) until
`flutter_web_auth_2`, `open_filex` and `workmanager` adopt SPM.

**Reading a red run:** step logs live on `results-receiver.actions.githubusercontent.com`,
which is unreachable from the agent sandbox (TLS blocked) — and so are artifact
downloads. Every workflow therefore ends with a step that posts the tail of each
log file as a **commit comment** on failure:

```bash
gh api repos/PeWieser/fibu/commits/<sha>/comments --jq '.[].body'
```
