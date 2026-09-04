# Fibu — Testmatrix iOS ↔ Windows

Stand: `main` @ `bd7659f`. Jeder Befund ist gegen den Code geprüft und mit
Datei:Zeile belegt. Die `rclone`-Semantik ist gegen die offizielle
Dokumentation geprüft, nicht angenommen.

Legende:

| Zeichen | Bedeutung |
|---|---|
| ✅ | Funktioniert wie erwartet |
| ⚠️ | Fallstrick — funktioniert, aber anders als die UI verspricht |
| ❌ | **Datenverlust** oder Funktionsausfall |
| 🔒 | Durch Sicherheitsbremse abgefangen |

---

## 0. Die Grundlage: Beide Plattformen nutzen jetzt dieselbe Engine

**Stand: aktualisiert am 2026-09-04 gegen `main` @ `4316ac3`.** Jede Zeile ist
gegen den Code geprüft, nicht fortgeschrieben.

Ursprünglich bedeutete „Spiegelung" auf den beiden Plattformen etwas
grundverschiedenes — Windows lief `rclone sync` (1-Weg mit Löschrecht, ohne
Zustand). Das ist behoben: Beide Plattformen nutzen `VirtualMirrorSyncEngine`.

| | iOS | Windows |
|---|---|---|
| Engine | `VirtualMirrorSyncEngine` | **dieselbe** (`rclone_service_impl.dart:198`) |
| Richtung | 2-Wege | 2-Wege |
| Download | in die Mediathek (`PhotoKitBridge`) | in den Ordner (`FilesystemMirrorSource.importDownloaded`) |
| Lösch-Erkennung | Tombstones + `previouslySyncedRels` | **dieselbe Logik** (gleiche Engine) |
| Zustand | `mirror_state.json` je Scope | `mirror_state.json` je (Ordner, Laufwerk, Ziel) |
| Anomalie-Bremse | 20 % + Obergrenze 25 | **dieselbe** (gleiche Engine, `virtual_mirror_sync.dart:83,613`) |
| Lokales Löschen | Systemdialog der Fotos-App | **Papierkorb** `.fibu-trash`, 30 Tage, kein Dialog |
| `.fibu/`-Schutz | ja | ja (`filesystem_mirror_source.dart:53-55`) |
| Inkrementell | eigener Pfad | `rclone copy` — löscht nie (`rclone_service_impl.dart:204`) |

**Warum das ging.** Die Engine liest `assetId` intern nie; sie verlangt nur
vier Callbacks. Das war die einzige Kopplung an die Mediathek.

**Ein bewusster Unterschied bleibt:** Auf dem Desktop gibt es keinen
Systemdialog wie bei der iOS-Fotos-App, der eine Cloud-Löschung abfangen
könnte. Deshalb wird lokal nie hart gelöscht, sondern in einen Papierkorb mit
30 Tagen Aufbewahrung verschoben (`filesystem_mirror_source.dart:133,152`).

---

## A. Einrichtung

| # | Szenario | Ergebnis | Beleg / Begründung |
|---|---|---|---|
| A1 | Nur iOS, Aufgabe anlegen, syncen | ✅ | Referenzfall, unverändert |
| A2 | Nur Windows, Aufgabe anlegen | ⚠️ | Quelle muss gewählt werden (Preset ist jetzt leer). Modus „Spiegelung" ist wählbar, verhält sich aber 1-Weg |
| A3 | iOS zuerst, dann Windows **manuell** | ✅ | Getrennte `tasks.json`, getrennte Registry. Kein Konflikt solange die Zielordner verschieden sind |
| A4 | iOS zuerst, dann Windows **per Kopplung** | ⚠️ | `rclone.conf`, `remotes.json`, `tasks.json` werden übernommen. Mediathek-Quelle wird geleert (`device_pairing_screen.dart:_importBundle`), **`syncMode: mirror` aber nicht** |
| A5 | Windows zuerst, dann iOS manuell | ✅ | Symmetrisch zu A3 |
| A6 | Windows zuerst, dann iOS **per Kopplung** | ✅ **gelöst**: Die Rolle ist ein Schalter auf jeder Plattform (`device_pairing_screen.dart:66,75`), nicht mehr plattform-abgeleitet. Der Startwert folgt nur der wahrscheinlicheren Richtung |
| A7 | Beide, verschiedene Cloud-Konten | ✅ | Keine Berührung |
| A8 | Beide, gleiches Konto, **verschiedene** Zielordner | ✅ | Voreinstellung: iOS `fibu-backup/Photos`, Windows-Wizard `Mediathek` |
| A9 | Beide, gleiches Konto, **gleicher** Zielordner | ❌ | Siehe B9 — der gefährlichste Fall der ganzen Matrix |

**Zu A6:** `_isReceiver` in `device_pairing_screen.dart` ist
`windows || macOS || linux`. iOS und Android sind immer Sender. Wer von
Windows auf iOS übertragen will, hat keinen Weg. Das ist eine Lücke, kein Bug
im engeren Sinn — aber die Matrix-Anforderung „Windows zuerst, dann iOS" ist
damit nicht erfüllbar.

**Zu A4:** Die Kopplung macht A9 **wahrscheinlicher**, nicht unwahrscheinlicher.
Die iOS-Aufgabe kommt mit `targetFolderName: 'fibu-backup/Photos'` und
`syncMode: mirror` auf Windows an. Der Nutzer wählt nur noch den Ordner — und
hat damit genau die Konstellation, die B9 auslöst.

---

## B. Betrieb: Änderungen auf einer Plattform

Spalte „Modus" = Modus der **anderen** Plattform auf demselben Zielordner.

### B-I. Änderung auf iOS, danach läuft Windows

| # | Was auf iOS passiert | Windows **inkrementell** (`copy`) | Windows **Spiegelung** (Engine) |
|---|---|---|---|
| B1 | Foto **hinzugefügt** → landet in der Cloud | ✅ bleibt liegen | ✅ **wird heruntergeladen** — echte 2-Wege-Spiegelung |
| B2 | Foto **geändert** → neue Fassung in der Cloud | ✅ bleibt liegen | ✅ `contentCmp` (Größe+Modtime) erkennt es, Windows lädt die neue Fassung |
| B3 | Foto **gelöscht** → Tombstone → Cloud-Löschung | ✅ korrekt, beide weg | ✅ korrekt, beide weg |
| B4 | Album **umbenannt** → Pfad ändert sich | ⚠️ alter Pfad bleibt als Waise liegen | ⚠️ alter Pfad gilt als „lokal gelöscht" → Tombstone; neuer Pfad wird heruntergeladen. Ergebnis korrekt, aber einmal hin und her |
| B5 | 500 Fotos neu | ✅ | ✅ alle 500 heruntergeladen |

**Was sich geändert hat.** Vorher lief hier `rclone sync` und löschte alles,
was der Windows-Ordner nicht kannte. Jetzt entscheidet dieselbe Engine wie auf
iOS über Zustand, Tombstones und Adoptions-Mengen.

**Erster Windows-Lauf auf einem bereits gefüllten Zielordner:** Es gibt noch
keinen Zustand, also keine `previouslySyncedRels` und damit keine
Lösch-Kandidaten. Cloud-only-Dateien werden heruntergeladen, nicht gelöscht —
korrektes Spiegel-Verhalten.

### B-II. Änderung auf Windows, danach läuft iOS

| # | Was auf Windows passiert | iOS **inkrementell** | iOS **Spiegelung** |
|---|---|---|---|
| B6 | Datei **hinzugefügt** → in der Cloud | ✅ bleibt in der Cloud, iOS lädt sie nicht | ⚠️ iOS lädt sie und importiert sie **in die Mediathek** (`importDownloaded`, 1955) |
| B7 | Datei **geändert** | ✅ | ⚠️ `contentCmp` vergleicht Größe+Modtime → iOS lädt die Windows-Fassung |
| B8 | Datei **gelöscht** (`copy`-Modus löscht nie) | ✅ | ✅ bleibt liegen |
| B9 | Windows-Spiegelung auf geteiltem Zielordner | — | ✅ **gelöst**: Windows spiegelt jetzt 2-Wege und löscht keine fremden Dateien mehr. Die Anomalie-Bremse (20 % / Obergrenze 25) schützt zusätzlich die lokale Seite |

**B9 war der gefährlichste Fall der Matrix — und ist behoben.**

Ursprünglicher Ablauf (vor `36f392c`):
1. iOS sichert 800 Fotos nach `mega:fibu-backup/Photos/…`
2. Auf Windows wird eine Aufgabe mit Quelle `C:\Users\…\Bilder` (20 Dateien)
   und **demselben Zielordner** im Modus „Spiegelung" angelegt
3. Windows lief `rclone sync` → **780 Cloud-Dateien gelöscht**, ohne
   Bestätigung, ohne Papierkorb
4. Die iOS-Bremse schützte die Mediathek, aber die Sicherung war weg

**Heute:** Schritt 3 läuft durch dieselbe Engine wie iOS. Die 780 Dateien sind
im Windows-Zustand nicht als „lokal gelöscht" bekannt, also gibt es keine
Tombstones und keine Cloud-Löschung. Stattdessen werden sie heruntergeladen.

**Die Bremse ist trotzdem verschärft worden** (`virtual_mirror_sync.dart:83,613`),
weil sie auch bei echtem Fremd-Eingriff schützen soll:

| | vorher | jetzt |
|---|---|---|
| relative Grenze | > 50 % | **> 20 %** |
| absolute Grenze | keine | **> 25 Dateien pro Lauf** |

Die absolute Grenze deckt ab, was eine Prozentgrenze nicht kann: kleine
Bibliotheken. Bei 12 Dateien wären 24 % erst drei Dateien.

### B-III. Beide ändern dasselbe

| # | Szenario | Ergebnis |
|---|---|---|
| B10 | Beide fügen **gleichnamige** Datei hinzu, unterschiedlicher Inhalt | ✅ beide über `localSizesByBase` (Name **und** Größe) — dieselbe Engine, Windows liefert die Größen über `FilesystemMirrorSource.librarySizes()` |
| B11 | Beide **löschen** dieselbe Datei | ✅ idempotent |
| B12 | iOS löscht, Windows ändert | ⚠️ Reihenfolge entscheidet weiterhin — das ist bei 2-Wege-Spiegelung ohne Konflikt-Versionierung inhärent. Wer zuletzt läuft, gewinnt. Kein Datenverlust, aber kein Mergen |
| B13 | Beide **ändern** dieselbe Datei | ⚠️ `contentCmp` = Größe+Modtime, **kein Hash** (`virtual_mirror_sync.dart:61`). Gleiche Größe + gleiche Zeit = unerkannt. Gilt jetzt für **beide** Plattformen identisch |
| B14 | Beide laufen **gleichzeitig** | ✅ **gelöst**: `.fibu/lock.json` im Zielordner (`sync_lock_service.dart`). Gilt für manuelle Läufe **und** geplante (`dashboard_controller.dart:392`, `scheduler_service.dart:320`). Herzschlag 60 s, verwaist nach 5 min |

---

## C. Konfigurations- und Zustandskonflikte

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| C1 | `.fibu/config.json` bei Windows-Spiegelung | ✅ **gelöst, doppelt abgesichert.** Spiegel läuft nicht mehr über `rclone sync`, und die Dateisystem-Quelle blendet `.fibu` aus (`filesystem_mirror_source.dart:53-55`). Zusätzlich liegt `--exclude .fibu/**` auf dem `copy`-Pfad (`rclone_service_impl.dart:238`) |
| C2 | `.fibu/manifest.json` | ✅ dito |
| C3 | Folge von C1 | ✅ entfällt |
| C4 | iOS schützt `.fibu` | ✅ beim Download (`virtual_mirror_sync.dart:646`) |
| C5 | Beide Geräte schreiben `.fibu/config.json` | ✅ per `deviceId` getrennt, fremde Aufgaben bleiben | `writeConfigToRemote` |
| C6 | `mirror_state.json` | ✅ je Gerät **und** je Scope. Windows schreibt jetzt seins: `fs_<Ordner>_<Laufwerk>_<Ziel>` (`filesystem_mirror_source.dart:200`) |
| C7 | Verlaufs-Journal | ⚠️ je Gerät lokal, kein Konflikt — aber jedes Gerät sieht nur seine eigenen Läufe. Ein geräteübergreifender Verlauf existiert nicht | `scheduler_run_log.dart` |

**C1 war der heimtückischste Befund** — er brauchte keinen Bedienfehler und
zerstörte die gemeinsame Konfiguration aller Geräte. Er ist jetzt doppelt
abgesichert: Der Spiegel läuft über die Engine (kein Löschrecht), und der
`copy`-Pfad hat den Ausschluss explizit.

**Neu gefunden in dieser Runde:** Der Planer synct ohne Sperre
(`scheduler_service.dart:314`). Die geräteübergreifende Sperre griff damit nur
bei manuellen Läufen — ein geplanter Hintergrund-Lauf auf einem Gerät hätte
einem manuellen Lauf auf einem anderen in denselben Zielordner geschrieben.
Behoben: `scheduler_service.dart:320,347`.

---

## D. Randfälle

| # | Szenario | Ergebnis |
|---|---|---|
| D1 | Windows offline zum geplanten Zeitpunkt | ✅ wird als `skipped` gebucht und beim nächsten Start nachgeholt (`runMissedSyncs`) |
| D2 | Windows ohne Autostart | ⚠️ Zeitplan läuft nur bei geöffneter App. Steht jetzt im UI (`schedulePlatformNote`) |
| D3 | iOS: System weckt den Hintergrundtask nicht | ✅ gleicher Nachhol-Mechanismus |
| D4 | Kopplung, aber anderes Netz | ⚠️ Meldung „Übertragung fehlgeschlagen". Kein Zeitlimit-Fehler, der verwirrt |
| D5 | Kopplung zweimal | ✅ Server schließt nach dem ersten Bundle (`stopReceiver`) |
| D6 | Aufgabe ohne Quelle (nach Kopplung) | ✅ Sync verweigert sich mit klarer Meldung statt „fertig" |
| D7 | Windows-Preset „Mediathek-Spiegelung" | ⚠️ heißt „Mediathek", sichert aber einen Ordner. Der Name ist auf Windows irreführend |
| D8 | iOS lädt Windows-Dateien in die Mediathek | ⚠️ B6. Album-Name wird aus dem Pfad abgeleitet (`_albumNameFromRel`). Fremde Ordnerstruktur → fremde Alben in der Mediathek |
| D9 | Zwei iOS-Geräte, derselbe Zielordner | ⚠️ je eigener `mirror_state`, aber `adopted`/`blocked`-Mengen divergieren. Nicht Teil der Anforderung, aber dieselbe Klasse Problem wie A9 |

---

## Befunde — Stand nach der Umsetzung

Alle sechs ursprünglichen Befunde sind behoben. Die Belege stehen bei den
einzelnen Matrix-Zeilen.

| # | Befund | Status | Beleg |
|---|---|---|---|
| 1 | Windows-Spiegelung löscht fremde Dateien (B1, B5, B9) | ✅ **behoben** | `rclone_service_impl.dart:198` leitet Spiegel durch `VirtualMirrorSyncEngine`; `filesystem_mirror_source.dart` liefert die vier Callbacks |
| 2 | `.fibu/` liegt im Sync-Ziel (C1–C3) | ✅ **behoben, doppelt** | `filesystem_mirror_source.dart:53-55` blendet aus; `rclone_service_impl.dart:238` hat `--exclude` auf dem `copy`-Pfad |
| 3 | Kopplung nur in eine Richtung (A6) | ✅ **behoben** | `device_pairing_screen.dart:66,75` — Rolle ist ein Schalter |
| 4 | Kopplung übernimmt `syncMode: mirror` unverändert (A4) | ✅ **behoben** | `device_pairing_screen.dart` stuft nur herab, wenn der **Empfänger** ein Desktop ist |
| 5 | Anomalie-Bremse zu schwach (B9) | ✅ **verschärft** | `virtual_mirror_sync.dart:83,613` — 20 % statt 50 %, plus Obergrenze 25 |
| 6 | Kein geräteübergreifender Sync-Lock (B14) | ✅ **behoben** | `sync_lock_service.dart`; greift bei manuellen **und** geplanten Läufen |

### In dieser Runde neu gefunden und behoben

| Befund | Status |
|---|---|
| Der Planer synct ohne Sperre (`scheduler_service.dart:314`) — die Sperre griff nur bei manuellen Läufen | ✅ `scheduler_service.dart:320,347` |
| Destruktive Aktionen lagen im CommandBar-Overflow und waren nicht auffindbar | ✅ zurück in `primaryItems` |

---

## Zweite Runde: B12/B13, C7 und B4 sind umgesetzt

Alle drei laufen ohne Nutzerinteraktion.

| # | Vorher | Jetzt |
|---|---|---|
| **B12/B13** | `contentCmp` verglich nur Größe+Modtime. Gleiche Größe plus gleiche Zeit galt als „identisch", obwohl beide Geräte unterschiedliche Inhalte hatten. Wer zuletzt lief, gewann — still | **3-Way-Abgleich gegen die Basis** (`lastKnown`, war schon vorhanden). `Basis == lokal, Basis != remote` → remote holen. `Basis != lokal, Basis == remote` → lokal senden. **Beide ≠ Basis und untereinander → Konflikt** |
| **C7** | Jedes Gerät sah nur seine eigenen Läufe | Jedes Gerät veröffentlicht sein Journal unter `<Ziel>/.fibu/journal/<deviceId>.jsonl`; `readAllDevices` liest die Vereinigung, dedupliziert über Zeit+Pfad+Art. Fail-open |
| **B4** | Album-Umbenennung = Tombstone + vollständiger Neu-Upload | **Rename-Erkennung** über Größe **und** Modtime aus der Basis; serverseitiges `moveRemoteFile` statt Transfer. Provider ohne Server-Side-Move fallen auf den normalen Upload zurück |

**Konflikt-Verhalten im Detail.** Bei echtem Konflikt geht nichts verloren: Die
lokale Fassung wird unter einem Zeitstempel-Namen hochgeladen
(`IMG_0001 (Konflikt 2026-09-04 14-03).HEIC`), die Cloud-Fassung bleibt liegen.
Der Zeitstempel ist Absicht — zwei Geräte können denselben Konflikt unabhängig
benennen, ohne sich zu überschreiben. Die Statuszeile bekommt einen eigenen
Text, statt auf „Auf Änderungen überprüfen" zurückzufallen.

**Was B13 nicht löst.** Der 3-Way-Abgleich erkennt Konflikte zuverlässig, aber
er hash-t nicht. Zwei Dateien mit identischer Größe **und** identischer
Änderungszeit **und** unterschiedlichem Inhalt bleiben unerkannt. In der Praxis
ist das bei Fotos praktisch unmöglich, aber es ist keine kryptographische
Garantie. Ein echter Hash wäre die vollständige Lösung — und bei einer
Mediathek mit Gigabytes ein spürbarer Kostenpunkt.

---

## Was offen bleibt

| # | Punkt | Art |
|---|---|---|
| 1 | **B13-Rest** — kein Inhalts-Hash. Größe+Zeit+Inhalt gleichzeitig gleich bleibt unerkannt | inhärent ohne Hash |
| 2 | **D8** — iOS importiert Windows-Dateien in die Mediathek, Album-Name kommt aus dem Pfad | Verhalten, geprüft |
| 3 | **Kein Gerät getestet.** Alles ist aus dem Code abgeleitet. Analyzer und Tests sind grün (`a912ddd`, beide Workflows), aber das ist keine Laufzeit-Verifikation. Insbesondere Konflikt-Erkennung und Rename-Erkennung sind neu und nicht gegen echte Daten gelaufen | Verifikation |

### Nicht mehr zutreffend

Die frühere Empfehlung „Spiegelung auf Windows sperren oder umbenennen" ist
überholt: Windows spiegelt jetzt echt 2-Wege. Die plattformabhängige
Modus-Beschreibung (`app_strings.dart`) bleibt trotzdem richtig — sie
beschreibt auf dem Desktop jetzt den Papierkorb statt des Systemdialogs.
