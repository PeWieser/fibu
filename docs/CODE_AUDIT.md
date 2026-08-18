# Fibu — Code-Audit (Qualität · Logs · Config · Multi-Geräte-Sync)

**Datum:** 2026-08-17
**Rolle:** Code-Auditor
**Umfang:** Log-Erstellung, Config-Erstellung, Sync-Pfad, allgemeine Code-Qualität, plus Zwei-Geräte-gleichzeitig-Frage.
**Bewertung:** 🟥 kritisch · 🟧 verbesserungswürdig · 🟩 ok.

---

## 1. Log-Erstellung — Befund: „viel zu viele Logs" stammt aus TOTEM Code

### 🟥 `MobileRcloneService` ist toter Code und die Quelle der Log-/Config-Probleme
**Datei:** `lib/core/services/mobile_rclone_service.dart`

Dieser Service erzeugt pro Job eine eigene Log-Datei (`fibu-logs/$jobId.log`) plus **getrennte Dauer-Logs** `delete.log`, `copy.log`, `download.log` — und schreibt auch noch eine **manuelle Text-Config** (`rclone.conf`) und `remotes.json`.

**Aber:** `MobileRcloneService` wird **nirgends mehr verwendet**:
- `rclone_provider.dart` nutzt für iOS/Android `IosRcloneService` (echte Engine), für Windows `WindowsRcloneService`, sonst `MockRcloneService`.
- `grep` zeigt: nur die **Klassendefinition** existiert, kein einziger Aufrufer.

→ **Die „zu vielen Logs" und die „unprofessionelle Config" entstammen dieser ungenutzten Attrappe.** Sie sollte gelöscht werden (siehe Empfehlungen).

### 🟩 Die echte iOS-Engine schreibt KEINE unnötigen Logs
**Datei:** `lib/core/services/ios_rclone_service.dart`
- Sie schreibt **keine** `delete.log`/`copy.log`/`download.log`.
- Nur `LibrcloneChannel.ensureInitialized` setzt den Config-Pfad; kein manuelles Logging pro Datei.
- Progress/Status laufen über Streams (`RcloneJobEvent`/`RcloneProgressEvent`) statt Datei-Logs → **sauber**.

### 🟧 `SyncConfigService.appendLocalLog` schreibt in ein Sammel-Log `fibu-logs/global.log`
**Datei:** `lib/core/services/sync_config_service.dart:119`
- `appendLocalLog('global', ...)` erzeugt/erweitert eine `global.log`, die **unbegrenzt** wächst (append, kein Rotieren/Begrenzen).
- Wird u.a. bei jedem `writeConfigToRemote`-Versuch beschrieben (inkl. Fehlversuchen).
- **Empfehlung:** Logs rotieren/begrenzen (z. B. max. N KB, alte löschen) oder nur bei Debug schreiben.

---

## 2. Config-Erstellung

### 🟩 Echte iOS-Engine nutzt rclones `config/create` (professionell)
**Datei:** `lib/core/services/ios_rclone_service.dart:addRemote`
```dart
await _rc.rpc('config/create', {
  'name': name,
  'type': type,
  'parameters': config,
  'opt': {'obscure': true, 'nonInteractive': true},
});
```
→ Passwörter werden von rclone selbst verschleiert (`obscure`), die Config wird von rclone korrekt erzeugt. **Das ist die professionelle, empfohlene Variante.**

### 🟥 Die manuelle Text-Config gehört zum toten `MobileRcloneService`
**Datei:** `lib/core/services/mobile_rclone_service.dart:addRemote`
```dart
final sb = StringBuffer();
sb.writeln('[$name]');
sb.writeln('type = $type');
config.forEach((k, v) { sb.writeln('$k = $v'); });
await confFile.writeAsString(sb.toString());
```
→ Hier liegt die **„unprofessionell aussehende Config"**: selbst zusammengebauter Text, Werte ohne rclone-Verschlüsselung im Klartext. Da dieser Service tot ist, betrifft das den iOS-Pfad nicht — aber es erklärt, was Sie gesehen haben.

### 🟨 `.fibu/config.json` (FibuRemoteConfig) — Struktur ok, aber dupliziert `sourcePath`
**Datei:** `lib/core/services/sync_config_service.dart`
- Die Struktur (`version`, `createdAt`, `deviceName`, `tasks[]`) ist sauber und professionell.
- **Befund:** `sourcePath` in der Remote-Config ist der **lokale Pfad** des erstellenden Geräts (z.B. `all` oder `files:...`). Auf einem **zweiten Gerät** macht dieser Pfad evtl. keinen Sinn, weil lokale Ordner/Staging geräteabhängig sind. Für Medien (`all`/`photos:`) ok; für lokale Ordner `files:<absPfad>` ggf. falsch.
- **Empfehlung:** Beim Import auf dem Zielgerät `sourcePath` lokal neu auflösen (bei `files:` aufs App-eigene Verzeichnis mappen) — sonst importiert Gerät B einen Pfad, der dort nicht existiert.

### 🟩 `.fibu/manifest.json` (SyncManifestService)
- Nur im toten `MobileRcloneService` geschrieben; in der echten iOS-Engine **nicht** → kein Bloat auf iOS. Gut.

---

## 3. Zwei Geräte synchronisieren ZEITGLEICH auf dasselbe Remote

### 🟥 rclone `bisync` ist NICHT für gleichzeitige Multi-Geräte-Runs ausgelegt
- **`bisync` hält seinen Zustand (Listing-Snapshots + Lock-Dateien) LOKAL auf jedem Gerät** (`<Dokumente>/.bisync/`), nicht auf dem Remote.
- Zwei Geräte haben also **getrennte, unabhängige States** und **getrennte Locks**.
- Wenn Gerät A und Gerät B **gleichzeitig** `bisync` gegen dasselbe Remote ausführen, kann sich keines über den anderen State synchronisieren:
  - A schreibt Änderungen + erneuert seine lokale Listing-Snapshot.
  - B, basierend auf seinem alten/anderen State, kann dieselben Dateien als „Konflikt"/„gelöscht" interpretieren und **löschen/überschreiben**, was A gerade hochgeladen hat.
  - Ergebnis: **Lösch-Ping-Pong, Duplikate (Konflikt-Suffixe) oder Datenverlust.**

Das rclone-Handbuch warnt explizit: bisync ist für das Teilen des Ziels zwischen mehreren Geräten **nicht geeignet** (u.a. „Not suitable for syncing multiple devices at once" / Limitationen).

### Wie löst iCloud (Photos) das? — Anderes Architektur-Paradigma
iCloud Photos funktioniert **fundamental anders** als rclone bisync:

| Aspekt | iCloud Photos | rclone bisync (aktuell) |
|---|---|---|
| Katalog | **Zentral serverseitig** (CloudKit), ein Katalog für alle Geräte | Lokaler Listing-State pro Gerät |
| Änderungserkennung | Change-Tokens / Server-Push, jeder Client merkt sich seinen letzten Sync-Punkt | Delta gegen die *lokale* Snapshot |
| Löschungen | **Tombstones** serverseitig; Löschung wird an alle Geräte propagiert (auch offline gewesene) | Löschung ergibt sich aus Delta; nur die laufenden Geräte sehen sie |
| Konflikte | Server löst (Last-Writer-Wins o. Ä.), zentral konsistent | Jedes Gerät entscheidet lokal → inkonsistent bei Gleichzeitigkeit |
| Gleichzeitigkeit | Viele Geräte können parallel einchecken (Server serialisiert) | Nicht dafür ausgelegt |

Kurz: **iCloud serialisiert alle Änderungen über einen zentralen Server-Katalog.** rclone bisync hat keinen zentralen Zustand und ist daher bei gleichzeitigen, getrennten Geräten nicht sicher.

---

## 4. Was würde konkret passieren (Simulation)

1. Gerät A und B haben beide einen Mirror-Task auf `remote:/fibu-backup/Photos`.
2. Beide rufen gleichzeitig `bisync` auf.
3. Beide lesen ihren **eigenen** (unterschiedlichen) Listing-State.
4. A lädt Foto X hoch und schreibt X in A's State.
5. B's State kennt X nicht → B sieht X als „neu auf Remote, nicht lokal" → B **lädt X nach B herunter** (ok) ODER sieht je nach Timestamp einen Konflikt → erzeugt `X.conflict`-Duplikate.
6. Laufende Geräte überschreiben sich gegenseitig die Listing-Snapshots → nächster Lauf inkonsistent → „need --resync" / Datenverlust-Risiko.

**Fazit:** Gleichzeitiges Zwei-Geräte-Sync funktioniert mit bisync **nicht zuverlässig**. Für echtes „wie iCloud" wäre ein zentraler Katalog/Tombstones nötig (deutlich über rclone hinaus) oder zumindest eine **Serialisierung** (Geräte syncen zu verschiedenen Zeiten).

---

## 5. Empfohlene Fixes (Codequalität)

| # | Maßnahme | Schwere |
|---|---|---|
| 1 | **`MobileRcloneService` löschen** (toter Code, Quelle der Log-/Config-Probleme) | 🟥 |
| 2 | `appendLocalLog` begrenzen/rotieren (max. Größe) | 🟧 |
| 3 | Beim Import von `.fibu/config.json` `sourcePath` lokal neu auflösen (v. a. `files:`) | 🟧 |
| 4 | `global.log` nur bei relevanten Ereignissen, sonst Debug-Level | 🟩 |
| 5 | `deviceName` je Gerät in `writeConfigToRemote` bleibt gut; ggf. Geräte-ID pro Task/Remote ergänzen | 🟩 |

---

## 6. Fazit

- **Logs:** Die vielen Logs stammen aus **toter** `MobileRcloneService`-Attrappe (nicht mehr im iOS-Pfad). Die echte Engine loggt sauber über Streams. Einzig `global.log` (append, unbegrenzt) sollte begrenzt werden.
- **Config:** Die echte iOS-Engine nutzt rclones professionelles `config/create` (verschlüsselt). Die „unprofessionelle" manuelle Config gehört ebenfalls zum toten `MobileRcloneService`.
- **Zwei Geräte gleichzeitig:** `bisync` ist dafür **nicht** ausgelegt (lokale States/Locks pro Gerät). iCloud löst es über einen **zentralen Server-Katalog mit Tombstones/Change-Tokens** — ein anderes, serverseitiges Architektur-Paradigma, das rclone so nicht bietet.
