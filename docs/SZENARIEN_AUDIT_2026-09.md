# Fibu — Szenario-Katalog & Härtetest (September 2026)

Stand: `main` @ `c702ceb`. Dieser Katalog ergänzt die bestehenden Prüfungen
([`STRESSTEST_DAU.md`](STRESSTEST_DAU.md), [`TESTMATRIX_IOS_WINDOWS.md`](TESTMATRIX_IOS_WINDOWS.md))
um eine neue, vollständige Durchsicht: alle realistischen Nutzungs- und
DAU-Szenarien („dümmster anzunehmender User"), inklusive Lebenszyklus
(Installation → Abbruch → Neuinstallation), Plattform-Eigenheiten
(**iOS zuerst, dann Windows, dann Android**) und Mehrgerätebetrieb.

**Methode.** Jeder Befund ist gegen den echten Code geprüft und mit
`Datei:Zeile` belegt. In dieser Umgebung gibt es kein Flutter-SDK und keine
Geräte/Simulatoren — Verifikation ist daher Code-Tracing plus die vorhandenen
Unit-/Widget-Tests; Laufzeitverhalten (v. a. iOS-Hintergrundtask) ist, wo
nötig, als „Gerätetest nötig" markiert.

Legende:

| Zeichen | Bedeutung |
|---|---|
| ✅ | Hält stand — Schutz im Code nachweisbar |
| ⚠️ | Hält eingeschränkt stand — reales Restrisiko oder irritierendes Verhalten |
| ❌ | Hält nicht stand — reproduzierbarer Fehler, möglicher Datenverlust oder tote Funktion |
| 🔒 | Wird von einer Sicherheitsbremse abgefangen |

---

## 0. Zusammenfassung

| Klasse | Anzahl |
|---|---|
| Geprüfte Szenarien | 114 |
| ✅ hält stand | 66 |
| 🔒 von Sicherheitsbremse abgefangen | 3 |
| ⚠️ eingeschränkt | 37 |
| ❌ hält nicht stand | 8 Zeilen, 6 Ursachen |

**Die sechs ❌-Ursachen (neu in dieser Runde):**

| # | Befund | Plattform | Abschnitt |
|---|---|---|---|
| N1 | Geplante Läufe verbuchen „Erfolg" und geben die Cloud-Sperre frei, **bevor** der Sync überhaupt gelaufen ist (`startBackupJob` wird nicht erwartet) | alle | H1 |
| N2 | Der 2-h-iOS-Hintergrundlauf beendet den Workmanager-Callback sofort nach Job-*Start*; der laufende Sync wird mit dem Hintergrund-Isolat sehr wahrscheinlich abgeräumt, aber als Erfolg gebucht | iOS | H2 |
| N3 | Der Planer berechnet einen **anderen Cloud-Pfad** als der manuelle Lauf (Root-Modus `/` vs. `''`, Mehrziel-Aufgaben, Alt-Formate) → zwei getrennte Mirror-Zustände, zwei getrennte Sperren für denselben Ordner | alle | H3 |
| N4 | `createRcloneServiceForPlatform()` liefert je Aufruf eine **neue Instanz**; die `isSyncRunning`-Wächter des Planers laufen daher immer ins Leere | alle | H4 |
| N5 | Windows: `isSyncRunning` ist hartkodiert `false` → geplante und manuelle Mirror-Läufe können **parallel** auf demselben Zustand laufen | Windows | M-W4 |
| N6 | Android: keine native `fibu/rclone`-Brücke vorhanden (MainActivity ist leer) → jeder rclone-Aufruf wirft `MissingPluginException`; die App ist auf Android faktisch funktionsunfähig, obwohl das README Android bewirbt | Android | M-A1 |

Alle Datenverlust-Pfade, die in früheren Runden offen waren
(Lösch-Wellen, Smart-Alben, Windows-`rclone sync`), bleiben behoben — die
Sicherheitsbremsen sind unverändert wirksam (Abschnitte D/E). Die neuen
Risiken liegen fast alle im **Planer/Hintergrund** und in der
**Neuinstallation** — also genau dort, wo der Nutzer nichts sieht.

**Update gleiche Runde:** Die ❌-Ursachen N1–N5 und die sinnvollen ⚠️-Befunde
wurden direkt behoben — Zuordnung und Umsetzung in Abschnitt O. Ein
dedizierter Zweitdurchgang des iOS-Spiegelmodus (Abschnitt P) fand zwei
weitere Lücken: M-I1 (falscher „gesynct"-Nachweis → falsche Löschvorschläge,
❌) und M-I2 (Replace löscht lokale Fassung vor dem Download) — beide
ebenfalls behoben. Die Bewertung der Tabelle oben beschreibt den
**Audit-Zustand vor den Fixes**.

---

## 1. Das Referenz-Szenario (vom Auftraggeber)

> „User richtet Backup ein, startet es, bricht ab, installiert die App neu,
> richtet Backup und Cloud erneut ein. Was passiert?"

### 1.1 Was beim Abbruch liegen bleibt

1. **Abbrechen** setzt das Abbruch-Signal (`ios_rclone_service.dart:1040–1052`)
   und meldet sofort „Abgebrochen". Die Engines prüfen das Signal zwischen
   den Dateien (`virtual_mirror_sync.dart:537,648,893`); die **aktuelle
   Einzeldatei wird immer noch fertig übertragen**, erst danach stoppt der
   Lauf. Ein laufender Einzel-Transfer ist nicht killbar — bei einem 4-GB-Video
   kann „Abbrechen" also Minuten dauern, bis der Zustand wirklich steht. ⚠️
2. Auch ein abgebrochener Lauf läuft bis in **Phase 5** durch
   (`virtual_mirror_sync.dart:977–1010`): Tombstones und Mirror-Zustand werden
   persistiert, allerdings nur mit den bis dahin *nachweislich* gesyncten
   Pfaden (`uploadedRels` + remote vorhandene). Fehlschläge bleiben draußen.
3. Die **Cloud-Sperre** `.fibu/lock.json` wird vom Dashboard im `finally`
   freigegeben (`dashboard_controller.dart:545–547`) — auch bei Abbruch.
   Wird die App stattdessen hart beendet (Swipe-away), bleibt die Sperre bis
   zum Verfall nach 5 min liegen (`sync_lock_service.dart:34–36`).
4. Auf dem Remote liegen nun: die bisher hochgeladenen Dateien,
   `.fibu/config.json` (Aufgaben-Konfiguration, beim Anlegen der Aufgabe
   geschrieben — `tasks_screen.dart:1354–1367`), ggf. `.fibu/lock.json`,
   `.fibu/tombstones.json` und das Journal. **Nichts davon geht durch die
   Neuinstallation verloren — es gehört der Cloud, nicht der App.**

### 1.2 Was die Deinstallation auf iOS löscht

| Ort | Inhalt | Weg? |
|---|---|---|
| `Library/Application Support` | `rclone.conf` (Zugangsdaten!), `remotes.json`, `tasks.json`, `device.json` (Gerätekennung), `fibu_state/` (Mirror-Zustand, Journal, `library_index.json`), `pending_deletions.json`, `fibu.log`, Thumb-Cache | **ja, komplett** |
| Keychain (`AfterFirstUnlockThisDeviceOnly`) | OAuth-Tokens (`fibu_oauth_token_*`, `oauth_service.dart:78`) | **nein** — Keychain-Einträge überleben auf iOS die Deinstallation (Systemverhalten). Nach der Neueinrichtung sind das verwaiste Einträge: neue Remotes bekommen neue IDs (`fibu-<hex>`), kein Remote referenziert die alten Tokens mehr. Funktional harmlos, datenschutztechnisch ein „lagert länger als nötig"-Hinweis. ⚠️ (N-F8) |
| Fotos-Mediathek | bleibt natürlich unangetastet | — |

### 1.3 Neueinrichtung — was der Nutzer sieht und was passiert

1. **Laufwerk neu verbinden.** Die Zugangsdaten waren in `rclone.conf` und
   sind weg → vollständige Neu-Anmeldung (OAuth/Passwort) nötig. Der Wizard
   verlangt einen echten Sign-in, bevor das Laufwerk gespeichert wird
   (`README` §7; `ios_rclone_service.dart:160–182`).
2. **Aufgabe wird angeboten.** Beim ersten Blick auf das Laufwerk findet die
   App `.fibu/config.json` mit der alten Aufgabe inkl. `selectedAlbums`
   (`sync_config_service.dart:62–78`) und bietet den Import an. **Das ist der
   wichtige saubere Pfad**: Die Album-Auswahl kommt exakt zurück, und damit
   auch dieselben Spiegel-Pfade (`Photos/<Album>/<Datei>`).
3. **Erster Sync nach Neueinrichtung** (mit importierter oder identisch
   nachgebauter Aufgabe):
   - Neuer `deviceId` (`device.json` war weg → `device_identity_service.dart:28–50`).
     Eine ggf. noch liegende **alte Sperre** trägt die alte Kennung und ist
     erst nach 5 min Übernahme-fällig. Wer innerhalb von 5 Minuten nach einem
     harten Abbruch neu einrichtet und sofort synct, bekommt
     „Gesperrt durch <eigener Gerätename>" und wartet bis zu 5 min. ⚠️ (N-F6)
     (`sync_lock_service.dart:34–36,78–90`)
   - Mirror-Zustand leer → `previouslySyncedRels` leer → **keine
     Lösch-Kandidaten**, es kann nichts als „lokal gelöscht" interpretiert
     werden. Nichts in der Cloud wird angefasst. ✅
   - Cloud-only-Dateien: Für jedes lokale Asset mit identischem Namen
     existiert der lokale Scan-Eintrag unter demselben `rel` (gleiche Alben
     ⇒ gleiche Pfade) → `localItems.containsKey(rel)` → kein Download
     (`virtual_mirror_sync.dart:806`). Zusätzlich schützt der
     Basisnamen-Index. Ergebnis: **kein Re-Download, keine Duplikate.** ✅
   - Hochgeladen wird nur, was seit dem Abbruch neu dazukam. Der Lauf endet
     im Normalfall mit „Aktualisiert". ✅
4. **DAU-Variante ohne Task-Import**, mit *anderer* Album-Auswahl
   (z. B. nur „Camera Roll" statt alles): Jetzt fehlen für alle anderen Alben
   die lokalen Gegenstücke — und der geräteweite Namens-Index
   (`library_index.json`, `ios_rclone_service.dart:1369–1398`) wurde mit
   deinstalliert. Die Engine lädt die
   Cloud-Dateien dieser Alben **komplett in die Mediathek zurück**
   (`virtual_mirror_sync.dart:767–950`). Die Fotos sind dort zwar schon, aber
   der Import erzeugt Duplikate; der nächste Lauf lädt die Duplikate unter
   Konflikt-Namen (`…_asset<id>…`) wieder hoch → Cloud-Blähung über mehrere
   Zyklen. Kein Datenverlust, aber ein echtes DAU-Loch. ⚠️ (N-F7)
   **Gegenmittel existiert:** Task-Import aus `.fibu/config.json` (Punkt 2)
   oder „alle Alben" wählen.
5. **Tombstones überleben** in der Cloud (`.fibu/tombstones.json`): Dateien,
   die der Nutzer vor der Deinstallation lokal gelöscht hatte, werden auch
   nach Neueinrichtung nicht wieder hochgeladen oder zurückgeholt
   (`virtual_mirror_sync.dart:692–705`). ✅

**Gesamtfazit Referenz-Szenario:** kein Datenverlust in keiner Variante; der
saubere Weg führt über den Aufgaben-Import aus der Cloud. Die zwei
Stolpersteine sind die 5-Minuten-Sperre (kosmetisch) und die
Re-Download-Falle bei abweichender Album-Auswahl (⚠️ N-F7).

---

## A. Ersteinrichtung & Leerzustände

| # | Szenario (DAU-fett) | Ergebnis | Beleg |
|---|---|---|---|
| A1 | Frische Installation, nichts eingerichtet | ✅ | Gestaffelte Anleitung: nur „Laufwerk hinzufügen" (`dashboard_screen.dart:80–105`) |
| A2 | Laufwerk verbunden, keine Sicherung | ✅ | Nur „Sicherung einrichten" |
| A3 | **App starten und sofort „Sync" drücken, obwohl noch nichts eingerichtet ist** | ✅ | `noActiveTasksError` bzw. Netz-Vorprüfung (`dashboard_controller.dart:560–590`) |
| A4 | Laufwerk-Anmeldung mittendrin abbrechen (OAuth-Fenster zu) | ✅ | Kein halb verbundenes Laufwerk; Token wird geparkt und beim Löschen gezielt geräumt (`STRESSTEST_DAU` B3, unverändert) |
| A5 | **Zweites Laufwerk mit gleichem Anzeigenamen anlegen** | ✅ | Auflösung über die Registry-Kennung, nicht den Namen (`remote_registry_service.dart`) |
| A6 | Wizard: Passwort mit Leerzeichen vorn/hinten eingetippt | ⚠️ | Eingaben werden nicht getrimmt/validiert außer im Verbindungs-Test — der Test scheitert mit dem echten Provider-Fehler, gespeichert wird erst nach Erfolg. Akzeptabel, aber kein Hinweis „Leerzeichen entfernt?" |
| A7 | Crypt-Laufwerk, Passwort später vergessen | ⚠️ | Kein Wiederherstellungsweg (systembedingt, E2EE); Fehlermeldung beim Entsperren ist der echte rclone-Fehler |

## B. Sync starten, steuern, abbrechen

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| B1 | **„Sync" 5× schnell hintereinander antippen** | ✅ | Doppel-Guard: UI-Status (`dashboard_controller.dart:560–562,628–630`) + Dienst-Mutex `_runningJobIds` (`ios_rclone_service.dart:603–609`) |
| B2 | Abbrechen während Upload/Download/Löschphase | ✅ | Signal wird zwischen Dateien geprüft, alle drei Phasen brechen ab (`virtual_mirror_sync.dart:537,648,893`) |
| B3 | Abbrechen, dann **sofort** erneut „Sync" | ⚠️ | Die aktuelle Einzeldatei läuft noch zu Ende; bis dahin blockiert `_runningJobIds` den Neustart mit „läuft bereits" (`ios_rclone_service.dart:603–609`). Korrekt, aber nach „Abgebrochen" irritierend (N-F11) |
| B4 | **„Abbrechen" 10× hämmern** | ✅ | `cancelBackupJob` ist idempotent (Mengen-Add + `job/stop` in `try/catch`) |
| B5 | App während des Syncs in den Hintergrund; iOS beendet sie (Speicherdruck) | ✅ | Zustand wird erst nachweislich-basiert geschrieben (Phase 5); `_runningJobIds` ist flüchtig → keine Blockade; nächster Lauf gleicht gegen die Cloud-Liste neu ab |
| B6 | **Gerät mitten im Sync ausschalten** | ⚠️ | Wie B5, kein Zustandsverlust; halbe Uploads: rclone lädt beim nächsten Lauf erneut (Größe/Zeit-Vergleich). Auf S3-artigen Backends kann ein unvollständiges Multipart-Fragment Speicher belegen, bis eine Lifecycle-Regel aufräumt — providerseitig, nicht Fibu-seitig |
| B7 | Offline auf „Sync" drücken | ✅ | `_networkBlockReason` (`dashboard_controller.dart:249–256`) |
| B8 | „Nur WLAN" an, mobiles Netz aktiv | ✅ | `cellularSyncBlockedNotice` |
| B9 | **WLAN bricht mitten im Sync weg (Tunnel, Fahrstuhl)** | ✅ | rclone-Fehler wird gefangen, freundliche Meldung (`_friendlySyncError`, `dashboard_controller.dart:208–245`), kein Hänger dank Fast-Fail-Timeouts (`ios_rclone_service.dart:44–63`) |
| B10 | **Wi-Fi → Mobilfunk-Wechsel mitten im Sync bei WLAN-only** | ⚠️ | Die WLAN-Regel wird nur *vor* dem Lauf geprüft (`dashboard_controller.dart:354–366`); der laufende Transfer nutzt das neue Netz zu Ende. Bewusst einfach gehalten |
| B11 | Eingehender Anruf während des Syncs (iOS) | ✅ | App geht in den Hintergrund; der Lauf läuft im Vordergrund-Zeitfenster weiter bzw. wird vom System beendet → B5 greift |
| B12 | Low-Power-Modus | ✅ | Auto-Refresh halbiert den Takt (`auto_refresh_service.dart:58–71`); BG-Task wird von iOS ohnehin seltener geweckt (systembedingt) |

## C. Mehrgeräte & Kopplung

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| C1 | Zwei Geräte spiegeln **gleichzeitig** in denselben Ordner | ✅ | Cloud-Sperre mit Herzschlag; zweites Gerät überspringt mit Namensmeldung (`sync_lock_service.dart`, `dashboard_controller.dart:390–406`) |
| C2 | App stürzt während des Syncs ab → Sperre bleibt | ✅ | Verfall nach 5 min, Übernahme wird geloggt (`sync_lock_service.dart:34–36,78–90`) |
| C3 | **Neuinstallation und sofortiger Sync < 5 min nach hartem Ende** | ⚠️ | Neue Gerätekennung, aber fremder (eigener alter) Herzschlag noch frisch → bis zu 5 min „Gesperrt durch <Gerätename>" (N-F6) |
| C4 | Zwei Geräte ändern dieselbe Datei | ✅ | 3-Way-Abgleich; Konflikt wird als Zeitstempel-Kopie behalten (`virtual_mirror_sync.dart:255–283`) |
| C5 | Zwei Geräte mit gleichnamigen Dateien (`IMG_0001.HEIC`) | ✅ | Name **und** Größe trennen (`virtual_mirror_sync.dart:606–628`) |
| C6 | **Kopplung: Bundle auf dem Empfangsgerät übernehmen, das schon eine eigene Sicherung hat** | ⚠️ | `tasks.json` wird **überschrieben**, nicht gemischt (`device_pairing_screen.dart:226–228`). Bestätigungsdialog nennt Anzahl Laufwerke/Aufgaben, aber nicht, dass die eigene Sicherung ersetzt wird. Im „eine Sicherung"-Modell konsequent, trotzdem überraschend |
| C7 | Kopplung über Gäste-WLAN mit Client-Isolation / aktives VPN | ⚠️ | UDP-Beacon kommt nicht durch → „Kein wartendes Gerät gefunden" (`pairingNoneFound`); kein irreführender Fehler, aber keine Ursachen-Hinweise (VPN/AP-Isolation) |
| C8 | **Fremdes Gerät im selben Netz schickt ein manipuliertes Bundle** | ✅ | AES-256-GCM mit Sitzungsschlüssel; Übernahme erst nach menschlicher Bestätigung (`device_pairing_service.dart` Kopf-Kommentar, `_confirmBox`) |
| C9 | Kopplung zweimal direkt hintereinander | ✅ | Server schließt nach dem ersten Bundle (`stopReceiver`) |
| C10 | Alte App-Version funkt Beacon v1 | ✅ | Wird beim Finden übersprungen (`TESTMATRIX` D12) |
| C11 | Gerätekennung wird mitkoppliert → doppelte Identität? | ✅ | `device.json` ist **nicht** Teil des Bundles (`PairingBundle`-Felder: nur rclone.conf/remotes/tasks/settings) → jedes Gerät behält seine Kennung |
| C12 | Zwei Geräte schreiben `.fibu/config.json` | ✅ | Zusammenführung über `deviceId` je Aufgabe (`sync_config_service.dart:98–106`) |

## D. Ereignisse auf der Cloud-Seite

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| D1 | Datei in der Cloud-WebUI löschen, dann syncen | ✅ | Erkennung über `previouslySyncedRels`; iOS-Systemdialog (gebündelt, ein Dialog pro Lauf); Ablehnung wird dauerhaft gemerkt (`virtual_mirror_sync.dart:706–764`) |
| D2 | **Kompletten Cloud-Ordner in der WebUI löschen (Massenlöschung)** | 🔒 | Anomalie-Bremse: >20 % **oder** >25 Dateien **oder** leere Liste → nichts wird lokal gelöscht, Lauf meldet (`virtual_mirror_sync.dart:715–746`) |
| D3 | Provider-Ausfall: leere/unvollständige Liste | 🔒 | `remoteFiles.isEmpty` gilt als Ausfall → keine Löschungen (`virtual_mirror_sync.dart:728–735`); Listen-Fehler bleiben laut (`_listRemoteRecursive`, `virtual_mirror_sync.dart:1077–1083`) |
| D4 | Datei in der Cloud umbenennen | ✅ | Rename-Erkennung über Größe+Zeit, serverseitiges `movefile`; Provider ohne Server-Move fallen auf Upload zurück (`virtual_mirror_sync.dart:410–465`) |
| D5 | **Jemand lädt Müll in den Zielordner (oder ein geteiltes Konto wird kompromittiert)** | ⚠️ | Echo lädt Cloud-only-Dateien in die Mediathek (by design, 2-Wege). Vorab-Speichercheck schützt vor vollem Gerät (`virtual_mirror_sync.dart:866–882`), aber nicht vor unerwünschtem Inhalt. Kein Inhaltsfilter — inhärent bei 2-Wege-Spiegelung |
| D6 | Zielordner in der Cloud **umbenennen/verschieben** | ⚠️ | Kein Datenverlust: Pfad nicht mehr auffindbar → „Verzeichnis existiert nicht" → leere Cloud-Seite; Lösch-Erkennung findet keine Kandidaten (nichts war „nachweislich gesynct" unter dem neuen Pfad) **und** die Leerlisten-Bremse greift zusätzlich. Der Bestand wird unter dem neuen Pfad neu aufgebaut; der alte Bestand im verschobenen Ordner wird zu Waisen (Duplikate beim Neuaufbau) |
| D7 | Cloud-Quota läuft mitten im Lauf voll | ✅ | Einzel-Uploads scheitern mit Provider-Fehler und werden nächstes Mal erneut versucht; bereits Vorab-Quota-Check bei bekannter Quota (`virtual_mirror_sync.dart:512–532`) |
| D8 | Provider drosselt (429/rate limit) | ✅ | rclone-internes Backoff; Fehler kommen als klare Meldung hoch, kein Endlos-Hang (Fast-Fail nur bei Listen/About, Transfers ohne Global-Timeout) |
| D9 | Passwort des Cloud-Kontos extern geändert | ✅ | Nächster Lauf scheitert mit Auth-Fehler (`_friendlySyncError` erkennt 401/403/token, `dashboard_controller.dart:224–230`); Wizard-Neuanmeldung nötig |
| D10 | Laufwerk in der Cloud-WebUI komplett löschen | ✅ | Sync scheitert laut mit echtem Provider-Fehler; Vorprüfung gegen Registry bei gelöschtem *App*-Laufwerk (`remoteMissingInTask`) |
| D11 | Zwei Fibu-Installationen, dieselbe Anmeldung, aber Aufgabe zeigt auf **verschiedene** Zielordner | ✅ | Unabhängige Scopes, keine Berührung |

## E. Ereignisse auf dem Gerät (iOS-Mediathek)

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| E1 | Foto lokal löschen → syncen | ✅ | `_confirmDeletions` prüft je Asset per `AssetEntity.fromId`, dann Tombstone → Cloud-Löschung in den Remote-Papierkorb (`.fibu-trash`, 30 Tage) (`ios_rclone_service.dart:1447–1495`, `trash_service.dart:78–119`) |
| E2 | Foto lokal löschen, dann aus „Zuletzt gelöscht" **wiederherstellen** | ✅ | Asset existiert wieder (`fromId` ≠ null) → keine Löschung; Datei kommt beim nächsten Lauf hoch, solange kein Tombstone existiert. War das Tombstone schon ausgeführt, bleibt die Cloud-Kopie im Remote-Papierkorb wiederherstellbar |
| E3 | Foto in der Fotos-App bearbeiten (Crop/Filter) | ✅ | Export-Größe ändert sich → `contentCmp` erkennt, Upload ersetzt (`virtual_mirror_sync.dart:288–330`) |
| E4 | **Album umbenennen** | ✅ | Rename-Erkennung, serverseitiger Umzug statt Neu-Upload (D4) |
| E5 | **Album löschen, Fotos bleiben in der Mediathek** | ✅ | Fotos tauchen im „Alle Fotos"-Scan weiterhin auf; ohne Album-Aufgabe unverändert. Bei Album-gebundener Aufgabe: `fromId`-Schutz verhindert Lösch-Propagation (Smart-Album-Logik) |
| E6 | Smart-Album („Favoriten", „Zuletzt hinzugefügt") als Quelle | ✅ | Asset-Existenzprüfung statt Album-Diff — Altern/Ent-Favorisieren erzeugt keine Tombstones (`STRESSTEST_DAU` D3/D4, unverändert gültig) |
| E7 | Fotozugriff „Auswahl …" (iOS 14+ limited) | ✅ | Lösch-Erkennung komplett übersprungen, geloggt (`ios_rclone_service.dart:1454–1461`) |
| E8 | Auswahl später auf „Alle Fotos" erweitert | ✅ | Scan sieht alles, keine Fehl-Löschungen |
| E9 | **Fotozugriff komplett entziehen und syncen** | ✅ | Klare Meldung `errPhotoPermission`, kein Crash (`ios_rclone_service.dart:1733–1737`) |
| E10 | iCloud-Fotos „Speicher optimieren" (Assets ausgelagert) | ✅ | `asset.file` löst den iCloud-Download aus; schlägt er ab, wird die Datei nächstes Mal erneut versucht |
| E11 | **iCloud-Fotos komplett deaktivieren** → Bibliothek schrumpft schlagartig | 🔒 | Massen-„Verschwinden": `_confirmDeletions` bestätigt die Assets zwar als echt weg, aber die >50 %-Bremse im iOS-Pfad (`ios_rclone_service.dart:1949–1953`) **und** die Engine-Bremse (`virtual_mirror_sync.dart:195–205`) stoppen die Tombstone-Welle. Der Lauf meldet die Anomalie. Datenverlust ausgeschlossen, Nutzer muss bewusst in kleinen Schichten löschen |
| E12 | Live Photo / RAW-Paar (DNG+HEIC) | ⚠️ | Es wird ein Asset exportiert; die Paar-Hälfte kann je Exportpfad fehlen (`STRESSTEST_DAU` I3 — unverändert, Gerätetest nötig) |
| E13 | Verstecktes Album | ⚠️ | Erscheint je iOS-Version im Picker; Verhalten backend-abhängig (I5) |
| E14 | **Datum/Uhrzeit des Geräts während des Syncs verstellen** | ⚠️ | `contentCmp` nutzt Modtimes mit 60 s Toleranz (`virtual_mirror_sync.dart:305–330`); Konflikt-Zeitstempel-Namen nutzen die Ortszeit. Keine Datenverlust-Pfade, aber mögliche Fehl-Einordnung „lokal neuer" bei großer Uhr-Verstellung |
| E15 | 30 000+ Fotos | ⚠️ | 100er-Batches mit Fortschritt; Zustandsspeicher wächst linear, kein hartes Limit (`STRESSTEST_DAU` I7) |
| E16 | Zwei Alben mit identischem Namen / Dateinamen-Kollisionen | ✅ | `taken`-Menge global pro Lauf (`ios_rclone_service.dart:1797–1800`), Deterministik über Asset-ID |
| E17 | Asset ohne Titel (iOS liefert null) | ✅ | Fallback-Name aus Asset-ID + MIME-Extension (`ios_rclone_service.dart:2210–2234`) |

## F. Dateien-App / Ordner-Quellen

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| F1 | Ordner aus der Dateien-App als Quelle, dann Ordner dort löschen | ⚠️ | iOS: `files:`-Quellen werden in **transientes** Staging kopiert (`ios_rclone_service.dart:1132–1148`); zwischen Läufen sind Tombstone/Snapshot weg → Lösch-Propagation funktioniert für Dateien-Quellen nicht zuverlässig (N-F9). Kein Datenverlust (es wird nichts Falsches gelöscht), aber Echo-Anspruch wird nicht eingelöst |
| F2 | iCloud-Drive-Ordner als Quelle (Dateien z. T. nur in der Cloud) | ⚠️ | Nicht lokal materialisierte Dateien sind für den Kopiervorgang nicht lesbar → werden still übersprungen (`_copyTree` `catch`); kein Absturz, aber stille Lücke |
| F3 | USB-Laufwerk an iPad, Aufgabe zeigt darauf, Laufwerk abgezogen | ✅ (iOS) / ✅ (Win) | Quelle existiert nicht → leerer Scan; iOS: Dateien-Quelle ohne Inhalt, kein Crash. Windows: siehe M-W2 (Kleinstbibliotheks-Risiko) |
| F4 | Sehr tiefe Pfade / 255-Zeichen-Dateinamen | ⚠️ | Keine explizite Längenprüfung; Provider-Limits schlagen als rclone-Fehler durch (lesbar), kein Datenverlust |
| F5 | Album-/Ordnernamen mit Emoji, Umlauten, `con`, `…`, führenden Punkten | ⚠️ | Nur `/ \ :` werden ersetzt (`ios_rclone_service.dart:1805`); alles andere wandert roh in den Cloud-Pfad. Problematisch v. a. beim Browsen des Cloud-Ordners **von Windows** (`CON`, `*?<>|"` sind dort reserviert/ungültig — rclone maskiert je Backend). Bekannt aus `STRESSTEST_DAU` D10/J6, bewusst unverändert (Pfad-Stabilität) |

## G. Windows-spezifisch (Ordner-Mirror)

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| G1 | Datei im Quellordner löschen → syncen | ✅ | In `.fibu-trash` (30 Tage) statt hartem Löschen; Tombstone propagiert (`filesystem_mirror_source.dart:119–145`) |
| G2 | **Quellordner verschieben/umbenennen** | ⚠️ | `scan()` liefert leer (`filesystem_mirror_source.dart:44–52`). Mit **≥ 10** Dateien greift die Anomalie-Bremse 🔒. Mit **< 10** Dateien entstehen echte Tombstones → die Cloud-Kopien wandern in den Remote-Papierkorb (wiederherstellbar, 30 Tage) statt dass der Lauf abbricht (N-F5). Empfehlung: fehlenden Quellordner hart abfangen |
| G3 | OneDrive-Dateien „Nur online" im Quellordner | ⚠️ | Platzhalter-Dateien haben Größe 0/lesbar-Metadaten; `File.length` meldet 0 → Upload wird übersprungen (`localSize <= 0`, `virtual_mirror_sync.dart:546`). Kein Schaden, aber still übergangen — keine Hydratisierung und kein Hinweis |
| G4 | **fibu.exe während des Syncs über den Taskmanager beenden** | ✅ | Cloud-Sperre verfällt nach 5 min; Zustand bleibt konsistent (nur nachweislich Gesynctes wird persistiert) |
| G5 | Windows in den Ruhezustand mitten im Sync | ✅ | Wie B5/B6: Prozess stirbt/stockt, nächster Lauf gleicht ab |
| G6 | `.fibu-trash` füllt die Festplatte | ⚠️ | 30-Tage-Purge nur beim nächsten erfolgreichen Mirror-Lauf (`filesystem_mirror_source.dart:148–169`); wer nie synct, sammelt. Kein Größen-Limit |
| G7 | Lange Pfade > 260 Zeichen | ⚠️ | Abhängig von Windows-Long-Path-Einstellung; rclone.exe meldet den Fehler lesbar |
| G8 | Antivirus blockiert rclone.exe | ⚠️ | `Process.start` wirft → Status `failed` mit Fehlermeldung (`rclone_service_impl.dart:266–273`); kein stiller Ausfall |
| G9 | Zwei Windows-Benutzerkonten auf einem Rechner | ✅ | Getrennte `%APPDATA%`-Daten, getrennte Gerätekennungen |

## H. Planer & Hintergrundbetrieb — **Hauptfundort dieser Runde**

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| H1 | Geplanter Lauf startet | ❌ | `_runOneTask` erwartet `startBackupJob` **nicht** (der Job läuft per `unawaited` weiter, `ios_rclone_service.dart:619–622`, `rclone_service_impl.dart:201–204`), verbucht aber sofort `SchedulerRunLog.record(id, success: true)` (`scheduler_service.dart:337`) **und** gibt im `finally` die Cloud-Sperre wieder frei (`scheduler_service.dart:345–348`). Drei Folgen: (a) ein fehlgeschlagener Hintergrund-Sync gilt als Erfolg → `runMissedSyncs` holt ihn nie nach; (b) die Sperre schützt während des Laufs nicht; (c) ein zweites Gerät sieht den Ordner als frei |
| H2 | iOS: 2-h-BGProcessingTask | ❌ | Der Workmanager-Callback kehrt direkt nach `runScheduledSync()` zurück (`scheduler_service.dart:27–41`) → das Hintergrund-Isolat meldet „fertig", während der Sync-Job dort erst gestartet wurde. Der Job läuft ohne await weiter und wird mit dem Isolat-Ende sehr wahrscheinlich beendet (gerätetest-pflichtig). Ergebnis: geplanter iOS-Lauf überträgt vermutlich nichts, gilt aber als Erfolg |
| H3 | Root-Ziel (`/`) + Zeitplan | ❌ | Der Wizard speichert `targetFolderName: '/'` (`tasks_screen.dart:1307–1311`); das Dashboard macht daraus `''` (`dashboard_controller.dart:329–332`), der Planer nutzt den Rohwert `'/'` (`scheduler_service.dart:311`). Folge: **anderer Cloud-Pfad, anderer State-Scope, anderes `.fibu/lock.json`** (`sync_lock_service.dart:42–44`) für denselben Ordner — manueller und geplanter Lauf arbeiten aneinander vorbei. Mehrziel-Aufgaben: der Planer synct nur `remotes.first` (`scheduler_service.dart:255`), das Dashboard alle |
| H4 | Zeitplan + manueller Sync gleichzeitig | ❌ | `createRcloneServiceForPlatform()` liefert je Aufruf eine neue Instanz (`rclone_provider.dart:19–35`); der Planer-Check `engine.isSyncRunning` (`scheduler_service.dart:301–308`) prüft also immer eine frische, leere Instanz. Der geplante Lauf startet parallel zum manuellen; die Cloud-Sperre blockiert dasselbe Gerät nicht (`isMine`, `sync_lock_service.dart:78–86`). Mit H3 (verschiedene Pfade) greift nicht einmal sie |
| H5 | Windows: Timer tickt alle 5 min, Mirror läuft noch | ❌ | `WindowsRcloneService.isSyncRunning` ist hartkodiert `false` (`rclone_service_impl.dart:173`) → der Timer kann den nächsten Lauf in den laufenden starten; beide teilen `mirror_state.json` (N5) |
| H6 | Offline zum geplanten Zeitpunkt | ✅ | Wird als `skipped` gebucht und beim nächsten Start nachgeholt (`scheduler_service.dart:147–178,271–281`) |
| H7 | WLAN-only + Mobilfunk zum Slot | ✅ | Übersprungen, nicht als Erfolg gebucht (`scheduler_service.dart:282–292`) |
| H8 | Verpasste Läufe nach ausgeschaltetem Gerät | ✅ | `runMissedSyncs` beim Start — funktioniert für Läufe, die der Planer *im laufenden Prozess* anstößt; wegen H1/H2 ist die „Erfolg"-Basis dafür allerdings unzuverlässig |
| H9 | iOS: „Hintergrundaktualisierung" in den Systemeinstellungen deaktiviert | ⚠️ | Kein BG-Lauf mehr; nur App-Start/Resume triggert. Kein Hinweis in der App darauf |
| H10 | Geplanter Lauf erkennt Cloud-Löschungen (kein Dialog möglich) | ✅ | Sauber gelöst: `PendingDeletionsStore` + Dashboard-Banner mit Bestätigung (`ios_rclone_service.dart:1998–2009`, `dashboard_screen.dart:757–833`) |

## I. Zustand, Korruption, Migration

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| I1 | `mirror_state.json` korrupt (z. B. Stromausfall beim Schreiben) | ⚠️ | `jsonDecode`-Fehler → leerer Zustand (`ios_rclone_service.dart:1628–1664`); Folgen wie Neuinstallation (Adoption/Neuaufbau statt Lösch-Propagation — sicher, aber still). Kein Atomar-Schreiben (temp+rename) |
| I2 | `tasks.json` korrupt | ✅ | Leere Liste, App startet im Einrichtungszustand (`tasks_controller.dart:274–343`); kein Crash |
| I3 | Gerät knapp voll beim Schreiben des Zustands | ⚠️ | Schreibfehler werden geloggt und geschluckt (`_saveVirtualState`); nächster Lauf baut neu auf — sicher, aber unsichtbar |
| I4 | Upgrade von alter Version mit globalem Zustand | ✅ | Nur `blocked`/`adopted` werden migriert, nie `items` (`_adoptLegacyGuards`, `ios_rclone_service.dart:1598–1626`) |
| I5 | Downgrade auf ältere App-Version (altes IPA installiert) | ⚠️ | Keine Versionsprüfung der Zustandsdateien; ältere Builds kennen Task-Scopes nicht → sie arbeiten mit dem Legacy-Pfad. Kein Datenverlust-Pfad bekannt, aber ungetestet |
| I6 | Zwei Aufgaben auf demselben Zielordner | ✅ | Seit „eine Sicherung"-Modell strukturell unmöglich: `reduceToSingle` (`tasks_controller.dart:355–361`) |

## J. Darstellung, Eingaben, DAU-Klassiker

| # | Szenario | Ergebnis | Beleg |
|---|---|---|---|
| J1 | Hell/Dunkel-Umschaltung während der Nutzung | ✅ | `didChangePlatformBrightness` → `systemBrightnessProvider` live (`main.dart:169–176`) |
| J2 | Sprache DE↔EN wechseln, während Sync läuft | ⚠️ | Laufende Logzeilen mischen Sprachen (kosmetisch, `STRESSTEST_DAU` J4) |
| J3 | Dynamic Type / sehr große Systemschrift | ✅ | Keine `noScaling`-Aufrufe, `textScaler` greift standardmäßig (`STRESSTEST_DAU` J7, zurückgenommener Fehlbefund) |
| J4 | **Aufgabenname: 500 Zeichen + Emoji einfügen** | ✅ | `LengthLimitingTextInputFormatter(80)` (`tasks_screen.dart:1682,2194`) |
| J5 | Homescreen-Quick-Action „Jetzt synchronisieren" aus dem Kaltstart | ✅ | `QuickActions.initialize` liefert den Start-Grund nach (`quick_actions_service.dart:24–33`); Engine-Initialisierung läuft beim ersten RPC an (`_ensureEngine`) — kein Reihenfolge-Crash |
| J6 | Widget zeigt gelöschte Sicherung | ✅ | `recomputeAndPush` nach jeder Task-Änderung (`tasks_controller.dart:390–393`), leerer Zustand im Widget definiert |
| J7 | Widget ohne App-Group (Sideload) | ✅ | `app_group_unavailable` → Widget bleibt stehen, App läuft (`ARCHITECTURE.md` Widgets) |
| J8 | **Bestätigungsdialog wegdrücken (App wischen) statt Antwort** | ✅ | Dialoge sind Riverpod-/ setState-gestützt; keine ausstehenden Seiteneffekte vor der Antwort (Löschen erst nach `onTap`-Bestätigung) |
| J9 | iPad-Split-View / Fenster verkleinern | ⚠️ | Cupertino-/Fluent-Layouts skalieren, kein harter Bruch bekannt; nicht systematisch geprüft |
| J10 | Laufwerk-Tab: Laufwerk löschen, das die eine Sicherung nutzt | ✅ | Warnung nennt die betroffene Sicherung (`cloud_drives_screen.dart:813+`), Sync-Vorprüfung meldet klar (`remoteMissingInTask`) |

## K. Plattform-Grundlagen (iOS · Windows · Android)

### iOS

| # | Befund | Ergebnis |
|---|---|---|
| M-i1 | PhotoKit-Löschdialog: Drittanbieter-Apps dürfen nie still löschen | ✅ gebündelter Systemdialog, Ablehnung dauerhaft gemerkt |
| M-i2 | `NSPhotoLibraryUsageDescription`, `NSLocalNetworkUsageDescription`, `BGTaskSchedulerPermittedIdentifiers` in `Info.plist` | ✅ vorhanden (`ios/Runner/Info.plist:73–117`) |
| M-i3 | Keychain-Einträge überleben Deinstallation | ⚠️ verwaiste OAuth-Tokens (N-F8) |
| M-i4 | App-Group-ID wird zur Laufzeit aus dem Signing-Profil gelesen | ✅ Widget übersteht Sideload-Re-Signing |
| M-i5 | BGProcessingTask braucht App im Vordergrund regelmäßig, sonst seltene Weckung | ⚠️ systembedingt; `runMissedSyncs` federt nach — aber H1/H2 begrenzen den Wert |

### Windows

| # | Befund | Ergebnis |
|---|---|---|
| M-W1 | `rclone.exe` wird neben der EXE gebundelt, Fallback PATH | ✅ (`rclone_service_impl.dart:24–33`) |
| M-W2 | Fehlender/geänderter Quellordner, kleine Bibliothek | ⚠️/❌ siehe G2 (N-F5) |
| M-W3 | Mirror-Abbruch meldet „abgeschlossen" | ⚠️ `_cancelledMirrorJobs.remove(jobId)` **vor** der Status-Abfrage (`rclone_service_impl.dart:394–398`) → Abbruch wird als Erfolg gezeigt |
| M-W4 | `isSyncRunning` immer `false` | ❌ siehe H5 (N5) |
| M-W5 | Zeitplan ohne Autostart | ⚠️ läuft nur bei geöffneter App; UI-Hinweis vorhanden (`schedulePlatformNote`, `TESTMATRIX` D2) |
| M-W6 | Pairing-Empfänger Windows: Spiegelung wird heruntergestuft | ⚠️ veraltet — Windows kann seit dem Engine-Umbau echtes 2-Wege (`TESTMATRIX` Befund 1), aber `_platformHasTwoWayMirror` zählt nur iOS/Android (`device_pairing_screen.dart:64–67`). Folge: gekoppelte Windows-Rechner laden nie aus der Cloud nach. Sicherheitsseitig unkritisch (Inkrementell löscht nie) (N-F10) |

### Android

| # | Befund | Ergebnis |
|---|---|---|
| M-A1 | **Keine native Engine-Brücke**: `MainActivity.kt` ist eine leere `FlutterActivity`, kein `fibu/rclone`-MethodChannel, kein gomobile-AAR im Build → `LibrcloneChannel` wirft `MissingPluginException` bei jedem RPC | ❌ (N6) Die App ist auf Android eine Hülle; README/Architektur beschreiben Android als Zielplattform |
| M-A2 | Manifest: `READ_MEDIA_IMAGES/VIDEO` vorhanden, aber keine Schreib-Rechte für MediaStore (`WRITE_MEDIA_*`) und kein Keychain-Pendant (`fibu/keychain` nicht registriert) | ❌ selbst mit Engine-Brücke würden Import/Löschen in die Mediathek und der SecureStore auf den Datei-Fallback zurückfallen |
| M-A3 | Kein CI-Workflow für Android (`build-ios.yml`, `build-windows.yml` only) | ⚠️ Android-Builds sind nirgends verifiziert |
| M-A4 | Doze/OEM-Autostart-Einschränkungen (Xiaomi & Co.) | ⚠️ systembedingt; ohne M-A1 nicht einmal relevant |

**Konsequenz für die Plattform-Priorisierung:** Alle ❌-Pfade des Android-
Abschnitts sind keine Regressions, sondern Baustellen-Status. Die iOS- und
Windows-Befunde (H1–H5, N-F5) sind die eigentlich dringenden.

---

## L. Neue Befunde im Überblick (diese Runde)

| ID | Befund | Schwere | Beleg |
|---|---|---|---|
| N1 | Planer erwartet Job-Ende nicht: Erfolg zu früh gebucht, Sperre zu früh freigegeben | ❌ hoch | `scheduler_service.dart:337,347` + `startBackupJob` unawaited |
| N2 | iOS-BG-Lauf endet mit dem Callback-Return; Sync wird vermutlich abgeräumt | ❌ hoch (gerätetest-pflichtig) | `scheduler_service.dart:27–41` |
| N3 | Planer nutzt anderen Zielpfad als Dashboard (Root `/`, Mehrziel, Alt-Formate) | ❌ hoch | `scheduler_service.dart:255,311` vs. `dashboard_controller.dart:329–332` |
| N4 | Engine-Wächter wirkungslos durch neue Instanzen je Aufruf | ❌ mittel | `rclone_provider.dart:19–35`, `scheduler_service.dart:301` |
| N5 | Windows: `isSyncRunning` konstant `false` → parallele Mirror-Läufe | ❌ mittel | `rclone_service_impl.dart:173` |
| N6 | Android ohne native Bridge funktionsunfähig | ❌ (Status) | `MainActivity.kt`, fehlendes AAR |
| N-F5 | Windows: fehlender Quellordner + <10 Dateien → Tombstones in den Remote-Papierkorb | ⚠️ mittel | `filesystem_mirror_source.dart:44–52` |
| N-F6 | Neuinstallation < 5 min nach hartem Ende → eigene alte Sperre blockiert | ⚠️ niedrig | `sync_lock_service.dart:34–36,78–90` |
| N-F7 | Neuinstallation mit anderer Album-Auswahl → Re-Download + Duplikat-Spirale | ⚠️ mittel | `virtual_mirror_sync.dart:767–950` |
| N-F8 | Verwaiste Keychain-Tokens nach Deinstallation | ⚠️ niedrig | `oauth_service.dart:78` |
| N-F9 | `files:`-Echo: transientes Staging vereitelt Lösch-Propagation | ⚠️ niedrig | `ios_rclone_service.dart:1132–1148` |
| N-F10 | Pairing→Windows stuft Spiegelung ab, obwohl Windows 2-Wege kann | ⚠️ niedrig | `device_pairing_screen.dart:64–67` |
| N-F11 | „Abbrechen" + Sofort-Neustart → „läuft bereits" bis Einzeltransfer fertig | ⚠️ niedrig | `ios_rclone_service.dart:603–609,1040–1052` |
| N-F12 | Basisnamen-Toleranz: gleiche Größe+Name in anderem Album gilt als gesynct | ⚠️ niedrig | `virtual_mirror_sync.dart:255–272` |
| N-F13 | Ein Fehler beendet die komplette Ziel-Queue | ⚠️ niedrig | `dashboard_controller.dart:600–610` |

### Fix-Empfehlungen (Priorität)

1. **H1/H2/H4 in einem Rutsch:** Planer soll den Job bis zum Ende erwarten
   (await auf den Status-Stream statt fire-and-forget), Ergebnis *danach*
   ins Laufprotokoll, Sperre *danach* freigeben; Engine als Singleton/
   `static`-Instanz teilen. Für iOS-BG: Callback darf erst nach Job-Ende
   returnen (mit hartem Zeitdeckel).
2. **H3:** Eine gemeinsame Funktion `remotePathFor(task, target)` für
   Dashboard **und** Planer (inkl. `root` → `''`, `id:subpath`-Auflösung,
   alle Ziele statt `first`).
3. **N5:** Windows: laufende Job-IDs zählen (analog iOS), `isSyncRunning`
   daraus ableiten; Abbruch-Status vor dem `remove` auswerten.
4. **N-F5:** `FilesystemMirrorSource.scan()` soll zwischen „Ordner leer"
   und „Ordner existiert nicht" unterscheiden; „existiert nicht" = harter
   Fehler statt Lösch-Kandidaten.
5. **N-F6:** Beim Lock-Check zusätzlich prüfen, ob der Herzschlag-Gerätename
   dem eigenen `Platform.localHostname` entspricht → eigene verwaiste Sperre
   sofort übernehmen.
6. **N-F7:** Nach Neuinstallation ohne Zustand beim ersten Lauf automatisch
   adoptieren (Flag setzen), wenn `.fibu/config.json` auf dem Remote liegt
   und importiert wurde — oder im Wizard „vorhandene Sicherung gefunden"
   als Adoption anbieten.
7. N6/M-A: Android entweder ehrlich als „nicht unterstützt" kennzeichnen
   oder Bridge + Berechtigungen bauen (eigene Entscheidung, größerer Umbau).

---

## M. Empfohlene Reihenfolge für den Praxis-Test am Gerät

1. **H1/H2 (iOS):** Sicherung mit Zeitplan „iOS System" anlegen, App
   schließen, 24 h warten. Dann: Sync-Log + Cloud-Bestand gegen
   `SchedulerRunLog` prüfen. Erwartet laut Code: Protokoll sagt „Erfolg",
   Cloud zeigt nichts Neues → Befund bestätigt.
2. **H3:** Aufgabe mit Ziel „Root" + Tageszeitplan; manuell und geplant
   laufen lassen; prüfen, ob `.fibu/lock.json` zweifach existiert
   (`/.fibu/` vs. `.fibu/`) und ob zwei State-Scopes entstehen.
3. **Referenz-Szenario (Abschnitt 1)** am Stück: einrichten → großer Lauf →
   Abbruch → Deinstallation → Neueinrichtung **ohne** Task-Import mit
   abweichender Album-Auswahl → Duplikat-Verhalten beobachten (N-F7).
4. **G2/N-F5 (Windows):** Aufgabe mit 3 Dateien, Quellordner umbenennen,
   syncen → Remote-Papierkorb prüfen.
5. **E11:** iCloud-Fotos deaktivieren, syncen → Bremse muss Meldung zeigen,
   keine Cloud-Löschungen.
6. Danach die ✅-Klassiker als Regression (B1, B7, D1, D2, E1, C1).

---

## O. Fix-Runde (gleicher Tag, gleicher Branch)

Die ❌-Befunde und die sinnvollen ⚠️-Befunde wurden unmittelbar nach dem
Audit behoben. Zuordnung Befund → Fix:

| Befund | Fix | Umsetzung |
|---|---|---|
| H1/H2 (N1/N2) | Planer erwartet das **Ende** des Laufs | `_runAndWait` in `scheduler_service.dart`: Status-Stream mit Ereignis-Puffer, Ergebnis (und Laufprotokoll) erst nach `completed`/`failed`/`cancelled`; 6-h-Zeitdeckel als Sicherheitsnetz. Der Workmanager-Callback kehrt dadurch erst nach dem Lauf zurück |
| H1 (Sperre) | Cloud-Sperre bleibt bis Laufende | `SyncLock.release` steht jetzt im `finally` **nach** `_runAndWait` |
| H3 (N3) | Eine Pfad-Wahrheit für Dashboard und Planer | `BackupTask.resolveTarget` + `BackupTask.fromJson` (`tasks_controller.dart`); Dashboard (`_syncTaskToRemote`) und Planer (`_runOneTask`) nutzen dieselbe Auflösung inkl. Root-Modus (`''`) und `id:subpath`; der Planer läuft jetzt **alle** Ziele ab, nicht nur `remotes.first` |
| H4 (N4) | Instanz-unabhängiger Lauf-Wächter | Neuer `SyncRunGuard` (`rclone_service.dart`): jeder `startBackupJob` zählt hoch, jeder Abschluss herunter; `isSyncRunning` beider Engines wertet ihn mit aus |
| H5/N5 | Windows-Parallel-Schutz | `WindowsRcloneService` führt jetzt `_runningJobIds`, lehnt zweite Läufe mit `syncAlreadyRunning` ab (analog iOS), Guard-Enter/Exit in beiden Code-Pfaden |
| N-F5 | Fehlender Quellordner = harter Fehler | Prüfung vor dem Mirror-Start (`rclone_service_impl.dart`); neue Meldung `errSourceFolderMissing` (DE/EN) in `app_strings.dart` |
| N-F6 | Eigene verwaiste Sperre sofort übernehmen | `SyncLock.acquire`: frische Sperre mit fremder Kennung, aber **eigenem Gerätenamen** wird übernommen (`sync_lock_service.dart`) |
| N-F7 | Re-Download-Falle nach Neuinstallation | Nach dem Aufgaben-Import aus der Cloud (Auto-Dialog **und** Import-Bildschirm) wird `markMirrorAdoption()` gesetzt → der erste Mirror-Lauf adoptiert den Bestand statt ihn in die Mediathek zurückzuladen |
| N-F10 | Pairing→Windows stuft nicht mehr ab | `_platformHasTwoWayMirror` umfasst jetzt Windows (`device_pairing_screen.dart`) |
| N-F11 | Abbruch + Sofort-Neustart | `startBackupJob` (iOS) wartet bis zu 15 s, wenn alle laufenden Läufe bereits abgebrochen sind, statt sofort „läuft bereits" zu melden |
| M-W3 | Abbruch meldet „abgebrochen" statt „fertig" | Windows-Mirror wertet das Abbruch-Set **vor** dem Entfernen aus (`rclone_service_impl.dart`) |

**Bewusst nicht geändert** (Dokumentation bleibt bestehen): N-F8
(Keychain-Aufräumen nach Deinstallation ist ohne App nicht möglich), N-F9
(`files:`-Echo-Designentscheidung), N-F12 (bewusste Namens-Toleranz), N-F13
(Fehler beendet Queue — im Eine-Sicherung-Modell ohnehin meist ein Ziel),
J2-Sprachmix, K9-Layout, Android-Ausbau (N6/M-A*: eigene Produktentscheidung,
siehe Abschnitt K).

**Verifikation der Fixes.** Ohne Flutter-SDK in dieser Umgebung laufen
`flutter analyze`/`flutter test` nur in der CI (Workflows bauen iOS **und**
Windows auf jedem Push, auch auf `arena/**`). Die manuelle Testreihenfolge
aus Abschnitt M — insbesondere Punkt 1 (H1/H2) und Punkt 2 (H3) — bleibt der
maßgebliche Nachweis am Gerät; die Erwartung kehrt sich um: Das Laufprotokoll
darf einen Hintergrund-Lauf erst **nach** tatsächlichem Abschluss als Erfolg
buchen, und Root-Ziele dürfen nur noch eine `.fibu/lock.json` erzeugen.

---

## N. Was in dieser Umgebung nicht prüfbar war

- Laufzeit auf echten Geräten/Simulatoren (kein Flutter-SDK, keine Geräte).
  Besonders: iOS-BG-Isolat-Verhalten (J2), PhotoKit-Dialogverhalten,
  Android-Permissions, Windows-Autostart.
- Provider-Spezifika einzelner rclone-Backends (Server-Side-Move,
  Sonderzeichen, Multipart-Reste).
- Ob `flutter analyze`/`flutter test` auf `c702ceb` grün sind — die CI der
  Workflows läuft bei jedem Push; letzter dokumentierter Stand auf `main`:
  grün (`STRESSTEST_DAU.md`, Nachtrag 2026-09-05).

---

## P. iOS-Spiegelmodus: dedizierter Zweitdurchgang

Nachfrage-gemäß wurde der iOS-Spiegelmodus (`_runVirtualMirrorSync` →
`VirtualMirrorSyncEngine.sync`, `ios_rclone_service.dart:1896 ff.`,
`virtual_mirror_sync.dart:106 ff.`) Ende-zu-Ende neu durchlaufen — Scan,
Abgleich, Upload, Tombstones, Lösch-Dialoge, Download/Import, Persistenz —
und gegen die Szenarien-Tabellen geprüft. Zusätzlich zu den bereits
dokumentierten Fällen (Abschnitte B, C, D, E, G, H, J) wurden dabei folgende
Pfade explizit verifiziert:

| Szenario | Ergebnis |
|---|---|
| Album wird umbenannt/gelöscht, Fotos bleiben | ✅ | Pfad-Anker über Asset-ID (`previousRelByAsset`, `ios_rclone_service.dart:1796–1812`): rel bleibt stabil, kein Tombstone, kein Re-Upload |
| Foto nur aus EINEM Album entfernt | ✅ | Asset existiert weiter (`fromId` ≠ null) → „vermisst" wird verworfen (`_confirmDeletions:1466 ff.`) |
| Foto in „Zuletzt gelöscht", dann wiederhergestellt | ✅ | E2; läuft das Tombstone vorher aus, bleibt die Cloud-Kopie 30 Tage im Remote-Papierkorb, Wiederherstellung kostet einen Re-Upload |
| Zwei Aufgaben spiegeln dasselbe Album in verschiedene Ordner | ✅ | Getrennte Scopes; Löschungen laufen je Scope über dieselbe Asset-ID-Erkennung, Cloud-Kopien landen je Ordner im Papierkorb |
| Eingeschränkter Fotozugriff („Auswahl …") | ✅ | Lösch-Erkennung wird übersprungen statt falsch beschlossen (`_confirmDeletions`, `permissionLimited`) |
| Hintergrund-Lauf darf nicht löschen | ✅ | Löschungen gehen in den `PendingDeletionsStore` und werden im Dashboard angeboten (J-Abschnitt) |
| Upload schlägt fehl (Quota/Netz) mitten im Lauf | ✅ **nach Fix M-I1** | s. u. |
| Cloud-Fassung neuer → Replace | ✅ **nach Fix M-I2** | s. u. |
| Abbruch in jeder Phase | ✅ | `isCancelled` zwischen Dateien; Abbruchsignal wirkt in Upload-, Tombstone- und Download-Phase |
| Quarantäne/Absturz mitten im Lauf | ✅ | Zustand wird nur am Laufende geschrieben; Teil-Uploads bleiben in der Cloud und werden per Inhaltsvergleich erkannt (kein Re-Transfer) |

### Neue Befunde aus diesem Durchgang

| ID | Befund | Schwere | Status |
|---|---|---|---|
| M-I1 | `syncedNow` nahm jeden lokalen Pfad als „gesynct" auf, sobald sein **Dateiname** im Mediathek-Index stand — unabhängig davon, ob die Datei je hochgeladen wurde. Der Zusatz-Ast widersprach dem direkt darüberstehenden Garantie-Kommentar. Folge: Schlug ein Upload fehl (Quota voll, Netzfehler), galt der Pfad trotzdem als „in der Cloud vorhanden"; im nächsten Lauf erzeugte das einen **Löschvorschlag für ein Foto, das nie gesichert war** (unterhalb der Anomalie-Bremsen, also ohne Schutz) | ❌ (potenzieller Datenverlust über den Systemdialog) | **behoben**: Ast entfernt (`virtual_mirror_sync.dart:998 ff.`); gesynct ist nur noch „Inhalt nachweislich in der Cloud" (uploadedRels) oder exakt dort vorhanden |
| M-I2 | Replace-Flow („Cloud-Fassung neuer"): Die lokale Version wurde **vor** dem Download der neuen Fassung gelöscht. Brach der Download danach ab (Netz, Abbruch, Gerät voll), war die lokale Kopie weg (nur in „Zuletzt gelöscht") und die Cloud-Fassung wurde im nächsten Lauf als „lokal gelöscht" interpretiert → auch sie wäre in den Papierkorb gewandert | ⚠️ (nur über zwei Fehlerkanten erreichbar, aber doppelter Verlust möglich) | **behoben**: `importDownloaded` liefert jetzt die erfolgreich importierten rel-Pfade; Altversionen werden erst NACH erfolgreichem Download **und** Import entfernt (`virtual_mirror_sync.dart:948 ff., 967 ff.`; beide Plattformen: Mediathek-Import iOS, Ordner-Import Windows) |
| M-I3 | Scheitert der Import in die Mediathek dauerhaft (z. B. Schreibrecht entzogen), wird dieselbe Cloud-Datei in jedem Lauf erneut geladen (der Erfolg wird nicht persistiert, weil das Asset nie im Scan auftaucht) | ⚠️ niedrig | dokumentiert; Lauter Fehlerlog vorhanden (`okCount`). Behebung braucht eine „bekannt, aber nicht importierbar"-Liste — bewusst nicht in dieser Runde |
| M-I4 | Aufgaben-Bearbeitung mit geänderter Album-Auswahl erzeugt einen neuen Zustands-Scope; darin sind die `blocked`-Mengen des alten Scopes nicht mehr wirksam (Dateien, deren Cloud-Löschung der Nutzer abgelehnt hatte, könnten erneut angeboten werden). Datenverlust ausgeschlossen (Dialog), allenfalls lästig | ⚠️ niedrig | dokumentiert; `_adoptLegacyGuards` übernimmt blocked/adopted nur aus dem ALTEN aufgabenübergreifenden Zustand, nicht zwischen Scopes |
| M-I5 | Die Adoptions-Flagge (`markMirrorAdoption`) liegt geräteweit im Basisordner und wird vom NÄCHSTEN Mirror-Lauf VERBRAUCHT — unabhängig davon, ob der Lauf zur importierten Aufgabe gehört. Im Eine-Cloud-Modell unkritisch; bei mehreren Aufgaben theoretisch Fehl-Adoption ohne Schaden (Adoption lädt nichts, sie verhindert nur Re-Downloads) | ⚠️ niedrig | dokumentiert |
| M-I6 | Geteilte Alben und reine Foto-Stream-Inhalte erscheinen nicht im Scan (`getAssetPathList` liefert sie nicht) — sie werden nicht gesichert | ⚠️ niedrig | dokumentiert (iOS-Eigenheit, keine Datenverlust-Kante) |
| M-I7 | `library_index.json` wächst unbegrenzt (Name+Größe je gesyncter Datei, nie bereinigt); bei sehr großen Mediatheken über Jahre ein langsam wachsendes JSON | ⚠️ niedrig | dokumentiert |
| M-I8 | Scope-Schlüssel ist ein 32-bit-FNV-Hash; eine Kollision zweier Aufgaben würde deren Zustände vermischen. Theoretisch (Geburtstags-Grenze ~77 Tsd. Aufgaben), praktisch ausgeschlossen | Hinweis | dokumentiert |
| M-I9 | Live-Photo-/RAW-Paar-Hälften (E12) — unverändert Gerätetest nötig | ⚠️ | wie E12 |

Alle übrigen Spiegel-Pfade (Tombstone-Replay, Konflikt-Kopien,
Umbenennungs-Erkennung, Anomalie-Bremsen, Systemdialog-Bündelung,
Remote-Papierkorb, Adoptions-Moduswechsel) wurden gegen den aktuellen Code
bestätigt und entsprechen den Abschnitten C/D/E.

---

## Q. Netzwerkausfall während eines laufenden Backups

Nach Prüfung aller Transferpfade (Nachfrage 2026-09-16):

| Phase | Verhalten bei Netzwerkverlust | Datenverlust? |
|---|---|---|
| Vorab-Check beim Start | Offline → Lauf startet nicht, `syncOfflineNoNetwork` (`_runJob`, `ios_rclone_service.dart`) | nein |
| Upload (Spiegel + inkrementell) | Einzelne Datei scheitert → `AppLog.warn`, Lauf macht mit der nächsten weiter; die Datei bleibt außerhalb des „gesynct"-Zustands (M-I1) und kommt beim nächsten Lauf erneut hoch | nein |
| Download | Wie Upload; halb geladene Temp-Dateien werden im `finally` weggeräumt | nein |
| Cloud-Auflistung (Basis jeder Lösch-Entscheidung) | Fehler bleibt LAUT (`_listRemoteRecursive`), der Lauf scheitert insgesamt → es wird **nichts** gelöscht | nein |
| Tombstone-Ausführung (Löschphase) | Einzelne Remote-Löschung scheitert → Warnung; das Tombstone bleibt gesetzt und wird nächstes Mal erneut versucht; die Datei wird nicht wieder heruntergeladen | nein |
| Windows-`rclone copy` (inkrementell) | Prozess endet mit Fehler → Job-Status `failed` → freundliche Netz-Meldung über `_friendlySyncError` | nein |
| iOS-Hintergrundlauf | iOS beendet den Lauf bei Netzverlust; nichts wird als Erfolg gebucht (H1-Fix), `runMissedSyncs`/nächster Planer-Tick holt nach | nein |
| Cloud-Sperre | Wird im `finally` freigegeben, auch bei Fehler — kein anderes Gerät bleibt blockiert | — |

**Fazit:** Ein Netzwerkausfall mitten im Lauf ist in allen Modi sicher:
Es geht nichts verloren, nichts wird fälschlich gelöscht, Übertragenes
bleibt in der Cloud, Nicht-Übertragenes wird nachgeholt. Einziger
Komfort-Makel: Ein Spiegel-Lauf, der mitten im Lauf das Netz verliert,
endet als „abgeschlossen mit weniger Transfers" statt als „fehlgeschlagen" —
die fehlenden Dateien holt der nächste Lauf. Das Laufprotokoll/`fibu.log`
zeigt die Einzel-Fehler.

---

## R. Standby/Sperrbildschirm während eines Laufs (Wachhalten)

Nachfrage 2026-09-17: Ein angefangener Lauf soll nicht durch den
Auto-Sperrbildschirm einfrieren.

**Umsetzung (still, ohne Meldung):**

- Neuer `KeepAwakeService` mit Referenzzähler, aktiviert beim Job-Start,
  gelöst beim Job-Ende — exakt dieselben Pfade wie der `SyncRunGuard`
  (iOS `whenComplete`, Windows Mirror `whenComplete` bzw. `exitCode`/catch).
- **iOS:** `isIdleTimerDisabled` über den bestehenden `fibu/system`-Kanal
  (Registrierung auch im Hintergrund-Isolate).
- **Windows:** `SetThreadExecutionState` (kernel32, via `dart:ffi`, ohne
  Zusatzpaket) mit `ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED`;
  am Laufende Rücksetzung auf `ES_CONTINUOUS`.
- Wirkt nur, solange ein Lauf aktiv ist; nach dem Lauf gilt wieder das
  normale Auto-Sperr-Verhalten. Für reine Hintergrundläufe
  (BGProcessingTask) ist es wirkungslos, aber harmlos.
- Nicht mobil-Android: ohne native Fibu-Brücke bewusst No-Op (Protokoll).

**Verhalten im Standby damit:**
| Situation | Verhalten |
|---|---|
| Manueller Lauf, Gerät wird nicht benutzt | Bildschirm bleibt an, Lauf läuft durch |
| Lauf fertig | Auto-Sperre sofort wieder aktiv |
| App wird trotzdem vom System beendet | Kein falscher Erfolg; Nachholen über Planer/`runMissedSyncs` |
