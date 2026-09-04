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

## 0. Die Grundlage: Beide Plattformen tun NICHT dasselbe

Das ist die wichtigste Erkenntnis der ganzen Matrix. „Spiegelung" bedeutet auf
den beiden Plattformen etwas grundverschiedenes.

| | iOS (`virtual_mirror_sync.dart`) | Windows (`rclone_service_impl.dart`) |
|---|---|---|
| Befehl | eigener Algorithmus | `isEchoMode ? 'sync' : 'copy'` (Zeile 188) |
| Richtung | **2-Wege**: hoch **und** runter | **1-Weg**: nur hoch |
| Download in die Mediathek | ja, `importDownloaded` (1955) | **nein, existiert nicht** |
| Lösch-Erkennung | Tombstones + `previouslySyncedRels` | **keine** (grep: 0 Treffer) |
| Zustand | `mirror_state.json` je Scope | **keiner** |
| `.fibu/`-Schutz | ja (Zeile 646) | **nein** |
| Anomalie-Bremse | ja (Zeile 593) | **nein** |
| Papierkorb | ja, `.fibu-trash` | **nein** |

**Beleg für die `sync`-Semantik** (rclone.org/commands/rclone_sync):

> „Destination is updated to match source, **including deleting files if
> necessary**. If you don't want to delete files from destination, use the
> `copy` command instead. **Important: Since this can cause data loss**, test
> first with the `--dry-run` flag."

**Was die UI auf beiden Plattformen verspricht** (`app_strings.dart:336`):

> „Exakte 2-Wege-Spiegelung: Neue Dateien aus der Cloud werden auch lokal
> heruntergeladen. Dateien, die du lokal löschst, werden auch in der Cloud
> gelöscht!"

Auf Windows ist **beides falsch**: Es wird nichts heruntergeladen, und lokale
Löschungen löschen über `rclone sync` die Cloud — ohne Bestätigung, ohne
Papierkorb, ohne Bremse.

---

## A. Einrichtung

| # | Szenario | Ergebnis | Beleg / Begründung |
|---|---|---|---|
| A1 | Nur iOS, Aufgabe anlegen, syncen | ✅ | Referenzfall, unverändert |
| A2 | Nur Windows, Aufgabe anlegen | ⚠️ | Quelle muss gewählt werden (Preset ist jetzt leer). Modus „Spiegelung" ist wählbar, verhält sich aber 1-Weg |
| A3 | iOS zuerst, dann Windows **manuell** | ✅ | Getrennte `tasks.json`, getrennte Registry. Kein Konflikt solange die Zielordner verschieden sind |
| A4 | iOS zuerst, dann Windows **per Kopplung** | ⚠️ | `rclone.conf`, `remotes.json`, `tasks.json` werden übernommen. Mediathek-Quelle wird geleert (`device_pairing_screen.dart:_importBundle`), **`syncMode: mirror` aber nicht** |
| A5 | Windows zuerst, dann iOS manuell | ✅ | Symmetrisch zu A3 |
| A6 | Windows zuerst, dann iOS **per Kopplung** | ❌ | **Richtung falsch gebaut.** Der Empfänger ist immer der Desktop; iOS ist nur Sender. Eine Windows→iOS-Übertragung existiert nicht (`_isReceiver` ist nur auf Desktop true) |
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

| # | Was auf iOS passiert | Windows **inkrementell** (`copy`) | Windows **Spiegelung** (`sync`) |
|---|---|---|---|
| B1 | Foto **hinzugefügt** → landet in der Cloud | ✅ bleibt liegen | ❌ **wird gelöscht** — liegt nicht im Windows-Quellordner |
| B2 | Foto **geändert** → neue Fassung in der Cloud | ✅ bleibt liegen | ❌ **wird durch die alte Windows-Fassung überschrieben** |
| B3 | Foto **gelöscht** → Tombstone → Cloud-Löschung | ✅ korrekt, beide weg | ✅ korrekt, beide weg (zufällig richtig) |
| B4 | Album **umbenannt** → Pfad ändert sich | ⚠️ alter Pfad bleibt als Waise liegen | ❌ alter Pfad wird gelöscht, neuer Pfad fehlt im Windows-Ordner und wird nie angelegt |
| B5 | 500 Fotos neu | ✅ | ❌ alle 500 gelöscht |

**Begründung B1/B2/B5:** `rclone sync` gleicht die Quelle gegen das Ziel ab und
löscht im Ziel alles, was die Quelle nicht hat. Der Windows-Quellordner enthält
die iOS-Dateien nicht. Es gibt keinen Zustand, der sie als „fremd, aber
gewollt" markieren könnte — Windows hat keinen Zustand.

### B-II. Änderung auf Windows, danach läuft iOS

| # | Was auf Windows passiert | iOS **inkrementell** | iOS **Spiegelung** |
|---|---|---|---|
| B6 | Datei **hinzugefügt** → in der Cloud | ✅ bleibt in der Cloud, iOS lädt sie nicht | ⚠️ iOS lädt sie und importiert sie **in die Mediathek** (`importDownloaded`, 1955) |
| B7 | Datei **geändert** | ✅ | ⚠️ `contentCmp` vergleicht Größe+Modtime → iOS lädt die Windows-Fassung |
| B8 | Datei **gelöscht** (`copy`-Modus löscht nie) | ✅ | ✅ bleibt liegen |
| B9 | **Windows-Spiegelung löscht die iOS-Dateien** | — | 🔒 **Anomalie-Bremse greift**: `remoteFiles.isEmpty \|\| candidates*2 > prevCount` (Zeile 593) → lokale Löschung übersprungen |

**B9 im Detail — der wichtigste Fall der Matrix.**

Ablauf:
1. iOS sichert 800 Fotos nach `mega:fibu-backup/Photos/…`
2. Auf Windows wird eine Aufgabe mit Quelle `C:\Users\…\Bilder` (20 Dateien)
   und **demselben Zielordner** im Modus „Spiegelung" angelegt
3. Windows läuft → `rclone sync C:\Users\…\Bilder mega:fibu-backup/Photos`
4. **780 Cloud-Dateien werden gelöscht.** Ohne Bestätigung, ohne Papierkorb
5. iOS läuft als Nächstes → sieht 780 fehlende Dateien → **Bremse greift**, die
   Mediathek bleibt erhalten

Ergebnis: **Die Mediathek auf iOS überlebt, die Cloud-Kopien sind weg.** Die
Bremse schützt das Gerät, nicht die Sicherung. Genau dafür ist eine Sicherung
aber da.

Die Bremse hat außerdem eine Lücke: Sie greift nur bei `prevCount >= 10` und
wenn **mehr als die Hälfte** fehlt. Löscht Windows 30 % der Dateien, läuft die
lokale Löschung auf iOS **durch** — mit Systemdialog, aber der Nutzer sieht 240
Löschvorschläge und wird sie vermutlich bestätigen.

### B-III. Beide ändern dasselbe

| # | Szenario | Ergebnis |
|---|---|---|
| B10 | Beide fügen **gleichnamige** Datei hinzu, unterschiedlicher Inhalt | ⚠️ iOS erkennt das über `localSizesByBase` (Name **und** Größe, Zeile 670) — unterschiedliche Größe = unterschiedliche Datei. Windows hat diese Prüfung nicht |
| B11 | Beide **löschen** dieselbe Datei | ✅ idempotent |
| B12 | iOS löscht, Windows ändert | ❌ Reihenfolge entscheidet. Läuft Windows zuerst, überschreibt es; läuft iOS zuerst, löscht es die Windows-Änderung |
| B13 | Beide **ändern** dieselbe Datei | ⚠️ iOS: `contentCmp` = Größe+Modtime, **kein Hash** (`contentKey`, Zeile 61). Gleiche Größe + gleiche Zeit = unerkannt. Windows delegiert an rclone (Größe+Modtime oder MD5) |
| B14 | Beide laufen **gleichzeitig** | ⚠️ Je Gerät gibt es eine Sperre (`isSyncRunning`), aber **keine geräteübergreifende**. Zwei parallele `rclone`-Läufe auf demselben Ziel sind nicht koordiniert |

---

## C. Konfigurations- und Zustandskonflikte

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| C1 | `.fibu/config.json` bei Windows-Spiegelung | ❌ **wird gelöscht.** Liegt bei `<targetFolder>/.fibu/config.json` (`sync_config_service.dart:429`) — also **im** Sync-Ziel. Die Windows-Quelle hat kein `.fibu`, also räumt `sync` es weg | kein Schutz in `rclone_service_impl.dart` |
| C2 | `.fibu/manifest.json` | ❌ dito (`sync_manifest_service.dart:139`) | dito |
| C3 | Folge von C1 | ❌ Beim nächsten Verbindungsaufbau findet **kein** Gerät mehr die erkannten Aufgaben. Der Import-Vorschlag verschwindet still | `readRemoteConfig` liefert null |
| C4 | iOS schützt `.fibu` | ✅ nur beim **Download** (Zeile 646). Gegen das Löschen durch Windows hilft das nicht | — |
| C5 | Beide Geräte schreiben `.fibu/config.json` | ✅ seit `2a170d3` per `deviceId` getrennt, fremde Aufgaben bleiben | `writeConfigToRemote` |
| C6 | `mirror_state.json` | ✅ je Gerät **und** je (Remote, Zielpfad, Quelle) — kein Konflikt. Aber: Windows schreibt gar keins | `_virtualStateRoot` |
| C7 | Verlaufs-Journal | ✅ je Gerät lokal, kein Konflikt. Aber: Windows journalisiert nur, was der Desktop tut — iOS-Änderungen tauchen dort nie auf | `scheduler_run_log.dart` |

**C1 ist der heimtückischste Befund.** Er braucht keinen Bedienfehler: Sobald
eine Windows-Aufgabe im Modus „Spiegelung" auf einen Ordner zeigt, in dem
`.fibu/` liegt, wird die gemeinsame Konfiguration zerstört. Und sie liegt per
Voreinstellung genau da, wenn die iOS-Aufgabe per Kopplung übernommen wurde.

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

## Befunde, nach Schwere sortiert

### ❌ 1 — Windows-Spiegelung löscht fremde Dateien (B1, B5, B9)

`rclone sync` ist ein 1-Weg-Befehl mit Löschrecht. Auf einem geteilten
Zielordner löscht er alles, was das andere Gerät hochgeladen hat.

**Kurzfristige Absicherung (klein, wirksam):**
- `.fibu/**` und `.fibu-trash/**` immer als `--exclude` mitgeben (fixt C1/C2)
- Auf Windows den Modus „Spiegelung" **nicht** anbieten, solange die Quelle
  ein Ordner und das Ziel geteilt ist — oder ihn klar als „Ein-Weg-Spiegelung
  (löscht in der Cloud)" beschriften
- Die Modus-Beschreibung plattformabhängig machen. Der Satz „Neue Dateien aus
  der Cloud werden auch lokal heruntergeladen" ist auf Windows schlicht falsch

**Richtig:** Windows bräuchte denselben manifest-basierten Algorithmus wie iOS —
Zustand je Scope, Tombstones, Bremse. Das ist keine Kleinigkeit, aber die
einzige Variante, bei der „Spiegelung" auf beiden Plattformen dasselbe
bedeutet.

### ❌ 2 — `.fibu/` liegt im Sync-Ziel (C1, C2, C3)

Die gemeinsame Konfiguration liegt dort, wo gesynct wird. Jeder `sync`-Lauf
räumt sie weg.

**Fix:** `.fibu` und `.fibu-trash` in den Filtern ausschließen, **oder** die
Konfiguration außerhalb des Zielordners ablegen (z. B. `<remote>/.fibu-global/`).
Ersteres ist ein Einzeiler pro Aufrufstelle.

### ❌ 3 — Kopplung nur in eine Richtung (A6)

„Windows zuerst, dann iOS" ist nicht möglich. Entweder die Kopplung
bidirektional machen (Mobil kann auch Empfänger sein) oder die Einschränkung
klar benennen.

### ⚠️ 4 — Kopplung übernimmt `syncMode: mirror` unverändert (A4)

Die importierte Aufgabe behält den 2-Wege-Modus, den Windows nicht
implementiert. Beim Import auf den Desktop sollte der Modus auf
„inkrementell" fallen oder explizit abgefragt werden.

### ⚠️ 5 — Anomalie-Bremse schützt das Gerät, nicht die Cloud (B9)

Sie greift erst ab 50 % Schwund. Darunter läuft die lokale Löschung durch.

### ⚠️ 6 — Kein geräteübergreifender Sync-Lock (B14)

Zwei Geräte können gleichzeitig auf dasselbe Ziel schreiben.

---

## Empfohlene Reihenfolge

1. **`.fibu`-Ausschluss in den Filtern** — Einzeiler, verhindert C1/C2/C3
2. **Modus-Beschreibung plattformabhängig** — beendet die falsche Versprechung
3. **Spiegelung auf Windows sperren oder umbenennen** — verhindert B1/B5/B9
4. **`syncMode` bei der Kopplung auf inkrementell setzen** — verhindert A4
5. **Kopplung bidirektional** — ermöglicht A6
6. **Manifest-basierter Spiegel für Windows** — die eigentliche Lösung

Punkte 1–4 sind zusammen klein und schließen jeden Datenverlust-Pfad dieser
Matrix. Punkt 6 ist die richtige, aber große Lösung.

---

## Was ich nicht prüfen konnte

- **Kein Gerät, keine Cloud.** Alles ist aus dem Code und der
  rclone-Dokumentation abgeleitet. Ob ein Anbieter `.fibu`-Ordner überhaupt
  zulässt, ob `modTime` überall gesetzt wird, und wie sich `rclone sync` bei
  einem konkreten Backend verhält, ist nicht am lebenden Objekt geprüft.
- **Kein Flutter/Dart lokal.** Verifikation läuft über CI.
- **Die Matrix beschreibt Soll-Verhalten aus dem Code**, nicht beobachtetes
  Verhalten. Ein echter Testlauf mit zwei Geräten und einem Cloud-Konto würde
  mehrere dieser Zeilen vermutlich bestätigen — und vielleicht eine widerlegen.
