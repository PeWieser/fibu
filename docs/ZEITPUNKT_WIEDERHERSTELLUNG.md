# Fibu — Verlauf & Zeitpunkt-Wiederherstellung („Time Machine")

Plan und Umsetzung. Stand: `main`.

## Ziel

Bei jeder Änderung, die die App lokal feststellt — **hinzugefügt, geändert,
gelöscht** — wird ein Eintrag in ein anwachsendes Journal geschrieben. Später soll die
Frage möglich sein: *„Wie war der Stand am 23. September 2026?"* — mit
selektiver Wiederherstellung einzelner Dateien, nicht alles oder nichts.

## Die ehrliche Grenze vorweg

Ein Journal kann beantworten, **was** es zu einem Zeitpunkt gab. Es kann keine
Bytes herbeizaubern. Für die Wiederherstellung braucht es die Daten selbst,
und dafür gibt es genau drei Fälle:

| Fall | Wiederherstellbar? |
|---|---|
| Datei liegt noch in der Cloud, hat sich seit dem Stichtag **nicht** geändert | **Ja** — normaler Download |
| Datei wurde gelöscht und liegt noch im Fibu-Papierkorb (`.fibu-trash`, 30 Tage) | **Ja** — aus dem Papierkorb |
| Datei liegt noch in der Cloud, wurde aber **nach** dem Stichtag überschrieben | **Nein** — Fibu kennt nur die aktuelle Fassung. Versionierung kann hier nur der Cloud-Anbieter liefern (z. B. MEGA, Dropbox, OneDrive haben eigene Versionen) |
| Datei gelöscht und Papierkorb bereits geleert | **Nein** |

Die Oberfläche muss das pro Datei sagen, statt einen Erfolg zu versprechen,
der nicht eintritt. Das ist dieselbe Regel wie bei der Sync-Statusleiste:
nichts anzeigen, was nicht passiert.

**Konsequenz:** Fibu ist damit ein **Änderungs-Journal mit gezielter
Wiederherstellung**, keine echte Time Machine. Für echte
Punkt-in-Zeit-Wiederherstellung überschriebener Dateien müsste die App
Versionen selbst vorhalten — das wäre ein eigener Speicherpfad
(`.fibu-versions/`) mit eigenem Platzbedarf und ist hier bewusst **nicht**
gebaut. Siehe „Nächster Schritt".

## Warum JSONL und keine SQLite

`sqflite` steht auf Apples Liste der SDKs, die zwingend ein eigenes Privacy
Manifest **und** eine Signatur brauchen
([Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)).
Ein neues Paket dort kostet einen weiteren Wartungspunkt im Audit (L-13).

Ein **append-only JSONL** (eine JSON-Zeile pro Änderung) ist für ein
inkrementelles Journal ohnehin die natürlichere Form: anhängen statt
umschreiben, keine Transaktionen, keine Migration, mit jedem Editor lesbar.

## Speicherort

`Library/Application Support/fibu_state/<scope>/change_journal.jsonl`

Also direkt neben `mirror_state.json` und `tombstones.json` desselben Scopes
(Laufwerk + Zielpfad + Quelle). Privater Ordner, nicht über die Dateien-App
sichtbar — konsistent zu Befund L-06: Das Journal enthält Dateinamen und
Albennamen, also personenbezogene Daten.

## Datenmodell

Eine Zeile = eine beobachtete Änderung:

```json
{"v":1,"at":"2026-09-23T14:02:11.000Z","k":"add","rel":"Photos/Camera Roll/IMG_0001.HEIC","size":2314567,"mt":1758632531000}
{"v":1,"at":"2026-09-23T14:02:11.000Z","k":"del","rel":"Photos/WhatsApp/IMG_9.JPG","size":812344,"mt":1758100000000,"trash":".fibu-trash/1758632531_IMG_9.JPG"}
```

| Feld | Bedeutung |
|---|---|
| `v` | Schema-Version, für spätere Migrationen |
| `at` | UTC-Zeitpunkt der Beobachtung |
| `k` | `add` \| `mod` \| `del` \| `restore` |
| `rel` | relativer Pfad im Spiegel |
| `size` | Bytegröße zum Zeitpunkt der Beobachtung |
| `mt` | Änderungszeit der Datei (ms seit Epoch) |
| `trash` | nur bei `del`: Ziel im Fibu-Papierkorb, falls dorthin verschoben |

`add` und `mod` werden unterschieden, damit die Oberfläche „neu" und
„geändert" getrennt zählen kann. Für die Zustandsrekonstruktion sind sie
identisch.

## Zustandsrekonstruktion

`stateAt(t)` spielt das Journal von vorn bis `t` nach:

- `add` / `mod` / `restore` → `present[rel] = Zustand`
- `del` → `present.remove(rel)`, Löschinfo merken

Damit ist automatisch korrekt, dass eine am 20.09. gelöschte und am 25.09.
neu angelegte Datei am 23.09. **nicht** existierte.

Einträge werden vor dem Abspielen aufsteigend nach `at` sortiert und nicht
übersprungen, sondern gefiltert — die Geräteuhr kann verstellt werden
(vergleiche `docs/STRESSTEST_DAU.md`, K4).

## Wiederherstellungs-Plan

Für einen Stichtag `t`:

1. `present = stateAt(t)`
2. `current` = `items` aus `mirror_state.json` (was jetzt synchronisiert ist)
3. `fehlend = present − current` → Kandidaten
4. Pro Kandidat die Quelle bestimmen:
   - liegt der Pfad remote noch? → **Cloud**
   - sonst: letzter `del`-Eintrag mit `trash` und Papierkorb-Datei vorhanden?
     → **Papierkorb**
   - sonst → **nicht verfügbar**

Die Oberfläche zeigt die drei Gruppen getrennt und lässt einzeln oder
gruppenweise auswählen.

## Wachstum

Ein Journal mit 30.000 Fotos und täglichen Syncs wächst. Deshalb:

- **Begrenzung:** Einträge älter als `retention` (Voreinstellung 90 Tage)
  werden beim Verdichten verworfen.
- **Verdichten:** Nach `add`/`mod` ohne dazwischenliegendes `del` genügt die
  jüngste Zeile pro Pfad. `del`-Einträge bleiben bis zum Ablauf der
  Aufbewahrung, sonst wäre die Papierkorb-Zuordnung weg.
- **Auslöser:** Verdichtet wird am Ende eines Syncs, nicht mittendrin.

## Was nicht gebaut wurde

- **Eigene Versionierung.** Überschriebene Dateien behalten ihre alte Fassung
  nicht. Dafür müsste Fibu vor dem Überschreiben die alte Version nach
  `.fibu-versions/` kopieren — eigener Platzbedarf, eigene Aufräumlogik.
- **Automatische Wiederherstellung ganzer Stichtage.** Bewusst nur selektiv,
  weil ein Voll-Rollback die Mediathek umtausende Fotos ändern würde.
- **Journal für den inkrementellen (Nicht-Spiegel-)Modus.** Der Journal-Haken
  sitzt in der Spiegel-Engine. Der inkrementelle Pfad kennt keine lokalen
  Löschungen und hat damit nichts zu journalisieren, was über die Cloud hinaus
  ginge.

## Nächster Schritt

`.fibu-versions/` mit konfigurierbarer Tiefe (z. B. 3 Versionen pro Datei),
damit auch überschriebene Dateien zu einem Stichtag zurückkönnen. Das ist der
einzige Weg zu einer echten Punkt-in-Zeit-Wiederherstellung ohne
Provider-Versionierung.
