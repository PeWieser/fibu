# Fibu — Ablauf-Audit: Mirror-Sync & Multi-Gerät (theoretischer Testdurchlauf)

**Datum:** 2026-08-17
**Rolle:** Auditor / Test-User
**Methode:** Statischer Durchlauf des beschriebenen Szenarios gegen den tatsächlichen Code.
**Bewertung:** 🟥 funktioniert nicht · 🟧 eingeschränkt/gefährlich · ✅ funktioniert.

---

## Beschriebenes Szenario

1. Onboarding überspringen.
2. Ein Cloud-Laufwerk einrichten.
3. **Mirror-Task** für „alle Fotos" anlegen.
4. Remote wird gelöscht → Änderungen sollen **lokal** übernommen werden; und vice versa.
5. App neu aufsetzen, dasselbe Remote + Task wiederherstellen.
6. **Zweites Gerät** hinzufügen, das ebenfalls im Mirror-Modus auf dasselbe Remote synchronisiert („wie zwei Geräte mit iCloud Photos").

---

## Zentrale Architektur-Frage: Was macht der „Mirror/Echo"-Modus wirklich?

**Code:** `lib/core/services/ios_rclone_service.dart` (`_runJob`)

```dart
final method = options.isEchoMode ? 'sync/sync' : 'sync/copy';
final startRes = await _rc.rpc(method, {
  'srcFs': srcFs,                 // lokal (bei Fotos: transienter Staging-Ordner)
  'dstFs': '$remoteName:$remotePath',  // remote
  ...
});
```

### 🟥 rclone `sync` ist EINSEITIG — kein 2-Wege-Sync
`rclone sync src dst` macht die Ziele **gleich dem Quellverzeichnis**: Es kopiert von `src → dst` **und löscht in `dst`, was nicht in `src` liegt**. Es lädt aber **nie** von `dst → src` herunter.

Daraus folgt für den Mirror-Modus (lokale Mediathek → Cloud):
- ✅ **Lokal gelöscht → wird in der Cloud gelöscht** (Datei fehlt im Staging → `sync` entfernt sie remote).
- ❌ **Remote gelöscht → wird NICHT lokal gelöscht** (rclone lädt nichts herunter; eine remote-Löschung wird lokal nie übernommen).
- ❌ **Remote hinzugefügt/geändert → wird NICHT lokal übernommen** (kein Download).

→ **Punkt 4 des Szenarios („remote löschen → lokal übernehmen") ist mit der aktuellen Engine nicht erfüllt.** Es ist nur eine einseitige Spiegelung lokal→remote mit Lösch-Propagation in **eine** Richtung.

### 🟥 Media-Staging ist transient → kein echter lokaler Spiegel
**Code:** `_stageMediaLibrary`

Das Staging (`fibu_media_staging`) wird bei **jedem** Sync gelöscht und aus PhotoKit neu aufgebaut. Die „lokale Quelle" ist also nur ein flüchtiger Export, kein dauerhafter lokaler Ordner, der mit der Cloud „gespiegelt" würde.
- Das funktioniert für reines Hochladen (lokal→remote).
- Für echte 2-Wege-Spiegelung bräuchte es einen persistenten lokalen Katalog **und** eine Download-/Lösch-Propagation von remote — beides fehlt.

---

## Schritt-für-Schritt-Bewertung

| # | Schritt | Ergebnis | Begründung |
|---|---|---|---|
| 1 | Onboarding überspringen | ✅ | „Später einrichten" → `completeOnboarding()` → Shell. |
| 2 | Cloud-Laufwerk einrichten | ✅ | Add-Remote-Wizard + OAuth (rclone-Standard-Credentials). |
| 3 | Mirror-Task „alle Fotos" | ✅ (lokal→remote) | Wizard → Reiter „Fotos & Videos" → alle Alben → `all`; `syncMode=mirror`. |
| 4a | **Remote gelöscht → lokal übernehmen** | 🟥 **NEIN** | `sync` ist einseitig; kein Download/Löschen lokal. |
| 4b | **Lokal gelöscht → remote übernehmen** | ✅ | Datei fehlt im Staging → `sync` löscht sie remote. |
| 5 | App neu aufsetzen, gleiches Remote+Task | 🟧 **eingeschränkt** | Remote kann neu verbunden werden, aber siehe „Neuaufsetzen". |
| 6 | Zweites Gerät, Mirror auf dasselbe Remote | 🟥 **Datenverlust-Risiko** | Siehe „Zwei Geräte". |

---

## Detail: Neuaufsetzen (Schritt 5)

- `listRemotes`/`addRemote` sind über rclone-Config persistent → das **Remote selbst** kann wieder verbunden werden (OAuth erneut).
- **Aber:** Tasks liegen nur in `tasks.json` (lokal). Beim Neuaufsetzen muss die Task manuell neu angelegt werden.
- Es gibt einen Import-Pfad über `.fibu/config.json` auf dem Remote (`readRemoteConfig`/`checkRemoteForConfig`), **aber `writeRemoteConfig` wird nirgends aufgerufen** — die Konfiguration wird also nie aufs Remote geschrieben. Der Import-Dialog kann daher nie greifen.
- Zusätzlich wird das Fibu-Manifest (`.fibu/manifest.json`, `SyncManifestService`) **nur im alten `MobileRcloneService`** geschrieben, **nicht** in der echten `IosRcloneService`-Engine → auch kein Katalog, aus dem eine Task rekonstruiert würde.

→ **Automatische Wiederherstellung der Task beim Neuaufsetzen funktioniert nicht.** Alles muss manuell neu eingerichtet werden.

---

## Detail: Zwei Geräte auf dasselbe Remote (Schritt 6) — 🟥 Datenverlust

Zwei Geräte A und B führen beide `rclone sync <lokal> <remote>` aus. Da `sync` remote **gleich dem lokalen Staging** macht, gilt:

- Gerät A hat Foto X, Gerät B nicht.
- A synct → X ist in der Cloud.
- **B synct → B's Staging enthält X nicht → `sync` LÖSCHT X in der Cloud.**
- A synct wieder → lädt X wieder hoch … unendlicher Ping-Pong, potenziell Verlust.

Das ist **das Gegenteil** von iCloud Photos (dort echte bidirektionale Synchronisation mit zentralem Katalog + Konflikt-Management, Löschungen werden zwischen Geräten propagiert, nicht gegeneinander).

**Ursache:** Der Mirror-Modus ist ein einseitiger, zerstörerischer Mirror aufs Zielverzeichnis — er ist **nicht** dafür ausgelegt, dass mehrere Geräte dasselbe Ziel teilen.

---

## Zusammenfassung der Befunde

| Befund | Schwere | Datei |
|---|---|---|
| Mirror = einseitiges `sync` (kein remote→lokal) | 🟥 | `ios_rclone_service.dart` |
| Media-Staging transient (kein echter Spiegel) | 🟥 | `ios_rclone_service.dart` |
| Zwei Geräte auf dasselbe Remote → Lösch-Ping-Pong/Datenverlust | 🟥 | `ios_rclone_service.dart` |
| `.fibu/config.json` wird nie geschrieben → kein Auto-Import beim Neuaufsetzen | 🟧 | `sync_config_service.dart` |
| Manifest nur in alter `MobileRcloneService`-Engine | 🟧 | `ios_rclone_service.dart` vs `mobile_rclone_service.dart` |

---

## Empfehlungen (für einen echten „iCloud-Photos"-artigen 2-Wege-Sync)

Für das gewünschte Verhalten wäre ein **echter bidirektionaler Sync** nötig, nicht `rclone sync`:

1. **Persistenter lokaler Mediathek-Spiegel** (nicht transient): exportierte Fotos + ein lokaler Katalog mit Checksummen (`SyncManifestService` in der echten Engine verwenden).
2. **Download-/Lösch-Propagation remote→lokal** (neben dem Upload): `rclone copy remote lokal` + Vergleich der Manifeste, um remote-Löschungen auch lokal zu löschen.
3. **Konflikt-/Lösch-Management für mehrere Geräte**: z. B. Lösch-Tombstones, „last writer wins", oder ein zentrales Manifest je Gerät. Ohne das ist „2 Geräte auf 1 Remote" destruktiv.
4. **`writeRemoteConfig` tatsächlich aufrufen** (z. B. nach Task-Erstellung), damit `.fibu/config.json` geschrieben wird und das Neuaufsetzen-Import greift.

> Hinweis: Echte bidirektionale Multi-Geräte-Sync ist ein größeres Architekturthema (deutlich über „rclone sync" hinaus). Falls das Szenario 1:1 wie iCloud Photos umgesetzt werden soll, sollte das als eigenständiges Feature geplant werden.

---

## Fazit

- **Einseitige Sicherung lokal→remote (Upload + lokale Lösch-Propagation): funktioniert.**
- **Remote→lokal (Download + remote-Lösch-Propagation): funktioniert nicht** (Punkt 4a des Szenarios).
- **Neuaufsetzen mit Auto-Restore: funktioniert nicht automatisch** (Config wird nie geschrieben).
- **Zwei Geräte auf dasselbe Remote im Mirror-Modus: gefährlich / Datenverlust-Risiko** (Punkt 6 des Szenarios).

Der aktuelle „Echo/Mirror"-Modus ist kein 2-Wege-Sync und kann das beschriebene iCloud-Photos-Szenario nicht abbilden.
