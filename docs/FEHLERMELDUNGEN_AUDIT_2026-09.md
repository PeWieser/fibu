# Audit: Fehlermeldungen & Fehlerzustände (2026-09)

Systematische Prüfung aller Szenarien, in denen der App Fehlermeldungen
begegnen können: Welche Meldung erscheint, ist sie adäquat (verständlich,
lokalisiert DE/EN, mit Handlungshinweis), und entspricht sie den
Designrichtlinien?

## 0. Designrichtlinien (Grundlage der Bewertung)

Aus `.agents/AGENTS.md` und den etablierten Mustern im Code:

1. **Error State auf jedem Screen** (AGENTS §4): Fehler müssen sichtbar und
   als Zustand gestaltet sein — kein stilles Weitermachen, kein „toter"
   Knopf.
2. **Keine stillen No-Ops** (AGENTS §5): Ein Fehler, der den Nutzer betrifft,
   darf nicht kommentarlos geschluckt werden. Mindestens ein Eintrag ins
   Diagnose-Protokoll (`fibu.log`), besser eine sichtbare Meldung.
3. **Destruktive Aktionen mit Klartext-Konsequenz** (AGENTS §6).
4. **Lokalisiert**: Jede Meldung existiert DE **und** EN
   (`app_strings.dart`, `isGerman ? … : …`).
5. **Freundlich statt technisch** (etabliertes Muster `_friendlySyncError` /
   `_friendlyConfigError`): Der Nutzer sieht eine verständliche Meldung mit
   Handlungshinweis; der rohe Originalfehler (rclone-Stderr, Pfade,
   Provider-Codes) bleibt im Laufprotokoll bzw. in `fibu.log`.
6. **Ursache benennen, nicht Symptom**: „Keine Alben gefunden" ist falsch,
   wenn die Foto-Berechtigung fehlt.

## 1. Szenario-Katalog (vor der Fix-Runde)

Legende: ✅ adäquat · ⚠️ unzureichend · ❌ Roh-Text/irreführend in der UI

### A. Synchronisierung (Dashboard, manuell)

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| A1 | Offline beim Start | `networkUnavailableError` („Keine aktive Internetverbindung") | ✅ |
| A2 | WLAN-only-Regel, Mobilfunk aktiv | `cellularSyncBlockedNotice` | ✅ |
| A3 | Remote gelöscht/umbenannt | `remoteNotFoundHint` mit Handlungshinweis | ✅ |
| A4 | OAuth-Token abgelaufen / 401/403 | `syncAuthError` („neu verbinden") | ✅ |
| A5 | Cloud-Quota voll | `syncQuotaError` + Vorab-Prüfung `syncRemoteFullWarning` | ✅ |
| A6 | Gerät voll (Download) | `syncLocalFullWarning` | ✅ |
| A7 | Ein Sync läuft bereits (alle Einstiege) | `syncAlreadyRunning` — aber UI zeigte **„Bad state: …"**-Vorspann | ❌ → behoben (E-1) |
| A8 | Quellordner fehlt (Windows-Mirror) | `errSourceFolderMissing(path)` | ✅ |
| A9 | Foto-Berechtigung verweigert (iOS) | `errPhotoPermission` | ✅ |
| A10 | rclone liefert keine Job-ID | Technischer Text „rclone lieferte keine Job-ID zurück" | ❌ → behoben (E-9) |
| A11 | Sonstiger Fehler (rclone-Stderr, Provider, Timeout-Varianten ohne Stichwort) | **Roher, meist englischer Technik-Text** als Fallback | ❌ → behoben (E-1) |
| A12 | Cloud-Sperre durch anderes Gerät | `syncLockedByOtherDevice(device)` | ✅ |
| A13 | Abbruch durch Nutzer | `backupStopped` („Backup gestoppt") | ✅ |

### B. Geplante/Hintergrund-Läufe

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| B1 | Geplanter Lauf schlägt fehl | **Keine UI-Meldung.** Nur `SchedulerRunLog` (JSON), das nirgends angezeigt wird | ⚠️ offen (Empfehlung R-1) |
| B2 | Lauf wird wegen Offline/WLAN übersprungen | Laufprotokoll `skipped`; Nachholen über `runMissedSyncs` — keine Meldung nötig (by design), aber ebenfalls unsichtbar | ⚠️ wie R-1 |
| B3 | Lösch-Anfrage im Hintergrund (iOS kann keinen Dialog zeigen) | `PendingDeletionsStore` → Dashboard-Banner mit Systemdialog | ✅ (gutes Muster) |
| B4 | iOS beendet den Hintergrund-Lauf (2-h-Fenster) | Kein Absturz; Lauf gilt als nicht erfolgreich und wird nachgeholt | ✅ (seit H1-Fix) |

### C. Cloud-Laufwerk verbinden (Wizard)

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| C1 | Pflichtfelder leer | `credentialsRequiredError` | ✅ |
| C2 | Name/Anbieter fehlt | `nameRequiredError` / `providerRequiredError` | ✅ |
| C3 | Verbindungstest: falsche Zugangsdaten | `invalidCredentialsHint` (+ Provider-Code) | ✅ |
| C4 | Verbindungstest: kein Netz/Timeout | `networkUnavailableError` (+ Provider-Code) | ✅ |
| C5 | Verbindungstest: anderer Fehler | **Roher Text** als Fallback | ❌ → behoben (E-2) |
| C6 | OAuth abgebrochen/fehlt beim Anlegen | Wird als leerer Token erkannt → Fehlermeldung des Verbindungstests | ✅ (über C3/C5) |

### D. Cloud-Laufwerke verwalten

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| D1 | Laufwerke aktualisieren schlägt fehl | **`e.toString()` roh** in der Benachrichtigung | ❌ → behoben (E-3) |
| D2 | Laufwerk trennen schlägt fehl | **`e.toString()` roh** | ❌ → behoben (E-4) |
| D3 | Laufwerks-/Quota-Karte lädt nicht | **`„Fehler: <Exception>""` roh** (iOS- und Windows-Dashboard, Storage-Karte) | ❌ → behoben (E-5) |
| D4 | Cloud-Ordner-Liste lädt nicht | `remoteFoldersLoadError` | ✅ |
| D5 | Bestehende Konfiguration in der Cloud erkannt | Erfolgs-/Importdialog mit Konsequenz-Hinweis | ✅ |

### E. Cloud-Inhalte ansehen (Browser, Viewer)

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| E1 | Alben-/Dateiliste lädt nicht (4 Stellen) | **`'$e'` roh** im Fehler-Banner | ❌ → behoben (E-6) |
| E2 | Foto-Original lädt im Viewer nicht | **`'$e'` roh** | ❌ → behoben (E-7) |
| E3 | „In Standard-App öffnen" scheitert | **Keine Rückmeldung** (Knopf wirkt tot) | ❌ → behoben (E-8) |
| E4 | Vorschau/Download im Dateidialog | `fileLoadFailed` lokalisiert | ✅ |

### F. Aufgaben

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| F1 | Sync aus der Aufgaben-Detailansicht schlägt fehl | **`„Fehler: <Exception>"` roh** | ❌ → behoben (E-10) |
| F2 | Cloud-Ordner löschen (Detail) schlägt fehl | `remoteFolderDeleteError` + **roher Suffix** | ⚠️ → behoben (Suffix entfernt) |
| F3 | `tasks.json` nicht lesbar/schreibbar | **Komplett still** (nur Test-Kommentar) | ⚠️ → Log-Eintrag ergänzt; UI-Hinweis bleibt Empfehlung R-2 |
| F4 | `.fibu/config.json` kann nicht in die Cloud geschrieben werden | **Komplett still** — Folge: Task-Import nach Neuinstallation fehlt | ⚠️ → Log-Eintrag ergänzt (Empfehlung R-2 für UI) |
| F5 | Album-Liste leer wegen fehlender Foto-Berechtigung | „Keine Alben gefunden" (**falsche Ursache**) | ❌ → behoben (E-11) |
| F6 | Album-Zähler einzelner Alben fehlerhaft | Zähler ist kosmetisch — still ok | ✅ |
| F7 | Aufgabe ohne Quelle/Ziel | `sourcePathRequiredError` etc. im Wizard | ✅ |

### G. Kopplung (Pairing)

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| G1 | Kein Netz beim Koppeln | `pairingNoNetwork` | ✅ |
| G2 | Zeitüberschreitung beim Warten | `pairingTimeout` | ✅ |
| G3 | Empfang/Übernahme der Konfiguration schlägt fehl | **`'$e'` roh** | ❌ → behoben (E-12) |
| G4 | Senden schlägt fehl | `pairingSendFailed` mit Ursachenfrage | ✅ |
| G5 | Kein anderes Gerät gefunden | `pairingNoneFound` | ✅ |
| G6 | Bestätigung vor Überschreiben | Klartext-Konsequenz (AGENTS §6) | ✅ |

### H. Windows-spezifisch

| # | Szenario | Meldung vor der Runde | Status |
|---|---|---|---|
| H1 | `rclone.exe` fehlt/nicht startbar | Prozess-Fehler fließt als **englischer Roh-Text** (`Failed to list remotes: …`) bis in die UI-Fallbacks | ⚠️ → seit E-1/E-2/E-3/E-4/E-5 greifen die lokalisierten Fallbacks; der Rohtext steht nur noch in `fibu.log` |
| H2 | Quellordner verschwunden | `errSourceFolderMissing` (seit N-F5) | ✅ |
| H3 | Autostart lässt sich nicht setzen | Schalter bleibt aus, kein Fehlerdialog | ⚠️ dokumentiert (niedrig, Funktion ist optional) |

## 2. Fix-Runde (gleicher Tag)

| ID | Änderung | Ort |
|---|---|---|
| E-1 | Sync-Fallback: „Bad state:"-Vorspann wird entfernt (Engine-Meldungen sind lokalisiert); jeder andere Fallback ist jetzt `syncErrorGeneric` (DE/EN), Original geht ins Log | `dashboard_controller.dart` |
| E-2 | Wizard-Fallback: `connectionFailedGeneric` (DE/EN), kurze Provider-Codes dürfen als Hinweiszeile bleiben | `add_remote_wizard.dart` |
| E-3 | Laufwerke-Aktualisieren: `drivesRefreshError` | `cloud_drives_screen.dart` |
| E-4 | Laufwerk trennen: `driveDeleteError` | `cloud_drives_screen.dart` |
| E-5 | Speicher-/Laufwerkskarte (iOS **und** Windows): `drivesLoadError` | `dashboard_screen.dart`, `multi_remote_storage_card.dart` |
| E-6 | Cloud-Browser (4 Fehlerpfade): `cloudBrowseError` | `cloud_photos_screen.dart` |
| E-7 | Viewer-Ladefehler: `fileLoadFailed` | `cloud_photo_viewer.dart` |
| E-8 | „In Standard-App öffnen" zeigt bei Misserfolg eine SnackBar (`fileLoadFailed`) | `cloud_photo_viewer.dart` |
| E-9 | `errNoJobId` von Technik- auf Nutzer-Text umgestellt („Sicherung konnte nicht gestartet werden. Bitte erneut versuchen.") | `app_strings.dart` |
| E-10 | Sync-Start aus Aufgaben-Detail: gleiche Bad-state/Fallback-Logik wie Dashboard | `task_detail_screen.dart` |
| E-11 | Album-Picker (Wizard **und** Aufgaben-Bearbeitung): bei verweigerter Berechtigung `errPhotoPermission` statt „Keine Alben gefunden" | `tasks_screen.dart`, `task_detail_screen.dart` |
| E-12 | Pairing-Empfang: `pairingReceiveFailed` | `device_pairing_screen.dart` |
| E-13 | Stille Catches in `tasks_controller.dart` (`_loadTasks`/`_saveTasks`) und `tasks_screen.dart` (Cloud-Konfig schreiben) protokollieren jetzt laut nach `fibu.log` | `tasks_controller.dart`, `tasks_screen.dart` |

Neue Strings (alle DE/EN): `syncErrorGeneric`, `connectionFailedGeneric`,
`cloudBrowseError`, `drivesRefreshError`, `drivesLoadError`,
`driveDeleteError`, `pairingReceiveFailed`; umformuliert: `errNoJobId`.

## 3. Offene Empfehlungen (nicht in dieser Runde umgesetzt)

| ID | Empfehlung | Begründung |
|---|---|---|
| R-1 | **Fehlgeschlagene geplante Läufe sichtbar machen**: `SchedulerRunLog.get(taskId)` wird von keiner UI gelesen. Vorschlag: Dashboard-Banner nach dem Muster des Pending-Deletions-Banners („Letzter geplanter Lauf fehlgeschlagen — wird automatisch nachgeholt"), angetippt → Detail mit `lastError` | Neues UI-Element, Design-Entscheidung beim Maintainer |
| R-2 | Schreibfehler von `tasks.json`/`.fibu/config.json` zusätzlich als einmaligen, dezenten UI-Hinweis anzeigen (heute nur `fibu.log`) | Sehr seltene Fehler; Log-Eintrag ist die 80%-Lösung |
| R-3 | Autostart-Fehler (Windows) am Schalter kurz begründen | Kosmetisch |
| R-4 | Roh-Texte der Windows-Rclone-Prozesse („Failed to list remotes…") bereits im Service in lokalisierte Kategorien übersetzen, statt erst in den UI-Fallbacks | Optional; die Fallbacks fangen es heute ab |

## 4. Verifikation

Ohne Flutter-SDK in dieser Umgebung verifiziert die CI (`flutter analyze` +
`flutter test` auf iOS- und Windows-Runnern) die Änderungen. Die manuelle
Sichtprüfung der Meldungen (DE/EN je Gerät, Dunkelmodus, iOS-Dialoge) gehört
in die nächste Testmatrix-Runde.
