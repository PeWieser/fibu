# Phase 5 — Cloud-Explorer auf Fotos-Niveau

Stand der Planung: `main` @ `d0862c4`. **Noch nichts umgesetzt.**

## 0. Entscheidungen aus der Rücksprache

1. Vorschaubilder liegen **in der Cloud** unter `.fibu/thumbs/`.
2. Bestände nachziehen: **Hinweis beim ersten Öffnen** des Explorers mit
   Knopf, danach läuft es automatisch mit.
3. Umfang: **Raster mit Vorschaubildern** und **Vollbild-Ansicht** (Wischen,
   auf Windows Pfeiltasten).

## 1. Ziel und Nicht-Ziel

**Ziel.** Der Explorer zeigt die gesicherte Mediathek so, wie man sie von der
Fotos-App kennt: Vorschaubilder im Raster, nach Monat und Tag gegliedert, und
beim Antippen eine Vollbild-Ansicht, in der man blättern und zoomen kann.

**Nicht-Ziel.** Bearbeitung, Personen, Orte, Erinnerungen, geteilte Alben,
Volltextsuche. Fibu ist eine Sicherung, keine Fotoverwaltung.

## 2. Verifizierte Grundlagen

Alles Folgende ist am Code geprüft, nicht angenommen:

| Tatsache | Beleg |
|---|---|
| `.fibu/` wird von keinem Spiegel zurückgespielt | `virtual_mirror_sync.dart:769` (Remote-Liste), `:1043` (Ordnerlauf), `filesystem_mirror_source.dart:54-55` (lokal), `rclone_service_impl.dart:231` (Windows `--exclude .fibu/**`) |
| Beim Upload liegt die Datei bereits lokal | `virtual_mirror_sync.dart:571` — `copyFileToRemoteWithProgress(tmp.path, …)` |
| Die Asset-ID ist an der Stelle bekannt | `VirtualMediaItem.assetId` (`virtual_mirror_sync.dart:21`) |
| Herunterladen einzelner Dateien geht | `RcloneService.downloadFile(remote, remotePath, localPath)` (`rclone_service.dart:276`) |
| Hochladen einzelner Dateien geht | `RcloneService.copyFileToRemote(localFilePath, remote, remotePath)` (`:249`) |
| Der Explorer gruppiert schon nach Tag | `cloud_photos_screen.dart` `_groupedByDay`, 3 Spalten, Kachel = Name + Größe |
| Vollbild hat heute nur „in Standard-App öffnen" | `FileViewerService.openInDefaultApp` / `getLocalFile` |
| `photo_manager` ist bereits Abhängigkeit | `pubspec.yaml:26` (`^3.12.0`) |

**Wichtigste Konsequenz:** `.fibu/thumbs/` ist sicher. Kein Spiegel lädt die
Vorschaubilder als „neue Aufnahme" herunter, kein Papierkorb fasst sie an, und
die Windows-Synchronisierung schließt sie aus.

## 3. Datenlayout

```
<ziel>/
├── Photos/<Album>/IMG_0001.HEIC        ← die Sicherung (unverändert)
└── .fibu/
    ├── manifest.json
    ├── tombstones.json
    └── thumbs/
        ├── 3f9a1c…b7.jpg               ← 256 px, JPEG q70
        └── 81de04…a2.jpg
```

**Name** = erste 32 Hex-Zeichen von `SHA-256(relativer Spiegel-Pfad)`.

* Deterministisch: zwei Geräte, dieselbe Aufnahme → derselbe Name → kein
  Duplikat, und ein zweiter Lauf lädt nicht neu hoch.
* Pfadsicher: keine Albumnamen, keine Sonderzeichen, keine Längenprobleme.
* Umkehrbar ist er nicht — aber das muss er auch nicht sein: Der Explorer
  kennt den Pfad und bildet ihn selbst ab.

**Format und Größe.** 256 px lange Kante, JPEG Qualität 70 → 15–30 KB pro
Aufnahme. Bei 5 000 Aufnahmen sind das 75–150 MB in der Cloud. Das ist der
Preis für sofortiges Scrollen auf jedem Gerät; er steht bewusst hier.

## 4. Erzeugung

### 4.1 Beim Sichern (der Normalfall)

Am Upload-Punkt (`virtual_mirror_sync.dart:571`) liegt die exportierte Datei
schon auf der Platte. Dort wird das Vorschaubild erzeugt — **nicht** einzeln
hochgeladen, sondern gesammelt und nach dem Lauf in einem Block übertragen:

1. `ThumbnailCreator.create(tempFile, assetId)` → JPEG-Bytes oder null
2. Bytes in den lokalen Cache schreiben (siehe §6)
3. Pfad in einer Warteliste merken
4. Nach dem Upload-Durchlauf: Warteliste abarbeiten, jede Datei nach
   `.fibu/thumbs/<hash>.jpg` hochladen

**Warum gesammelt:** Ein rclone-Aufruf pro Aufnahme zusätzlich würde die Zahl
der RPCs verdoppeln. Im Block kostet es einen eigenen Fortschrittsschritt
(„Vorschauen übertragen") und ändert am Upload-Takt nichts.

**Erzeugung pro Plattform** — hier liegt die einzige echte technische Grenze:

| Plattform | Decoder | Encoder | Ergebnis |
|---|---|---|---|
| iOS / Android | `photo_manager` (`AssetEntity.thumbnailDataWithSize`, liefert JPEG) | entfällt | immer, auch HEIC |
| Windows | `image`-Paket (JPEG, PNG, WebP, GIF, BMP) | `image`-Paket (`encodeJpg`) | für diese Formate |
| Windows, HEIC | — | — | **kein Vorschaubild**, Kachel bleibt |

Zwei Punkte, die beim Umsetzen zu prüfen sind ( offline nicht verifizierbar):

* `photo_manager` 3.12: exakter Name und Signatur der Thumbnail-API
  (`thumbnailDataWithSize(ThumbnailSize(256, 256), quality: 70)`).
* `image`-Paket: neu in `pubspec.yaml`, reine Dart-Implementierung, kein
  nativer Code, kein Privacy-Manifest-Eintrag. Lizenz (Apache-2.0) in die
  In-App-Lizenzliste.

`dart:ui` ist bewusst **nicht** der Encoder: `Frame.image.toByteData` kann
nur PNG, und PNG-Fotos wären mit 80–120 KB pro Stück zu groß.

### 4.2 Bestände nachziehen

Beim Öffnen des Explorers wird `.fibu/thumbs/` **einmal** aufgelistet. Aus der
Differenz zur Dateiliste ergibt sich, was fehlt.

* Fehlt etwas und wurde noch nie nachgezogen → Hinweis am Kopf des Explorers:
  „Für 1 284 Aufnahmen gibt es noch keine Vorschau" mit Knopf **Jetzt
  erzeugen** und **Später**.
* Der Lauf: pro Aufnahme herunterladen → dekodieren → kodieren → in den
  Cache → hochladen. Mit Fortschritt, Abbruch, und Drosselung (siehe §7).
* Die Entscheidung „Später" wird pro Cloud gemerkt (`shared_preferences` ist
  nicht nötig — eine Zeile in `settings.json` genügt), damit der Hinweis nicht
  bei jedem Öffnen kommt. Nach dem nächsten Sync fragt er einmal neu.

**Warum nicht automatisch beim Sync:** Der Nutzer entscheidet, wann
Datenvolumen fließt — und der Hinweis erscheint genau dort, wo der Mangel
sichtbar wird.

## 5. Lokaler Cache

`<Cache-Verzeichnis>/thumbs/<hash>.jpg`

* **Zweck:** Scrollen ohne Netzwerk. Ohne Cache wäre jedes Scrollen ein
  Download.
* **Schreiben:** bei Erzeugung (§4) und bei jedem Download aus der Cloud.
* **Lesen:** Explorer und Vollbild-Ansicht lesen zuerst den Cache.
* **Größe:** weiche Grenze 200 MB. Darüber wird das älteste Drittel gelöscht
  (Datei-Änderungszeit). Kein LRU-Buch, keine Datenbank — eine Ordnerliste
  reicht bei ein paar tausend Dateien.
* **Wegwerfbar:** Der Cache darf jederzeit gelöscht werden; er ist vollständig
  aus der Cloud wiederherstellbar.

## 6. Explorer: Raster mit Vorschaubildern

**Kachel.** Vorschaubild `BoxFit.cover`, abgerundete Ecken (`radiusSm`),
darunter nichts — Name und Größe verschwinden aus der Kachel und stehen in der
Vollbild-Ansicht.

**Drei Zustände pro Kachel**, alle ohne Flackern:

1. **Platzhalter** — dezente Akzentfläche mit Dateisymbol, solange geladen wird
2. **Vorschaubild** — aus dem Cache oder nach dem Download
3. **Dateikachel** — Name + Größe, wenn es kein Vorschaubild gibt (HEIC auf
   Windows) oder das Laden fehlschlug

**Laden.** Ein `ThumbnailService` mit:

* Warteschlange und **maximal 4 gleichzeitigen Downloads** — sonst bricht ein
  Scroll-Schub die Verbindung zusammen
* Abbruch beim Wegscrollen: Kacheln, die nicht mehr sichtbar sind, verlieren
  ihren Platz in der Warteschlange
* Ein Download pro Datei gleichzeitig (kein Doppel-Download bei schnellem
  Scrollen)

**Spalten.** Heute fest 3 (`crossAxisCount: 3`). Das ist auf einem
Windows-Fenster zu grob. Neu: 3 auf Telefonen, 5 auf Tablets, 6 auf Windows —
über die verfügbare Breite, nicht über die Plattform.

**Gliederung.** Heute: Tagesgruppen mit Überschrift. Neu: **Monats-Trenner**
(„September 2026") als eigene Zeile, darunter die Tagesgruppen wie bisher.
Aufnahmen ohne Datum bleiben im Sammel-Tag „Ohne Datum" — nichts wird
unterschlagen.

## 7. Vollbild-Ansicht

Neuer Bildschirm `CloudPhotoViewer`, geöffnet aus der Kachel:

* **Blättern:** `PageView` über die Aufnahmen der aktuellen Gruppe, links und
  rechts; auf Windows zusätzlich **Pfeiltasten** und **Esc** zum Schließen
  (`Shortcuts`/`Actions`, kein roher Tastatur-Listener)
* **Zoomen:** `InteractiveViewer`, Doppel tippen zoomt, zwei Finger zoomen
* **Kopfzeile:** Name, Aufnahmedatum, Größe — die Angaben, die aus der Kachel
  herausgewandert sind
* **Aktion:** „In Standard-App öffnen" bleibt (bestehender
  `FileViewerService.openInDefaultApp`)
* **Laden:** Vollbild lädt die **Originaldatei** über
  `FileViewerService.getLocalFile`, nicht das Vorschaubild. Bis sie da ist,
  bleibt das Vorschaubild als Platzhalter stehen — kein schwarzes Loch
* **HEIC auf Windows:** Die Originaldatei lässt sich nicht darstellen. Dann
  steht dort der Hinweis „Dieses Format kann Windows nicht anzeigen" mit dem
  Knopf „In Standard-App öffnen" — Windows selbst kann HEIC oft, Flutter
  nicht. Keine Ausrede, aber eine echte Grenze.

## 8. Leistungsbudgets

| Wert | Grenze |
|---|---|
| Vorschaubild | 256 px, JPEG q70, 15–30 KB |
| Gleichzeitige Downloads | 4 |
| Cache | 200 MB weich, ältestes Drittel raus |
| Dekodieren | `cacheWidth: 512` — nie in voller Auflösung |
| Nachzieh-Lauf | max. 50 Aufnahmen pro Durchlauf, dann Pause; abbrechbar |
| Listing `.fibu/thumbs/` | einmal pro Explorer-Öffnung |

## 9. Fehlerverhalten

* Vorschaubild fehlt oder Download schlägt fehl → Dateikachel, kein Fehlerdialog
* Erzeugung beim Sichern schlägt fehl → die **Aufnahme selbst wird trotzdem
  gesichert**; der Fehler geht ins Protokoll, nicht an den Nutzer. Ein
  Vorschaubild ist niemals ein Grund, eine Sicherung abzubrechen.
* `.fibu/thumbs/` nicht listbar (Provider ohne Listen-Recht) → Explorer
  arbeitet ohne Vorschaubilder weiter
* Nachzieh-Lauf abgebrochen → der Stand bleibt, beim nächsten Öffnen geht es
  weiter (die Differenz wird jedes Mal neu berechnet)

## 10. Datenschutz und Doku

* Vorschaubilder sind **abgeleitete Bilddaten** in der Cloud des Nutzers. Sie
  gehen an denselben Anbieter wie die Aufnahmen selbst, an keinen Dritten.
* `docs/DATENSCHUTZ.md` bekommt einen Absatz: was in `.fibu/thumbs/` liegt,
  dass es aus den eigenen Aufnahmen erzeugt wird, und dass Löschen der
  Sicherung es mitlöscht.
* **Achtung:** Die In-App-Fassung der Datenschutzerklärung ist eine zweite,
  hardcodierte Kopie (`legal_documents_screen.dart`, `LegalDocuments.privacy`).
  Sie muss denselben Absatz bekommen — das ist eine Code-Änderung und läuft
  in Phase 5e mit.
* `docs/ARCHITECTURE.md`: neuer Abschnitt „Vorschaubilder".
* `README.md`: die Formulierung „keine Vorschaubilder" ist dann falsch und
  muss raus.

## 11. Testplan

**Unit** (`test/unit/thumbnail_service_test.dart`)

* Namensschema: stabil, pfadsicher, gleicher Pfad → gleicher Name,
  verschiedene Pfade → verschiedene Namen
* Cache: schreibt, liest, wirft das älteste Drittel über der Grenze raus
* Warteschlange: maximal 4 gleichzeitig, kein Doppel-Download, Abbruch
* Differenzrechnung: was fehlt, wenn die Cloud-Liste leer / voll / teilweise
  ist
* Kodieren: eine kleine Testdatei rein, JPEG mit ≤ 256 px raus (rundet den
  Encoder-Verdacht ab)

**Unit** (`test/unit/cloud_photo_groups_test.dart`)

* Monats- und Tagesgliederung, Sortierung, „Ohne Datum"-Sammelgruppe

**Widget**

* Kachel zeigt Platzhalter, dann Bild aus einer echten Cache-Datei
* Ohne Vorschaubild zeigt die Kachel Name und Größe
* Vollbild öffnet, blättert mit `PageView`, zeigt die Kopfzeile
* Windows: Pfeiltaste blättert, Esc schließt

**Manuell zu prüfen** (steht dann im Protokoll, nicht im Code)

* HEIC auf Windows bleibt Dateikachel
* Nachzieh-Lauf mit einigen hundert Aufnahmen auf einem echten Gerät

## 12. Phasen

| # | Inhalt | Risiko |
|---|---|---|
| 5a | `ThumbnailService` (Name, Cache, Warteschlange, Differenz) + Unit-Tests | niedrig — reine Logik |
| 5b | `ThumbnailCreator` pro Plattform + Hook beim Sichern + Nachzieh-Lauf + Hinweis | mittel — neue Abhängigkeit `image` |
| 5c | Explorer-Raster mit Vorschaubildern, Spalten nach Breite, Monats-Trenner | mittel |
| 5d | Vollbild-Ansicht mit Blättern, Zoom, Tastatur | mittel |
| 5e | Doku: DATENSCHUTZ (Datei **und** In-App), ARCHITECTURE, README | niedrig |

Jede Phase ein Commit, dazwischen ein grüner CI-Lauf. 5a und 5e sind auch
allein sinnvoll; 5b ohne 5c bringt noch nichts Sichtbares.

## 13. Risiken

1. **`image`-Paket** ist eine neue Abhängigkeit. Reine Dart-Implementierung,
   kein nativer Code, kein Privacy-Manifest-Eintrag — aber sie muss in die
   In-App-Lizenzliste.
2. **HEIC auf Windows** bleibt ohne Vorschaubild. Das ist eine Grenze von
   Flutter/Skia, nicht von Fibu, und sie wird so kommuniziert.
3. **Speicher in der Cloud** wächst um 75–150 MB bei 5 000 Aufnahmen. Wer das
   nicht will, kann den Nachzieh-Lauf ablehnen; beim Sichern entstehen sie
   trotzdem — wenn das nicht gewünscht ist, braucht es einen Schalter
   (offener Punkt).
4. **Provider ohne Listen-Recht** auf `.fibu/thumbs/` → ohne Vorschaubilder,
   aber voll funktionsfähig.
5. **Erster Lauf nach dem Update** zeigt überall Dateikacheln, bis der
   Nachzieh-Lauf durch ist. Der Hinweis erklärt das.

## 14. Offene Punkte

1. Soll es einen Schalter „Vorschaubilder in der Cloud speichern" geben?
   Vorschlag: ja, in den Einstellungen unter „Sicherung", Standard an.
2. Vorschaubilder auch für **Datei-Sicherungen** (PDF, Office) oder nur für
   Bilder und Videos? Vorschlag: nur Bilder und Videos.
3. Löschen verwaister Vorschaubilder (Aufnahme weg, Vorschaubild noch da)?
   Vorschlag: beim Nachzieh-Lauf mit aufräumen, einmal pro Durchlauf.
