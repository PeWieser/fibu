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
     re-uploaded, never asked again. Safety brakes: an empty remote listing or
     a >50 % shrink is treated as an outage and deletes nothing.
2. **MirrorSyncEngine** (filesystem mirror, folders/files): classic local
   mirror directory with the same tombstone protocol.

Incremental (one-way) media uploads use `sync/copy` with case-insensitive
include filters (`IMG_0001.HEIC` matches `*.heic`) and transient staging that
is removed after the upload. A missing remote target folder is treated as an
empty cloud side, not an error.

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

`.github/workflows/build-ios.yml`: on every push to `main`, GitHub Actions
builds `Rclone.xcframework` (Go + gomobile) and an unsigned release IPA
(artifact `ios-app-release`). Swift Package Manager is disabled per project
(`pubspec.yaml → flutter.config.enable-swift-package-manager: false`) until
`flutter_web_auth_2`, `open_filex` and `workmanager` adopt SPM.
