# Umbau: eine Cloud, eine Sicherung — Windows zuerst

Stand der Planung: `main` @ `4ed2d20`. **Noch nichts umgesetzt.**

## 0. Entscheidungen aus der Rücksprache

1. **Genau eine Cloud** insgesamt. Mehrere Anbieter nur, indem sie im Setup zu
   einer virtuellen Cloud gebündelt werden (Union, Combine, Crypt, Chunker).
2. Alles, was im Aufgaben-Tab war, wandert in die **Einstellungen** — eigener
   Punkt, so wenig Einträge wie möglich, klar strukturiert.
3. **Globales Modell:** überall genau eine Cloud und eine Sicherung, auch
   iOS/Android. Deren Oberfläche folgt in einer späteren Phase.
4. Eine Sicherung darf **mehrere Quellordner** haben.
5. **Kein Archiv.** Die App ist in der Beta — überzählige Sicherungen werden
   beim Einrichten übernommen oder verworfen, nicht gesammelt. Es geht dabei
   nur um Konfiguration; Dateien in der Cloud bleiben unberührt.
6. Autostart der Windows-App gehört in den Abschnitt **„System"** — das ist
   die Windows-eigene Wortwahl (Systemeinstellungen → Apps → Autostart).
7. Ein Pool zeigt **immer** eine Größenangabe: liefert rclone für das
   virtuelle Laufwerk nichts Brauchbares, wird die Summe der Bestandteile
   gebildet.
8. Die Fenstergröße richtet sich nach dem Inhalt: Der Inhalt muss vollständig
   passen, ringsum ein gleichmäßiges, ruhiges Padding.

## 1. Zielbild

```
HEUTE                              NACHHER (Windows)
3 Tabs: Dashboard, Aufgaben,       2 Tabs: Dashboard, Einstellungen
        Einstellungen
N Clouds                           1 Cloud (evtl. ein Pool aus mehreren
M Aufgaben                             Laufwerken)
jede Aufgabe 1..N Ziele            1 Sicherung, 1..N Quellordner, 1 Ziel
Fenster 1280×720                   Fenster 900×620 (Minimum 760×540)
```

---

## 2. Datenmodell

### 2.1 `remotes.json` — mehrere Einträge bleiben, einer ist „die Cloud"

Ein Pool braucht seine Mitglieder als echte Abschnitte in `rclone.conf`,
deshalb bleibt die Liste. Neu kommen zwei Felder auf der obersten Ebene:

```json
{
  "remotes": [
    { "id": "fibu-a1b2c3d4", "name": "MEGA",     "type": "mega"  },
    { "id": "fibu-9a8b7c6d", "name": "Backblaze","type": "b2"    },
    { "id": "fibu-e5f6a7b8", "name": "Tresor",   "type": "crypt" }
  ],
  "activeRemoteId": "fibu-e5f6a7b8",
  "poolMembers": { "fibu-e5f6a7b8": ["fibu-a1b2c3d4", "fibu-9a8b7c6d"] }
}
```

* `RemoteEntry` (`id`, `name`, `type`) bleibt unverändert.
* **`activeRemoteId`** — genau ein Eintrag ist das Sicherungsziel. Die UI zeigt
  nur diesen.
* **`poolMembers`** — welche Laufwerke zu einem virtuellen gehören. Mitglieder
  können nur im Pool-Editor getrennt werden, nicht einzeln in der Übersicht.
* Laufwerke, die weder aktiv noch Mitglied sind, heißen **Waisen** (entstehen
  nur durch Migration, s. 2.4) und werden in einer eigenen Zeile angeboten.
* Neue Provider: `activeRemoteProvider` → `RemoteEntry?`,
  `poolMembersProvider(id)`. `remotesProvider` bleibt für interne Zwecke
  (Sync, Quota, Explorer).

### 2.2 `tasks.json` — genau eine Sicherung

* `tasks` bleibt ein **Array** (Kompatibilität mit `.fibu/config.json` und der
  Konfig-Übertragung), hat aber höchstens **ein** Element.
* Guard im `TasksListNotifier`: `addTask` hängt nicht mehr an, sondern ersetzt
  — mit Bestätigung, wenn schon eine Sicherung existiert. Damit kann keine
  Oberfläche (auch keine alte iOS-Ansicht) einen zweiten Eintrag erzeugen.
* **Felder, die wegfallen:**
  * `distributionStrategy` (`mirrorAll`/`balance`) — Verteilen auf mehrere
    Ziele gibt es nicht mehr.
  * `targetRemotes` (Liste) → nur noch `targetRemote` (existiert bereits).
* **`name`** wird automatisch gebildet („Sicherung auf MEGA") und ist nicht
  mehr frei editierbar — eine Eingabe weniger.

### 2.3 Was ausdrücklich unverändert bleibt

`mirror_state.json`, Tombstones, `ChangeJournalService`, `SyncLock`,
Manifest, Papierkorb, Anomalie-Bremse (20 % / 25), Konflikt-Erkennung. Alle
hängen am **Zielordner**, nicht an der Zahl der Aufgaben.

### 2.4 Migration — einmalig, beim ersten Start nach dem Update

Reihenfolge, alles in einem neuen `SingleBackupMigrationService`:

1. **Aktives Laufwerk bestimmen**, wenn `activeRemoteId` fehlt:
   a. Ziel der ersten aktiven Aufgabe, wenn es in `remotes.json` existiert.
   b. Sonst das erste Laufwerk in `remotes.json`.
   c. Sonst leer (Neuinstallation).
2. **Aufgaben auf eine reduzieren** (`TasksListNotifier.reduceToSingle`):
   die erste aktive gewinnt, ist keine aktiv die erste überhaupt. Der Rest
   wird **verworfen** — kein Archiv, die App ist in der Beta. Verworfen wird
   nur Konfiguration; Dateien in der Cloud bleiben, und die Sicherung lässt
   sich neu einrichten. Jeder Wurf steht im Diagnoseprotokoll.
3. **Nie** wird in `rclone.conf` geschrieben. Kein Laufwerk verschwindet.
4. **Konfig-Übertragung:** `_importBundle` läuft über dieselbe Reduktion,
   bevor geschrieben wird — ein altes Gerät schleust sonst sein
   Mehrfach-Modell ein.

### 2.5 Rückwärtskompatibilität

* Eine ältere App-Version liest die neue Datei weiter: `tasks[0]` funktioniert,
  `activeRemoteId`/`archivedTasks` ignoriert sie. Kein Absturz.
* `.fibu/config.json` auf der Cloud bleibt im alten Format **lesbar**; beim
  Import gilt 2.4.

---

## 3. Windows-Oberfläche

### 3.1 Shell — zwei Einträge

* `fluent.PaneItem` „Aufgaben" entfällt. Neu: Index 0 Dashboard, 1 Einstellungen.
* Betroffene Stellen: `shell_screen.dart` (Windows-Zweig, ~Zeile 100–120),
  `dashboard_screen.dart:147` und `:154` (Sprünge auf `state = 1`/`2` → beide
  auf `1`), `navigation_shell_test.dart`.
* iOS/Android behalten vorerst drei Tabs (Phase 6).

### 3.2 Fenster

* Grundsatz: **Der Inhalt bestimmt die Größe.** Inhaltsspalt 620 px,
  ringsum 32 px Padding, dazu die Navigationsleiste — daraus ergibt sich die
  Fenstergröße, nicht umgekehrt.
* `windows/runner/main.cpp:29` — `Size(1280, 720)` → `Size(860, 620)`.
* Mindestgröße in `windows/runner/win32_window.cpp` über `WM_GETMINMAXINFO`
  (`ptMinTrackSize`) — heute nicht gesetzt; Minimum = Inhalt + Padding.
* Inhalt zentriert auf `maxWidth: 620`, damit bei breitem Fenster nichts
  auseinanderläuft.
* Belegt wird das mit einem Widget-Test, der das Dashboard bei genau dieser
  Größe pumpt: Ein `RenderFlex`-Überlauf lässt den Test fehlschlagen.
* Navigationsleiste bleibt sichtbar (`PaneDisplayMode.auto` kollabiert bei
  900 px nicht automatisch — `displayMode` auf `compact` prüfen).

### 3.3 Dashboard — genau drei Objekte

```
┌──────────────────────────────────────────────┐
│ ●  Änderungen warten — 12 Dateien            │   Statuskarte
│    (während des Syncs: dieselbe Karte)       │   (abgehoben)
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└──────────────────────────────────────────────┘
   4,2 GB von 50 GB belegt · 45,8 GB frei       Speicher
   ▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

   ┌────────────────────────────────────────┐
   │            Jetzt sichern               │   Sync-Button
   └────────────────────────────────────────┘
   Zuletzt: 04.09.2026 14:03
```

**1. Statuskarte** — das vom Rest abgehobene Objekt: eigene Fläche
(`theme.surface`, `radiusLg`, 1,5 px Kontur in `accent` mit 25 % Alpha, wenn
etwas zu tun ist), ~96 px hoch, Icon links, Text rechts.
**Ruhe und Sync teilen sich dieses eine Feld** — der Sync-Zustand ersetzt die
Ruhe-Zeile, er hängt nichts an.

| Zustand | Icon | Text |
|---|---|---|
| keine Cloud | Cloud + | „Cloud verbinden" — die ganze Karte ist dann eine Schaltfläche |
| offline | Cloud durchgestrichen | „Offline — Sicherung pausiert" |
| Sync nötig | Pfeil hoch | „Änderungen warten — 12 Dateien" |
| aktuell | Haken | „Alles gesichert · zuletzt 14:03" |
| läuft | Ring (unbestimmt) | „Übertrage auf „MEGA" · 12 von 80 Dateien · noch 3 min" |
| fehlgeschlagen | Ausrufezeichen | „Fehlgeschlagen" + Grund in der zweiten Zeile |
| abgebrochen | Stopp | „Abgebrochen" |

* Alle **Texte bleiben**, wie sie sind (`app_strings.dart`) — nur ihre
  Anordnung ändert sich.
* Kein Prozentwert, kein Balken im Ruhe-Zustand. Während des Syncs ein
  schlanker Fortschrittsbalken (3 px) am unteren Kartenrand.
* Kein „Vorbereiten …"-Zwischenzustand ohne Inhalt: `pending` zeigt den
  laufenden Zustand mit „Übertragung wird vorbereitet".

**2. Speicher** — eine Zeile, ein Balken: „4,2 GB von 50 GB belegt ·
45,8 GB frei". Quota des **aktiven** Laufwerks (`about`). Ohne
`about`-Unterstützung: „Keine Größenangabe verfügbar" (bestehender String
`quotaSummaryUnavailable`).

**3. Sync-Button** — Verhalten und Meldungen **unverändert**
(`triggerSyncQueue` → Queue → `SyncLock` → `startBackupJob`). Volle Breite,
44 px, Akzentfläche. Während eines Laufs „Abbrechen" mit bestehender Logik.
Darunter in `textSecondary` (12 px): „Zuletzt: …" — nur, wenn es einen letzten
Lauf gibt.

**Vom Windows-Dashboard entfernt:** Statusbanner oben, Setup-Hint-Karte (ihre
Funktion übernimmt die Statuskarte), `MultiRemoteStorageCard` (eine Summe über
mehrere Laufwerke gibt es nicht mehr), das separate Active-Job-Panel, die
doppelten `SizedBox(theme.xl)`.
`_buildStatusBanner`, `_buildActiveJobPanelWindows` und
`_buildSyncActionsWindows` werden zu einem `_statusCard` zusammengefasst;
`_lastSyncInfo` bleibt als Textzeile.

### 3.4 Einstellungen — sechs Punkte

```
Cloud             eine Cloud: verbinden / ersetzen / trennen, Bestandteile,
                  belegter Platz, Inhalt anzeigen
Sicherung         Ordner, Modus, Zielordner, Zeitplan, nur WLAN, aktiv,
                  archivierte Sicherungen
System            Konfiguration übertragen, Diagnose-Protokoll,
                  mit Windows starten
Erscheinungsbild  Farbschema, Sprache
Über              Version, Entwickler, Engine, Lizenzen
Rechtliches       Datenschutz, Impressum
```

**„Sicherung"** (Inhalt aus dem Aufgaben-Editor, reduziert):

| Zeile | Steuerelement | Herkunft |
|---|---|---|
| Quellordner | Liste + „Ordner hinzufügen" / entfernen | `FilePicker.getDirectoryPath`, Mehrfachauswahl-Logik aus `tasks_screen.dart:2482-2540` → eigener Baustein `FolderPickerTile` |
| Modus | zwei Kacheln: Spiegelung / Inkrementell | bestehende Erklärtexte |
| Ordner in der Cloud | ein Textfeld, Vorgabe `fibu-backup` | ersetzt die drei `TargetFolderMode`-Varianten |
| Zeitplan | täglich / wöchentlich + Uhrzeit | bestehende Steuerelemente |
| Nur bei WLAN | Schalter | aus „Netzwerk" |
| Aktiv | Schalter | aus dem Aufgaben-Editor |


**Entfernt:** Aufgabenname, Ziellaufwerk-Auswahl, Verteilungsstrategie,
Aufgaben-Import mit Mehrfachauswahl, „Mediathek"-Reiter (hatte Windows nie).

### 3.5 „Cloud" statt „Cloud-Laufwerke"

Keine Liste, sondern eine Karte:

* Name, Anbieter, belegter Platz, Zustand der Anmeldung.
* **Ersetzen** — startet den Assistenten; die alte Cloud bleibt verbunden, bis
  die neue den Anmeldetest bestanden hat.
* **Trennen** — bestehender Bestätigungsdialog mit Klartext-Folge
  (AGENTS.md Regel 6).
* **Inhalt anzeigen** — Cloud-Explorer bleibt erreichbar.
* Bei Pools: **Bestandteile** — Liste der Mitglieder, hinzufügen/entfernen.
* Waisen aus der Migration: eine Zeile „N weitere Laufwerke verbunden —
  verwalten".

### 3.6 Assistent — ein Flow für Einzel-Cloud und Pool

```
Schritt 1  Was möchtest du sichern?
             ( ) Eine Cloud verbinden
             ( ) Mehrere Clouds zu einer bündeln
                   → Pool (Union) / Geteilter Speicher (Combine)
                     / Verschlüsselter Tresor (Crypt) / Dateien teilen (Chunker)

Schritt 2  Zugangsdaten — unverändert, inklusive echtem Anmeldetest.
           „Hinzufügen" bleibt gesperrt, bis der Test erfolgreich war.

Schritt 3  (nur beim Bündeln) Bestandteile
           Liste der schon verbundenen Laufwerke + „Weitere Cloud hinzufügen"
           (springt in Schritt 2 und zurück). Union: Politik.
           Crypt: Master-Passwort + Dateinamen-Verschlüsselung.

Schritt 4  (nur wenn es noch keine Sicherung gibt) Sicherung einrichten
           Ordner wählen, Modus, Zeitplan → fertig → Dashboard.
```

Technisch: `AddRemoteWizard` bekommt `_members` und `_poolKind`; die
`remotePicker`-Felder der virtuellen Backends
(`rclone_provider_registry.dart:1314` Crypt/Chunker `single`, `:1384` Union,
`:1413` Combine `multi`) werden aus `_members` gefüllt statt aus der globalen
Laufwerksliste.

### 3.7 Was auf Windows wegfällt

* Windows-Zweig von `TasksScreen`, `TaskDetailScreen`,
  `RemoteTaskImportScreen` (Dateien bleiben für iOS/Android bis Phase 6).
* Aufgaben-Presets für Windows.
* `DistributionStrategy.balance`.

---

## 4. Folgen für iOS und Android

Das globale Modell erzwingt **eine** kleine Änderung auch dort, sonst könnte
die alte Oberfläche einen zweiten Eintrag anlegen:

* „Aufgabe erstellen" entfällt, sobald eine Sicherung existiert.
* Die Laufwerksliste zeigt das aktive Laufwerk zuerst und markiert es;
  Mitglieder eines Pools sind gruppiert.

Der vollständige Umbau der iOS/Android-Oberfläche auf dasselbe Zweiteilung
(Dashboard + Einstellungen) ist **Phase 6** und nicht Teil dieses Plans.

---

## 5. Sync, Planer, Autostart, Kopplung

* Die Queue (`dashboard_controller.dart:580-620`) bleibt — sie läuft über eine
  Liste mit einem Element. Meldungen unverändert.
* `triggerSyncTask(taskId)` → `triggerSync()`; die alte Signatur bleibt als
  dünne Hülle, solange iOS sie nutzt.
* Planer (`scheduler_service.dart:142,221`) unverändert.
* Kopplung: `_importBundle` ruft die Migration (2.4) auf.
* Autostart: unverändert, wandert nur in der Oberfläche unter „Gerät".

## 6. Texte (`app_strings.dart`)

**Neu:** `cloudSection`, `backupSection`, `activeCloudHint`, `poolMembers`,
`addMemberCloud`, `poolKindUnion/Combine/Crypt/Chunker`, `archivedBackups`,
`restoreBackup`, `removeBackupForGood`, `statusNoCloud`, `statusSyncNeeded(n)`,
`statusPreparing`, `wizardStepPoolTitle`, `replaceCloud`.

**Weg (nach Phase 5):** `navTasks`, `addTask`, `taskWizard*`,
`distribution*`, `targetFolderMode*`, `manageCloudDrives*`.

## 7. Tests

| Datei | Änderung |
|---|---|
| `navigation_shell_test.dart` | Windows: zwei Einträge, Index 1 = Einstellungen |
| `dashboard_screen_test.dart` | Windows-Layout neu: Statuskarte in allen 7 Zuständen, Speicherzeile, Button |
| `tasks_screen_test.dart` | Windows-Fälle entfallen, iOS/Android bleiben |
| **neu** `test/unit/single_backup_migration_test.dart` | 2.4: eine Aufgabe, mehrere mit gleichem Ziel, mehrere mit verschiedenen Zielen, leere Liste, kaputte Datei, Import-Bundle |
| **neu** `test/unit/active_remote_test.dart` | `activeRemoteId` setzen/ersetzen/trennen, Pool-Mitglieder, Waisen |

Nach jeder Phase: `flutter analyze` 0 Fehler / 0 Warnungen und `flutter test`
grün in beiden Workflows.

## 8. Phasen

| # | Inhalt | Risiko |
|---|---|---|
| 1 | Modell, Migration, Provider, Unit-Tests — **ohne** Oberflächenänderung | niedrig, App verhält sich unverändert |
| 2 | Windows-Shell (2 Tabs) + neues Dashboard + Fenstergröße | mittel |
| 3 | Einstellungen neu (Cloud + Sicherung), Aufgaben-Tab auf Windows raus | mittel |
| 4 | Assistent mit Pool-Flow | mittel |
| 5 | Aufräumen: tote Zweige, Strings, Doku | niedrig |
| 6 | iOS/Android auf dasselbe Modell | hoch, eigene Planung |

Jede Phase ist ein eigener Commit mit grünem CI-Lauf dazwischen.

## 9. Risiken und zu prüfen

* **Kein Datenverlust** durch die Migration: Aufgaben werden archiviert statt
  gelöscht, `rclone.conf` wird nicht angefasst.
* **Quota eines Pools:** liefert rclone `about` für Union/Combine die Summe der
  Mitglieder? Zu prüfen, sonst zeigt die Speicherzeile „keine Angabe".
* **Fluent bei 900 px:** Navigationsleiste und Karten müssen bei der neuen
  Fenstergröße passen — in Phase 2 am Build prüfen.
* **iOS-Übergangszustand:** eine Sicherung, aber alte Oberfläche. Sichtbar,
  aber funktional.
* **Konfig-Übertragung von einem alten Gerät** bringt mehrere Aufgaben — die
  Migration greift, der Rest landet in „Archivierte Sicherungen".

## 10. Geklärte Punkte

1. **Autostart** → Abschnitt „System".
2. **Fenstergröße** → inhaltbestimmt (s. 3.2), nicht als fester Wert verhandelt.
3. **„Inhalt anzeigen"** bleibt. Der Cloud-Explorer zeigt weiterhin keine
   Vorschaubilder — siehe „Bekannte Grenze" unten.
4. **Archiv** → entfällt. Übernehmen oder verwerfen, mit Protokollzeile.

## 11. Bekannte Grenze: Cloud-Explorer ≠ Fotos-App

`cloud_photos_screen.dart` zeigt Alben und nach Datum sortierte Aufnahmen,
aber **keine Vorschaubilder** — die Kachel zeigt Name und Größe. Das ist eine
bewusste Grenze (ein Miniaturbild pro Datei aus der Cloud laden wäre ein
Datenvolumen, das niemand erwartet; WebDAV/S3/SFTP liefern keine
serverseitigen Thumbnails). Zur Fotos-App von iOS/macOS fehlt damit genau das
Merkmal, das sie ausmacht. Eine Annäherung wäre ein Thumbnail-Cache mit
Vorschau-Anforderung (z. B. erste N Aufnahmen pro Album + Cache im
App-Support) — eigener Punkt, nicht Teil dieses Umbaus.
