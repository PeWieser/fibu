# Fibu — Szenario- & Testmatrix (iOS, aktueller Build)

> Stand: `main` @ `a92b937` + aktueller Lauf. Alle Befunde sind Code-Audits +
> Geräte-Logs des Test-Devices („meegaa"/„meewgaa"). Zeilen „[fix]" waren echte Fehler,
> die in genau diesem Zug behoben wurden.

## 1. Erststart / Onboarding

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 1.1 | Kaltstart ohne Konfig | Onboarding 3 Schritte: Willkommen → Cloud verbinden → Zugriff erlauben | ✅ geht |
| 1.2 | Foto-Berechtigung verweigern | „Loslegen" deaktiviert, Hinweis-Text + Dialog mit „Systemeinstellungen öffnen"; Onboarding kann nicht abgeschlossen werden | ✅ |
| 1.3 | Engine-Erstinit | `librclone engine bereit`, Logdatei `<Dokumente>/fibu.log` entsteht | ✅ |
| 1.4 | (fix) settings.json/tasks.json lagen in Documents | Nutzer-Ordner zeigte Klitsch-Dateien | ✅ jetzt `Library/Application Support` (privat), rclone.conf ebenfalls migriert |
| 1.5 | (fix) Launch-Screen war immer weiß | Jetzt `systemBackgroundColor` → adaptiv Hell/Dunkel | ✅ |

## 2. Cloud-Laufwerke (Remotes)

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 2.1 | Remote anlegen, falsche Zugangsdaten | „Verbindung testen" (echte rclone-Prüfung) schlägt fehl mit Provider-Text (z. B. MEGA `couldn't login`), Hinzufügen bleibt blockiert | ✅ |
| 2.2 | Remote anlegen, korrekte Zugangsdaten (MEGA/S3/WebDAV/SFTP/FTP/generisch) | Test ok → Add entsperrt → Config landet richtig obskuriert (doppeltes Obscuring entfernt) | ✅ nach Fix |
| 2.3 | OAuth-Provider (Google Drive/OneDrive/Dropbox) | Browser-Autorisierung → Token → Test ok → Anlegen | ✅ |
| 2.4 | Schlüsselbund-Autofill (iOS) | Username/Passwort-Felder in AutofillGroup, finishAutofillContext nach Erfolg; Zugang wird pro Provider-Typ aus Keychain vorgeschlagen („user @ host") | ✅ |
| 2.5 | (fix) Remote löschen | Swipe wischen (rot+Mülleimer) → kein Trash mehr; stattdessen Tap → Aktionsblatt „Trennen" | ✅ |
| 2.6 | Remote löschen, den ein Task noch benutzt | Sync danach: „didn't find section in config file" → UI zeigt jetzt freundlich `remoteNotFoundHint`, statt generischem „kein Internet" | ✅ |
| 2.7 | Mehrere Remotes | Liste zeigt je Remote: Typ, Speicher x von y (oder „n. v." bei Providern ohne about) + Fibu-Beleg, Tap → Aktionsmenü | ✅ |
| 2.8 | rclone coverage | Alle rclone-Backend-Typnamen via Registry (inkl. `s3-*` → `s3`, `gcs → google cloud storage`, `1fichier → fichier` Aliase) | ✅ |

## 3. Aufgaben (Tasks)

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 3.1 | Kaltstart mit bestehenden Tasks | Liste zeigt kurz Lade-Indikator, nie Flash-„Leerzustand" | ✅ |
| 3.2 | Task anlegen ohne Album-Wahl (Medien-Tab) | „Weiter" deaktiviert + Fehlermeldung; leere Alben tauchen nicht auf | ✅ |
| 3.3 | Task umbenennen / Quell-Auswahl ändern | Inline im Detail (Name + Alles/Fotos/Videos/Alben), „Fertig" speichert sofort | ✅ |
| 3.4 | Task bearbeiten via Detail | „Bearbeiten" toggelt in-place (kein Wizard-Dialog in iOS); Löschoptionen existieren nur dort | ✅ |
| 3.5 | Löschensymbole in Listen | weg (Task- & Remote-Listen ohne Dismissible/Trash-Icons) | ✅ |
| 3.6 | Ziel-Cloud-Ordner löschen | Nur im Bearbeiten-Modus; Typ-zum-Bestätigen-Dialog (GitHub-Stil, exakter Pfad) → rclone `operations/purge` | ✅ |
| 3.7 | Task-Wizard Zielordner-Standard | `fibu-backup` (wird beim ersten Sync angelegt / wiederverwendet) | ✅ |

## 4. Sync-Verhalten

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 4.1 | Symmetrische Medien-Mirror (Manifest-only) | Scan → Upload nur neuer/geänderter Dateien (On-Demand-Export), Download Cloud-only → in Mediathek importiert, Tombstones geschrieben | ✅ |
| 4.2 | Wiederholter Lauf ohne Änderungen | kurz „Alles aktuell — nichts zu übertragen" | ✅ |
| 4.3 | Lokales Löschen | Pfad verschwindet aus `mirror_state` → Tombstone → Remote-Papierkorb/hart-Delete; geloggt „lokal gelöscht → als Tombstones propagiert" | ✅ |
| 4.4 | Remote gelöscht | => Jetzt auch in der lokalen Mediathek gelöscht (iOS-System-Blöttchen), denn 2-Wege-Spiegelung = symmetrisch. Ablehnung blockiert den Pfad (kein Re-Upload) | ✅ neu |
| 4.5 | Gleiches Foto auf 2 Geräten | Eröffnet sich aus Modtime (neuer gewinnt) — keine Ping-Pong-Duplikate | ✅ |
| 4.6 | Mirror/FS-Ordner (nicht Medien) | weiterhin persistent lokaler Provider (bisync-konform) | ✅ |
| 4.7 | Abbruch mitten im Mirror | Jetzt: isCancelled-Hook je Phase bricht sauber ab, Logs zeigen Bruch an | ✅ neu |
| 4.8 | Offline-Start | Banner „Offline"; Queue blockiert, friendly error im Log/status | ✅ |
| 4.9 | Nur-Mobilfunk (globales WLAN-only) | Task blockiert mit cellularSyncBlockedNotice (Scheduler + interactives Sync) | ✅ |
| 4.10 | Sync-Queue doppelt anstoßen | Guards verhindern Doppelstart | ✅ |

## 5. Anzeige / Dashboard

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 5.1 | Fehlerwhanzeige | freundliche Texte (offline/auth/quota/remote fehlt) statt Brut-Json | ✅ |
| 5.2 | Fortschritt | Theme-Akzent-Farbe, „x von y Dateien", jetziges Datei, ETA nur wenn sinnvoll | ✅ |
| 5.3 | Speicher-Karte | Ein Balken: Fibu-Anteil themensatt, anderer belegter Platz blass, frei adaptiv; 1 Zeile Text | ✅ vereinfacht |
| 5.4 | Offline-Banner | erscheint/verschwindet live (`networkStatusProvider`) | ✅ |

## 6. Tastatur & Bedienung

| # | Szenario | Erwartung | Status |
|---|----------|-----------|--------|
| 6.1 | Tipp außerhalb eines Textfeldes | Tastatur geht weg (globaler GestureDetector) | ✅ |
| 6.2 | Wizard-Felder | AutofillGroup (Username/Passwort) + next/done | ✅ |

## Bekannte Ecken (bewusst dokumentiert)
- **iOS-System-Blatt beim Libraries-Delete** (PhotoKit hat immer die Apple-Bestätigung) — gewollt.
- **Manifest-only Neuaufsetzung** (Zustand weg): erster Lauf spiegelt von Neuem (controllerklar: kein Datenverlust, nur Zeitaufwand).
- Two-way Delete remote→lokal löscht aus der Mediathek — das ist der explizite Normativwunsch.
- MEGA hat kein `about` → Quota „n. v." ist KORREKT (kein Fehler).
