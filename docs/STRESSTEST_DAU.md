# Fibu — DAU-Stresstest (Szenario-Katalog + Theorie-Prüfung)

Stand: `main` @ `b5a95c9`. Jeder Befund ist gegen den echten Code geprüft, mit
Datei/Zeile als Beleg. Legende:

| Zeichen | Bedeutung |
|---|---|
| ✅ | Hält stand — Schutz im Code vorhanden |
| ⚠️ | Hält eingeschränkt stand — Risiko unter realistischen Bedingungen |
| ❌ | Hält **nicht** stand — reproduzierbarer Fehler / Datenverlust möglich |

---

## 0. Ergebnis nach der Fix-Runde

Von ursprünglich 5 ❌ und 22 ⚠️ sind **alle Datenverlust-Pfade behoben**.
Übrig bleiben Restrisiken, die bewusst nicht geändert wurden (Begründung je
Punkt in den Tabellen unten).

**Korrigierter eigener Befund:** J7 (Dynamic Type) war **falsch** — Flutter
skaliert `fontSize` standardmäßig über `MediaQuery.textScalerOf(context)`.
Der grep nach `textScaler` war kein Beleg für fehlende Skalierung.

### Umgesetzte Fixes

| Fix | Umsetzung |
|---|---|
| Abbruch stoppt Spiegel-Sync | `isCancelled`-Signal in beide Engines; geprüft vor jeder Datei in Upload-, Download- und Lösch-Phase |
| Keine Lösch-Welle mehr | `_confirmDeletions`: je „vermisstem" Pfad wird per `AssetEntity.fromId` geprüft, ob das Asset wirklich weg ist. Nur dann Tombstone |
| Eingeschränkter Fotozugriff | Bei `limited` wird die Lösch-Erkennung vollständig übersprungen |
| Album-Reihenfolge | Alphabetisch kanonisiert (Wizard + Bearbeiten) **und** `stateScopeKey` reihenfolge-unabhängig |
| State-Leck beim Löschen | `cleanupMirrorState` entfernt den Scope-Ordner der gelöschten Aufgabe |
| Bearbeiten während Sync | Gesperrt mit erklärendem Dialog |
| Gleichnamige Alben | `taken`-Menge global pro Lauf |
| Namenslänge | 80 Zeichen, ohne Zähler-UI |

### Bewusst **nicht** geändert (mit Begründung)

| Punkt | Begründung |
|---|---|
| D10 / J6 — Album- und Zielordner-Namen strenger bereinigen | Würde die Spiegelpfade **aller bestehenden Nutzer** ändern → Massen-Re-Upload. Der Nutzen (kosmetisch) rechtfertigt das nicht |
| F7 — Inhalts-Hash statt Größe+Zeit | Auf dem Gerät zu teuer; Größe+Modtime ist die bewusste Abwägung |
| I3 / I5 — Live Photos, RAW, versteckte Fotos | Ohne Gerät nicht belastbar prüfbar |
| J4 — Sprachmix in laufenden Logs | Kosmetisch; sauber lösbar nur über Meldungsschlüssel statt Text |
| B7 — Laufwerk mitten im Sync löschen | Der Lauf scheitert am nächsten rclone-Aufruf mit klarer Meldung |
| C5 — zwei Aufgaben auf demselben Zielordner | Seit der Task-Isolation kein gegenseitiges Löschen mehr; eine UI-Warnung wäre Zusatzkomfort |
| K1 / K2 / K4 | Systembedingt (Neuinstallation, Zweitgerät, Systemuhr) |

---|---|---|
| 1 | **„Abbrechen" stoppt einen Spiegel-Sync nicht.** UI sagt „Abgebrochen", die Transfers laufen weiter, danach blockiert die Parallel-Sperre neue Syncs. | ❌ |
| 2 | **„Zuletzt gelöscht" / „Zuletzt hinzugefügt" sind als Task-Album wählbar** → schleichender Cloud-Datenverlust durch Tombstones. | ❌ |
| 3 | **Album-Reihenfolge = Tipp-Reihenfolge** → `sourcePath` nicht kanonisch → Mirror-Zustand wird beim Bearbeiten still verworfen. | ⚠️ |
| 4 | **Eingeschränkter Fotozugriff („Auswahl …")** wird wie Vollzugriff behandelt → nicht freigegebene Fotos gelten als „lokal gelöscht". | ⚠️ |
| 5 | Die Anomalie-Bremse ist eine reine **>50 %-Heuristik** — schleichender Schwund bleibt unter dem Radar. | ⚠️ |
| 6 | **Dynamic Type wird ignoriert** — `textScaler` kommt in `lib/` kein Mal vor; große Systemschrift skaliert nichts. | ❌ |

---

## A. Ersteinrichtung & Leerzustände

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| A1 | App zum ersten Mal starten, nichts eingerichtet | Nur „Laufwerk hinzufügen" | `_buildSetupHint` zeigt bei `!hasRemotes` ausschließlich die Laufwerk-Zeile (`dashboard_screen.dart:88–100`) | ✅ |
| A2 | Laufwerk da, keine Aufgabe | Nur „Aufgabe erstellen" | `else if (!hasTasks)` → genau eine Zeile | ✅ |
| A3 | Während `tasks.json` noch lädt auf das Dashboard schauen | Kein falscher Leerzustand | Gate über `tasksLoadedProvider` (`:83`) | ✅ |
| A4 | „Aufgabe erstellen" antippen | Springt in den Aufgaben-Tab | `shellIndexProvider` wird mit dem `CupertinoTabController` synchronisiert | ✅ |
| A5 | Sync drücken ohne Laufwerk/Aufgabe | Klare Meldung, kein Crash | `noActiveTasksError` / Netzwerk-Vorprüfung | ✅ |

## B. Cloud-Laufwerke

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| B1 | Laufwerk löschen, das eine Aufgabe nutzt | Warnung vor dem Löschen | Dialog nennt die betroffenen Aufgaben: `deleteDriveTasksWarning(affectedTasks)` (`cloud_drives_screen.dart:813+`) | ✅ |
| B2 | Laufwerk löschen, dann Sync der verwaisten Aufgabe | Klare Meldung, kein kryptischer rclone-Fehler | Vorprüfung gegen die Registry: `remoteMissingInTask(id)` (`dashboard_controller.dart:_syncSingleTask`) | ✅ |
| B3 | OAuth-Abbruch mitten im Login (Fenster schließen) | Kein halb verbundenes Laufwerk | Token wird geparkt und beim Löschen gezielt geräumt (`clearToken`) | ✅ |
| B4 | Union/Crypt/Combine ohne Basis-Laufwerk anlegen | Hinweis statt leerer Auswahl | Dropdown zeigt nur vorhandene Laufwerke, sonst Hinweis | ✅ |
| B5 | Zweites Laufwerk mit demselben Anzeigenamen | Keine stille Kollision | Namen werden über die Registry-Kennung aufgelöst | ✅ |
| B6 | Laufwerk trennen, später erneut verbinden und Aufgaben importieren | Album-Auswahl bleibt erhalten | `selectedAlbums`/`selectedFolders` werden jetzt in `.fibu/config.json` mitgeschrieben | ✅ |
| B7 | Laufwerk löschen, während ein Sync darauf läuft | Sauberer Abbruch | **Nicht geschützt** — der laufende Mirror bekommt das entfernte Ziel erst beim nächsten rclone-Aufruf mit; kein Abbruch, keine Vorwarnung | ⚠️ |

## C. Aufgaben

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| C1 | Aufgabe löschen | Bestätigung mit Konsequenz | `_confirmDeleteTask` + `deleteTaskRule6Notice` | ✅ |
| C2 | Aufgabe ohne Ziel-Laufwerk speichern und syncen | Klare Meldung | `remoteNotFoundHint` | ✅ |
| C3 | Aufgabe bearbeiten, während ein Sync läuft | Kein Datenriss | Bearbeiten ist während eines laufenden Syncs gesperrt, mit erklärendem Dialog statt stiller Ignoranz. | ✅ |
| C4 | Aufgabe löschen, dann neu anlegen mit gleicher Quelle/Ziel | Frischer Zustand erwartet | `removeTask` ruft `cleanupMirrorState` auf und entfernt den Scope-Ordner der gelöschten Aufgabe. | ✅ |
| C5 | Zwei Aufgaben auf denselben Zielordner | Kein gegenseitiges Löschen | Seit der Task-Isolation eigener Zustand je (Laufwerk+Ziel+Quelle). **Aber:** beide schreiben in denselben Cloud-Ordner und sehen die Dateien des jeweils anderen als „fremd" | ⚠️ |
| C6 | 50 Aufgaben anlegen und „Sync" drücken | Läuft nacheinander durch | Sequentielle Queue (`for (final task in activeTasks) await _syncSingleTask`), ein Fehler beendet die Queue | ✅ |

## D. Album-Auswahl — **kritischster Bereich**

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| D1 | Album im Bearbeiten-Modus öffnen | Zugehörige Alben sind vorausgewählt | `effectiveAlbums` (Feld, sonst aus `sourcePath`) | ✅ |
| D2 | Kein Album wählen | „Alle Alben" | `allowAll = selectedAlbums.isEmpty` | ✅ |
| D3 | **Smart-Album mit wechselndem Inhalt wählen** („Favoriten": Foto ent-favorisieren; „Zuletzt hinzugefügt": Foto altert raus) | Sollte gesperrt/warnen | Kein Datenverlust mehr: `_confirmDeletions` prüft je Kandidat per `AssetEntity.fromId`, ob das Asset wirklich weg ist. Ein Foto, das aus einem Smart-Album verschwindet, existiert weiter → kein Tombstone. Der Cloud-Ordner heißt weiterhin wie das Smart-Album (kosmetisch). | ✅ |
| D4 | **„Zuletzt hinzugefügt" (Recents) als einziges Album** | Dauerhafte Sicherung erwartet | Wie D3 — Altern ist keine Löschung. Die >50 %-Bremse bleibt als zweites Netz. | ✅ |
| D4b | „Zuletzt gelöscht" als Album wählen | Sollte gesperrt sein | Falls das Album geliefert wird: gleicher Schutz wie D3, weil die Prüfung asset-basiert und nicht album-basiert ist. | ✅ |
| D5 | Alben in anderer Reihenfolge antippen (B, A statt A, B) | Identische Aufgabe | `_selectedAlbums` ist ein `Set`, `join('| Wizard sortiert Alben alphabetisch vor dem Codieren; zusätzlich ist `stateScopeKey` reihenfolge-unabhängig (`canonicalMediaSource`). | ✅ |
| D6 | Aufgabe nach D5 einmal bearbeiten | Zustand bleibt | Bearbeiten sortiert identisch zum Wizard; und selbst bei altem, unsortiertem `sourcePath` ergibt die Kanonisierung denselben Scope. | ✅ |
| D7 | Album abwählen, das vorher gesichert wurde | Cloud bleibt unangetastet | Jetzt korrekt per Design: Album abwählen ändert den Scope nicht mehr, und `_confirmDeletions` verhindert Löschungen ohnehin. | ✅ |
| D8 | Quelle von „Fotos & Videos" auf „Videos" umstellen | Fotos bleiben in der Cloud | Wie D7. | ✅ |
| D9 | Leeres Album auswählen | Kein Fehler | `if (count == 0) continue` | ✅ |
| D10 | Album mit leerzeichen/Umlaut/Emoji im Namen | Funktioniert | Nur `/ \ :` werden ersetzt (`:1618`); Leerzeichen, Umlaute, Emoji wandern **unverändert** in den Cloud-Pfad | ⚠️ |
| D11 | Zwei Alben mit identischem Namen | Keine Kollision | `taken`-Menge ist jetzt pro Lauf global statt pro Album. | ✅ |

## E. Sync auslösen & steuern

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| E1 | „Sync" doppelt/vervielfacht antippen | Nur ein Lauf | Guard: `if (state.status == syncing \|\| pending) return` (`triggerSyncAll`, `triggerSyncTask`) | ✅ |
| E2 | Sync im Dashboard, gleichzeitig geplanter Hintergrund-Lauf | Nur ein Lauf | Service-Mutex `isSyncRunning` + Scheduler prüft ihn (`scheduler_service.dart:113`) | ✅ |
| E3 | **„Abbrechen" während eines Spiegel-Syncs** | Lauf endet sofort | `cancelBackupJob` setzt jetzt ein Abbruch-Signal, das beide Engines zwischen den Dateien abfragen (`isCancelled`). Upload-, Download- und Lösch-Phase brechen sofort ab. | ✅ |
| E4 | „Abbrechen" während eines inkrementellen Syncs | Lauf endet | `job/stop` auf den rclone-Job | ✅ |
| E5 | App während des Syncs in den Hintergrund, iOS killt sie | Kein kaputter Zustand | Zustand wird erst in Phase 5 geschrieben; beim nächsten Lauf wird gegen die Cloud-Liste neu abgeglichen. `_runningJobIds` ist flüchtig → kein Blockade-Rest | ✅ |
| E6 | Offline auf „Sync" drücken | Klare Meldung | `_networkBlockReason` → `networkUnavailableError` | ✅ |
| E7 | „Nur WLAN" aktiv, mobiles Netz | Kein Sync | `cellularSyncBlockedNotice` | ✅ |
| E8 | Netz bricht mitten im Sync weg | Fehler, kein Hänger | rclone-Fehler wird gefangen und als Fehlerzustand gemeldet | ✅ |
| E9 | Fortschrittsanzeige bei 0 zu tun | Kurzer, ruhiger Balken | Zähler + Prozent in einer Zeile, „Überprüfen" als Platzhalter | ✅ |

## F. Sync-Inhalt: Löschungen & Konflikte

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| F1 | Lokal löschen, syncen (Spiegel) | Cloud-Löschung, kein Re-Download | Tombstones + `previouslySyncedRels` + Name/Größe-Index | ✅ |
| F2 | In der Cloud löschen, syncen | Lokal löschen nach Systemdialog | `deleteLocalAssets` via PhotoKit (iOS zeigt Dialog) | ✅ |
| F3 | Lokal **und** remote geändert (Konflikt) | Neuere Seite gewinnt | `contentCmp` über Größe + Modtime mit Vorrang lokal bei Unklarheit | ✅ |
| F4 | Foto lokal zuschneiden, syncen | Änderung wird erkannt | Größen-Differenz → Upload | ✅ |
| F5 | Massenhaft „fehlend" (Formatwechsel) | Keine Lösch-Welle | Anomalie-Bremse `prevCount >= 10 && missing*2 > prev` | ✅ |
| F6 | **Schleichender** Schwund (D4, G3) | Trotzdem Schutz | Ersetzt durch den präzisen Asset-Existenz-Check. Schleichender Schwund wird jetzt korrekt als „nicht gelöscht“ erkannt. | ✅ |
| F7 | Datei remote geändert, Größe gleich, nur Metadaten | Wird erkannt | Nur Größen-/Zeitvergleich; **kein** Hash. Gleiche Größe + gleiche Zeit → unerkannt | ⚠️ |
| F8 | Reihenfolge Upload → Download | Immer erst hoch, dann runter | Beide Engines: Upload-Phase vor Download-Phase, per Test abgesichert | ✅ |

## G. Berechtigungen

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| G1 | Fotozugriff komplett verweigern, Sync starten | Klare Meldung | `throw Exception(errPhotoPermission)` nach `!ps.isAuth && !ps.hasAccess` (`:1125`, `:1550`) | ✅ |
| G2 | Zugriff später in den Einstellungen erteilen | Funktioniert ohne Neustart | `requestPermissionExtend` wird bei jedem Lauf neu gefragt | ✅ |
| G3 | **„Auswahl …" (eingeschränkter Zugriff), 10 von 5000 Fotos** | Nur freigegebene sichern, Rest unangetastet | Bei `limited` (`hasAccess && !isAuth`) wird die Lösch-Erkennung komplett übersprungen und geloggt — `fromId` liefert dort null, obwohl das Foto existiert. | ✅ |
| G4 | Zugriff von „Auswahl" auf „Alle Fotos" erweitern | Keine Löschungen | Scan sieht wieder alles → keine `deletedNow` | ✅ |
| G5 | iCloud-Fotos ausgelagert („Optimierter Speicher") | Werden für den Upload geladen | `asset.file` löst den Download aus; bei Abbruch schlägt der Einzel-Upload fehl und wird nächstes Mal erneut versucht | ✅ |

## H. Speicherplatz

| # | Szenario | Erwartung | Ist-Verhalten | Bewertung |
|---|---|---|---|---|
| H1 | Cloud voll, Upload nötig | Warnung, kein Einzel-Fehler-Gewitter | Quota-Vorprüfung → `syncRemoteFullWarning`, Uploads übersprungen | ✅ |
| H2 | Gerät voll, Download nötig | Warnung | `DeviceStorage.freeBytes()` → `syncLocalFullWarning` | ✅ |
| H3 | Provider ohne Quota-Auskunft | Kein Fehlalarm | Nur geprüft, wenn `freeBytes > 0` | ✅ |
| H4 | Sehr große Videos, Gerät fast voll | Kein Absturz | Vorprüfung summiert die Zielgrößen vor dem ersten Transfer | ✅ |

## I. Medien-Sonderfälle

| # | Szenario | Bewertung | Hinweis |
|---|---|---|---|
| I1 | HEIC / JPG / PNG gemischt | ✅ | Erweiterung kommt aus `asset.title` |
| I2 | Videos | ✅ | `RequestType.video` bzw. `common` |
| I3 | Live Photos / RAW (DNG+HEIC-Paar) | ⚠️ | Es wird **ein** Asset exportiert; die Paar-Hälfte kann je nach Exportpfad fehlen |
| I4 | Screenshots, Panoramen, Zeitlupe | ✅ | Als normale Assets behandelt |
| I5 | Versteckte Fotos | ⚠️ | Erscheinen im Picker; Verhalten beim Export backend-abhängig |
| I6 | Zwei Fotos mit identischem Dateinamen | ✅ | `taken`-Desambiguierung über Asset-ID |
| I7 | 30 000 Fotos | ⚠️ | Scan läuft in 100er-Batches mit Fortschritt; Dauer und Speicherbedarf des Zustands sind nicht begrenzt |

## J. Darstellung & Eingaben

| # | Szenario | Bewertung | Hinweis |
|---|---|---|---|
| J1 | Hell/Dunkel während der Nutzung umschalten | ✅ | `systemBrightnessProvider` live |
| J2 | Palette wählen, dann System auf Dunkel | ✅ | **Nachgetragen 2026-09-05:** Getrennte Hell-/Dunkel-Paletten gibt es nicht mehr. Es gibt **eine** Palette; sie bringt beide Farbsets mit und `appThemeProvider` wählt das Set nach `systemBrightnessProvider`. Der Umschaltfall ist damit derselbe Code-Pfad, nur mit anderer Helligkeit |
| J3 | Jede Palette auf Lesbarkeit | ✅ | WCAG AA ≥ 4.5:1 in 8 Paletten × 2 Modi × 7 Kombinationen, per Test abgesichert |
| J4 | Sprache umschalten, während ein Sync läuft | ⚠️ | Laufende Logs mischen Sprachen (kosmetisch) |
| J5 | Aufgabenname mit Emoji / 200 Zeichen | `LengthLimitingTextInputFormatter(80)` im Wizard (iOS + Windows), ohne Zähler-UI. | ✅ |
| J6 | Zielordner mit Leerzeichen | ⚠️ | Wie D10 — keine Bereinigung |
| J7 | Sehr große Systemschrift (Dynamic Type) | ✅ | **Ursprünglicher Befund war falsch und ist zurückgenommen.** `Text.textScaler` übernimmt standardmäßig `MediaQuery.textScalerOf(context)` — feste `fontSize`-Werte skalieren also mit. Explizit abgeschaltet wird nirgends (`TextScaler.noScaling`: 0 Treffer). Feste Höhen um Text: keine gefunden (nur 1px-Trennlinien und scrollbare Log-Bereiche) |

## K. Daten & Mehrgeräte

| # | Szenario | Bewertung | Hinweis |
|---|---|---|---|
| K1 | App löschen und neu installieren | ⚠️ | Mirror-Zustand liegt in `Application Support` → weg. Cloud bleibt; erster Lauf adoptiert über `adoptOrphans` |
| K2 | Zweites Gerät, gleiches Cloud-Ziel | ⚠️ | Dateinamen können kollidieren (`IMG_0001.HEIC` existiert auf beiden Geräten). Name+Größe trennt sie jetzt korrekt — aber beide Geräte halten denselben Ordner für „ihren". **Nachgetragen 2026-09-05:** `SyncLockService` verhindert, dass beide **gleichzeitig** in denselben Zielordner spiegeln; Konflikte werden per 3-Way-Abgleich als Zeitstempel-Kopie behalten statt überschrieben |
| K3 | Upgrade von einer Version mit globalem Mirror-Zustand | ✅ | Nur `blocked`/`adopted` werden migriert, nie `items`/Tombstones |
| K4 | Systemuhr verstellt | ⚠️ | Konflikt-Auflösung nutzt Modtime; 60 s Toleranz |

---

## Empfohlene Reihenfolge für den Praxis-Test

Zuerst die Datenverlust-Pfade, weil sie irreversibel sind:

1. **D3/D4** — Aufgabe auf „Zuletzt hinzugefügt" (oder „Zuletzt gelöscht") anlegen, syncen, 30+ Tage warten **oder** den Effekt schneller provozieren: Album wechseln und erneut syncen. Prüfen, ob in der Cloud Dateien verschwinden.
2. **G3** — Fotozugriff auf „Auswahl …" mit wenigen Fotos setzen, dann einen Spiegel-Sync laufen lassen.
3. **E3** — Sync mit vielen großen Dateien starten, „Abbrechen" drücken, dann sofort erneut „Sync": Erwartet wird die Meldung „Es läuft bereits eine Synchronisierung", obwohl „Abgebrochen" angezeigt wurde.
4. **D5/D6** — Alben in umgekehrter Reihenfolge antippen, speichern, dann die Aufgabe bearbeiten: prüfen, ob adoptierte Cloud-Dateien erneut geladen werden.
5. Danach die ✅-Pfade als Regression (A1–A4, B1–B2, C1, E1–E2, F1–F3, H1–H2).

---

## Was ich **nicht** prüfen konnte

- Laufzeitverhalten auf einem echten Gerät (kein Simulator, kein Flutter-SDK in dieser Umgebung).
- Backend-spezifisches Verhalten einzelner rclone-Provider (Sonderzeichen in Pfaden, Server-seitiges Kopieren).
- Ob `flutter analyze` / `flutter test` aktuell grün sind — der Lauf mit deinem Workflow-Update wurde bei „Set up job" abgebrochen, bevor er startete.
  **Nachgetragen 2026-09-05:** Beide Workflows laufen inzwischen bei jedem Push
  und sind auf `main` @ `3139d5b` grün (Windows-Lauf 33987370958, iOS-Lauf
  33987370983): analyze 0 Fehler/0 Warnungen, Build, Tests. Die Einzelbefunde
  dieses Katalogs wurden dadurch **nicht** neu geprüft.
