# Fibu — Arbeits-Log (Session)

---

## 2026-08-24 — Natives Liquid Glass (iOS 26+), darunter unverändert

### App (Flutter + UIKit)
- Neuer Channel `fibu/liquid_glass` + Platform-View `fibu/liquid_glass_view`.
- Echtes **UIGlassEffect** per Runtime-`NSClassFromString` (kein Hard-Link →
  kompiliert auch mit älteren Xcode-SDKs; aktiv nur ab iOS 26).
- Tab-Bar: transparent + Glass-Streifen dahinter (iOS 26+); iOS &lt; 26 opakes surface.
- Nav-Bars (Dashboard/Tasks/Settings): transparenter Hintergrund ab iOS 26.
- Karten/Banner: `LiquidGlassPanel` / `LiquidGlassGroupedBox` (Status-Banner,
  Sync-Fortschritt); Fallback = bisherige Surface-Optik.

### Widgets
- Hintergrund ab iOS 26: natives UIGlassEffect via `UIViewRepresentable`.
- iOS 17–25: `containerBackground` + systemBackground (wie zuvor).
- iOS 15–16: klassisches background.
- Status-Glyph: Glass-Kreis ab 26, getönter Kreis davor.
- Deployment Target bleibt **15.0**.

### Nicht geändert
- Android/Windows-Optik, Design-Tokens, Geschäftslogik.

---

## 2026-08-24 — Setup-Hinweis gestaffelt, Sync-Banner ehrlich, Remote-Picker für Union/Crypt

### Dashboard Setup-Hinweis
- **0 Laufwerke + 0 Aufgaben** → nur „Laufwerk hinzufügen“ (kein „Aufgabe erstellen“ mehr daneben).
- **Laufwerk vorhanden, keine Aufgabe** → nur „Aufgabe erstellen“.
- Beides vorhanden → normales Dashboard. Reihenfolge bewusst: ohne Ziel wäre eine Aufgabe sinnlos.

### Sync-Banner (needsSync bleibt stehen)
- Bug: Gelbes Banner „Änderungen gefunden — Sync fällig“ blitzte kurz auf und sprang zurück auf grün „Alle Dateien synchronisiert“, obwohl lokal und remote nicht übereinstimmten.
- Ursache: `recomputeAndPush` setzte `needsSync` nur beim Übergang `ok → pending`. War der Status schon `pending`/`never`/`error`, wurde `needsSync` wieder `false`.
- Fix: Jeder Status außer `ok` hält `needsSync` dauerhaft; Fehler werden am neuen Task-Stand gemessen; `reportTaskRun` bewertet alle Tasks, nicht nur den zuletzt gelaufenen.

### Virtuelle Backends: Multiple-Choice statt Freitext
- Union, Crypt, Combine, Alias, Chunker, Compress: statt `drive1:pfad drive2:pfad` tippen erscheint eine Auswahl der bereits verbundenen Cloud-Laufwerke (Single bzw. Multi).
- Ohne Basis-Laufwerk: klarer Hinweis „Zuerst ein normales Cloud-Laufwerk verbinden“.
- `ProviderAuth.buildConfig` formatiert die Auswahl rclone-konform (`id:`, Union-Liste, Combine `driveN=id:`).

---

## 2026-08-23 — Letztes Backup sichtbar, ruhiger Balken, klügere Zielordner-Wahl, Widgets iOS-17-fix, ein Lizenz-Dokument

### Dashboard
- **„Letztes Backup: 23.08.2026, 12:15“** dezent unter dem Sync-Button
  (alle Plattformen; Tabellenziffern; ohne Aufgaben unsichtbar).
- **Mehr Luft im Leerzustand:** Abstand über dem Einrichtungshinweis,
  Aktionszeilen auf 52 pt mit großzügigerem Innenabstand.
- **Kein aufblitzender Balken mehr:** Blitz-Läufe (nichts zu übertragen)
  werden auf mindestens ~1,6 s sichtbare Ruhe gehalten — echte
  Übertragungen warten nie.
- **iPad:** Dashboard-Inhalt mittig auf max. 700 pt begrenzt; Banner-Text
  mit maxLines/Ellipsis gegen Abschneiden auf kleinen Geräten.

### Widgets (WICHTIG: iOS-17-Rendering-Fix)
- Seit iOS 17 verlangt WidgetKit die **containerBackground-API** — ohne sie
  zeigt das System nur einen Platzhalter („statischer Inhalt“!). Jetzt
  adoptiert (ein containerBackground an der Wurzel, Fallback für iOS 15/16).
- Platz besser genutzt: größere Icons/Typo in allen drei Größen.

### Task-Wizard
- **Zielordner-Vorauswahl:** Existiert `fibu-backup` im Root des Remotes →
  „Vorhandener Ordner“ mit genau diesem vorausgewählt; sonst „Neuer Ordner“
  (fibu-backup). Offline/Fehler → Standard bleibt.

### Rechtliches
- Standard-LicensePage (verwirrende Paketliste) ersetzt durch **ein einziges
  durchscrollbares Dokument**: freundliche Einordnung oben (MIT, rclone,
  Flutter, gomobile), darunter alle vollständigen Lizenztexte, rclone &
  gomobile zuerst; Lesebreite auf 680 pt begrenzt.

### Gerätekompatibilität (iPhone 6s/iOS 15 → iPhone 17/iOS 27, iPad)
- Deployment-Target überall 15.0 (Runner + Widget-Extension) — verifiziert.
- containerBackground nur ab iOS 17 (#available), Fallback davor.
- SafeArea überall; Banner/Zeilen mit Overflow-Schutz; iPad-Lesebreiten.

---

## 2026-08-23 — Einfache Sync-Verben, Offline-Gating, Zweisprachigkeits-Pass, Repo-Aufräumen, Doku (EN)

### Sync-Meldungen: einfache Verben
- Fortschrittstexte sind jetzt schlicht: **Überprüfen · Hochladen ·
  Herunterladen · Aufräumen · Löschen · Vorbereiten · Fertig** — keine
  Technik-Sätze, keine Dateinamen-Anhängsel, keine Emoji-Summen mehr.
  Zähler („x von y“) kommen weiterhin separat an.
- Abschluss: „Fertig — x hochgeladen · y heruntergeladen“ bzw.
  „Alles aktuell.“

### Offline-Gating
- „Cloud-Dateien durchsuchen“ ist offline ausgegraut (alle Plattformen),
  inkl. Tooltip/Label „Offline — keine Internetverbindung“.

### Zweisprachigkeit (kompletter Pass)
- **Provider-Feldlabels** (Registry, ~45 deutsche Labels) werden für die
  englische Oberfläche über `AppStrings.providerFieldLabel` übersetzt.
- Sprachauswahl „System (automatisch)“ lokalisiert (statt Enum-Hardcode).
- Datei-Metadaten (Vorschau): Name/Größe/Erweiterung/Kategorie/MIME/Datum
  sowie Format-Labels („JPG Bilddatei“ → „JPG image file“) DE/EN.
- Sichtbare Engine-Fehler zweisprachig: keine Job-ID, unbekannter Fehler,
  Foto-Berechtigung verweigert.
- Bewusst NICHT übersetzt: Diagnose-Log-Zeilen (technisches Artefakt).

### Repo-Aufräumen
- Entfernt: alle Probe-Screenshots im Root, `task.md`, `todo.md`,
  `walkthrough.md`, `test_report_style.md` sowie die veralteten
  Snapshot-Dokumente `ABLAUF_AUDIT`, `APPLE_AUDIT`, `CODE_AUDIT`,
  `IOS_AUDIT`, `TEST_MATRIX`, `UMSETZUNGSPLAN`.
- Neu: `docs/ARCHITECTURE.md` (englisch, aktuell) — Sync-Engines,
  Remote-Identitätsmodell, Widget-Pipeline, Hintergrund-Scheduling, CI.
- README überarbeitet (englisch, aktuell): Anmelden statt Verbindungstest,
  ein Status-Banner, Auto-Refresh, Widgets mit dynamischer App-Group,
  Cloud-Löschungs-Propagation, Album-Zuordnung, Task-Import, Lizenzen.

---

## 2026-08-23 — Widget-Fix für Sideloading, ehrliche Meldungen, Autofill-Komfort, Sofort-Prüfung

### Widget: App-Group dynamisch (iLoader & Co.)
- Sideload-Tools benennen App-Groups beim Signieren um → die hart codierte
  `group.com.example.fibu` fand nie den geteilten Container.
- Jetzt lesen **App und Widget-Extension** die tatsächlich provisionierte
  Group-ID zur Laufzeit aus dem Signierprofil (`embedded.mobileprovision`,
  Entitlements → `com.apple.security.application-groups`). Fallback bleibt
  die Original-ID. Voraussetzung bleibt: Das Tool muss App **und** Extension
  eine (gleiche) App-Group geben.

### Ehrliche Meldungen (Pseudo-Erfolge entfernt)
- Dashboard-Banner erscheint NICHT mehr, wenn keine Aufgaben konfiguriert
  sind — kein „Alle Dateien synchronisiert“ ohne ein einziges Backup.
- Widget (klein + groß): 0 aktive Aufgaben → „Noch keine Backup-Aufgaben“
  in Grau statt grünem „Aktuell“.
- Fortschritts-Panels waren bereits korrekt gegated (nur während Sync).

### Sync-Button erklärt sich selbst
- Solange `tasks.json` lädt: **Spinner + „Aufgaben werden geladen …“** im
  Button (Spinner statt Balken — unbestimmte, kurze Wartezeit ohne
  messbaren Fortschritt). Kein stummes Grau mehr.

### Schlüsselbund-Autofill: Tastatur klappt automatisch ein
- Befüllt AutoFill das Passwortfeld, während der Fokus im E-Mail-Feld
  liegt, ist die Eingabe komplett → Fokus wird nach 250 ms gelöst, die
  Tastatur verschwindet. Kein „Weiter → Fertig“-Getippe mehr.
  (Tippt der Nutzer selbst im Passwortfeld, passiert nichts.)

### Dashboard prüft sofort beim Öffnen
- `initState` + Tab-Wechsel auf Dashboard (`shellIndexProvider`-Listener)
  stoßen die Bedarfsprüfung (Mediathek-Zählung) und die Speicherstände
  sofort an — kein Warten auf den 10-s-Takt.

### Recherche: Löschbestätigung (PhotoKit)
- Ergebnis eindeutig: Drittanbieter-Apps können den System-Löschdialog
  **nicht** unterdrücken, auch nicht „einmalig bestätigen“ — keine API,
  kein Entitlement; gilt selbst für Assets, die die App selbst angelegt
  hat. iCloud-Fotos umgeht das nur, weil es die Systembibliothek selbst
  ist. Fibu bündelt deshalb alle Löschungen eines Laufs in EINEN Dialog.

---

## 2026-08-22 — Auto-Refresh statt Buttons, ein Status-Banner, Plus-Menü mit Remote-Import, Widget-Diagnose

### Automatische Aktualisierung (Buttons weg)
- Neuer `AutoRefreshService`: alle **10 s** (bzw. **20 s im Stromsparmodus**,
  iOS `lowPowerModeEnabled` via neuem `fibu/system`-Channel) werden Remotes,
  Quota und Sync-Bedarf aktualisiert — nur im Vordergrund, nur online, nie
  während eines Syncs. Fibu-Beleg (rekursive Listung) bewusst nur jeder
  6. Zyklus.
- Alle „Aktualisieren“-Buttons entfernt: Dashboard, Cloud-Laufwerke,
  Cloud-Explorer (Fehler-Retry bleibt).

### Ein Status-Banner
- Dashboard zeigt genau EIN ruhiges Banner, eine Zeile, nicht tappbar:
  **Grau** (offline) → **Akzent** (Sync läuft) → **Rot** (Fehler) →
  **Grau** (abgebrochen) → **Orange** (Sync fällig) → **Grün** (aktuell).
- Separater Offline-Hinweis + „Aktivitätsprotokoll anzeigen“-Zeile entfernt
  (Logs weiterhin unter Einstellungen → Diagnose-Log).

### Sync-Button
- Zusätzlich zum Lade-Gate jetzt auch **offline ausgegraut** (alle Plattformen).

### Plus-Menü: verpassten Task-Import nachholen
- Neuer `remoteTaskCandidatesProvider`: erkennt auf allen Remotes Aufgaben aus
  `.fibu/config.json`, die lokal noch fehlen (Remote-Referenzen dynamisch
  aufgelöst).
- Tipp auf „+“: Gibt es Kandidaten → Apple-Action-Sheet („Neue Aufgabe“ /
  „Erkannte Aufgaben importieren (N)“); sonst direkt die Aufgaben-Maske.
- Neuer `RemoteTaskImportScreen`: Multiple-Choice-Auswahl, „Importieren“
  oben rechts (alle drei Plattformen).

### Anmeldefelder
- Demo-E-Mail-Platzhalter („name@beispiel.de“) entfernt.

### Widget-Diagnose
- `fibu/widget`-Channel meldet jetzt einen expliziten Fehler, wenn die
  App-Group `group.com.example.fibu` nicht provisioniert ist (häufigste
  Ursache beim Sideload-Signieren) → sichtbar im fibu.log statt still ok.

### Frage beantwortet (Cloud-Löschung ohne Fibu)
- Ja: Erkennung basiert auf Listing-Diff gegen den „nachweislich gesynct“-
  Zustand des letzten Laufs — kein Tombstone nötig. MEGA verschiebt in den
  Rubbish Bin, den rclone nicht listet → Datei gilt als gelöscht.

---

## 2026-08-22 — Cloud-Löschungen lokal, Album-Zuordnung beim Download, Quota-Auto-Refresh

### Mirror: Direkte Cloud-Löschungen kommen jetzt lokal an
- Vorher wurden in der Cloud gelöschte Dateien beim nächsten Lauf sogar
  **wieder hochgeladen** (lokal vorhanden + remote fehlt = „neu“).
- Neu (Virtual-Mirror-Engine, Schritt 0/3b): Ein Pfad, der beim letzten Lauf
  **nachweislich gesynct** war und jetzt ohne Tombstone remote fehlt, gilt
  als Cloud-Löschung → wird vom Upload ausgenommen und lokal über PhotoKit
  gelöscht (`deleteWithIds` — iOS zeigt immer den Systemdialog mit Vorschau).
- Lehnt der Nutzer im Systemdialog ab: Datei bleibt lokal, Pfad wird
  blockiert (kein erneuter Upload, kein erneutes Nachfragen).
- **Sicherheitsbremsen:** Leere Cloud-Liste oder >50 % „verschwunden“
  (≥10 Pfade) wird als Ausfall/Formatwechsel gewertet — nichts wird gelöscht.
- Zustands-Semantik gehärtet: `mirror_state.json` enthält nur noch
  **nachweislich gesyncte** Pfade (hochgeladen oder remote gesehen).
  Fehlgeschlagene Uploads werden erneut versucht und können nie fälschlich
  als „remote gelöscht“ gelten.
- Neue Fortschrittsphase „Übernehme Cloud-Löschungen“ (DE/EN).

### Downloads landen im richtigen Album
- `PhotoKitBridge.importIntoLibrary` ordnet Importe jetzt dem Album aus dem
  Cloud-Pfad (`Photos/<Album>/…`) zu: bestehendes Nutzer-Album per Name
  finden, sonst anlegen (`darwin.createAlbum`), dann `copyAssetToPath`.
  Vorher erschien alles nur unter „Zuletzt“.
- Gilt für Virtual-Mirror UND FS-Mirror-Importe; Fehler bei Smart-Alben
  werden geschluckt (Import selbst bleibt erfolgreich).

### Cloud-Speicheranzeige aktualisiert sich selbst
- Nach jedem Sync-Lauf (Queue, Einzel-Task, auch bei Abbruch mit Teil-Upload)
  werden `primaryQuotaProvider`, `remoteQuotaProvider` und
  `remoteFibuUsageProvider` invalidiert — die Dashboard-Speicherkarte lädt
  frisch, ohne Umweg über Cloud-Laufwerke.
- Der Dashboard-„Aktualisieren“-Button invalidiert dieselben Provider.

---

## 2026-08-22 — Sync-Button-Gate, Sync-Bedarfs-Prüfung, Widget-Fixes, schlanke Provider-Liste, Rechtliches

### Dashboard
- **Sync-Button ausgegraut**, bis `tasks.json` fertig gelesen ist
  (`tasksLoadedProvider`) — ein zu früher Tipp meldete fälschlich
  „keine aktiven Aufgaben“ (alle drei Plattformen).
- **„Aktualisieren“ prüft jetzt Handlungsbedarf:** Mediathek-Zählung vs.
  letzter Sync-Stand (`WidgetStatusNotifier.recomputeAndPush`). Feedback
  sagt klar „Alles aktuell“ oder „Änderungen gefunden — Sync fällig“.
- **Status-Banner dreistufig:** Grün (aktuell) → **Orange** (`theme.warning`,
  „Änderungen gefunden — Sync fällig“) → Rot (Fehler). Der Ruhezustand lügt
  nicht mehr, wenn seit dem letzten Sync fotografiert wurde.

### Homescreen-Widgets
- **Phantom-Route beim Widget-Tap behoben:** `FlutterDeepLinkingEnabled=false`
  — Flutter pushte aus `fibu://open` eine Dashboard-Kopie mit Zurück-Button.
  Jetzt öffnet der Tap die App einfach im aktuellen Zustand.
- **Frische Daten:** Widget-Status wird zusätzlich bei App-Resume
  (`didChangeAppLifecycleState`) und nach JEDER Task-Änderung (`_saveTasks`)
  neu berechnet und gepusht — nicht mehr nur beim Kaltstart.
- **Automatische Hintergrund-Prüfung:** Der 2-Stunden-Workmanager-Lauf ruft
  jetzt `WidgetStatusNotifier.refreshInBackground()` auf. Dafür registriert
  der AppDelegate die Fibu-Channels (`fibu/rclone`, `fibu/widget`,
  `fibu/keychain`) auch im Workmanager-Registrant-Callback — vorher fehlten
  sie in Hintergrund-Isolates komplett (auch der Hintergrund-Sync konnte so
  nie rclone erreichen).
- Hinweis: Bei seitgeladenen, selbstsignierten IPAs muss die App-Group
  `group.com.example.fibu` beim Signieren erhalten bleiben, sonst sieht die
  Widget-Extension die Daten nicht (Platzhalter-Inhalt).

### Anbieter-Auswahl
- Beschreibungszeilen („bekannter Cloud-Speicherdienst“ …) aus der Liste
  entfernt — nur noch der Anbietername. Die Suche durchsucht die
  Beschreibungen weiterhin.

### Rechtliches
- **Ja, Lizenz-Hinweise sind nötig** (MIT/BSD/Apache verlangen die Beilage
  der Lizenztexte). Neu: Sektion „Rechtliches“ ganz unten in den
  Einstellungen → „Open-Source-Lizenzen“ öffnet die vollständige,
  automatisch generierte Liste (LicenseRegistry aller Dart-Pakete).
- rclone/librclone (MIT) und gomobile (BSD-3) sind statisch gelinkt und
  werden deshalb in `main()` manuell in die LicenseRegistry eingetragen.

---

## 2026-08-22 — Upload-Fixes, dynamisches Backup-Ziel, Schlüsselbund-Login, „Anmelden“, Zweisprachigkeit

### Upload-Ablauf Punkt für Punkt geprüft & gefixt
- **Erst-Sync gegen leeres Remote:** `_listRemoteRecursive` (FS- und
  Virtual-Mirror-Engine) hat den kompletten Job abgebrochen, wenn der
  Zielordner (z. B. `fibu-backup/Photos`) remote noch nicht existierte
  („directory not found“). Jetzt: gezielt als **leere Cloud-Seite** behandelt
  — der Ordner entsteht beim ersten Upload. Alle anderen Fehler bleiben laut.
- **Include-Filter case-insensitiv:** iOS-Dateien heißen `IMG_0001.HEIC`/`.JPG`
  (Großschreibung); die kleingeschriebenen Regeln (`*.jpg`, `*.heic`, …)
  matchten beim inkrementellen `sync/copy` **nichts** → 0 Dateien übertragen.
  Fix: `'IgnoreCase': true` im `_filter`.
- **Multi-Remote (mirrorAll):** `_syncSingleTask` synchronisiert jetzt
  nacheinander auf **alle** verknüpften Ziele, nicht nur das erste.
- **Vorprüfung mit Klartext:** Fehlt das Ziel in der Registry, scheitert der
  Lauf sofort mit lokalisiertem Hinweis statt rclone-Jargon
  („didn't find section in config file“).

### Backup-Ziel dynamisch (Task-Übernahme „nicht gefunden“ behoben)
- `.fibu/config.json` referenzierte Remote-IDs des **anderen** Geräts —
  nach Import zeigte die Aufgabe auf ein „nicht gefundenes“ Ziel.
- Auflösung jetzt dynamisch in `SyncConfigService.resolveLinkedRemotes`:
  **ID → Anzeigename → Provider-Typ → Fallback auf das Remote, auf dem die
  Config gefunden wurde.** Die Benennung ist damit egal; es zählt der Anbieter.
- Config-Format erweitert: `linkedProviders` (rclone-Backend-Typ je Remote)
  wird beim Schreiben mitgegeben — andere Geräte matchen über den Provider.
- `importTasks` ersetzt Aufgaben mit gleicher ID statt sie zu duplizieren
  (erneuter Import nach Neu-Verbinden erzeugt keine Doubletten mehr).

### Apple-Schlüsselbund / Autofill repariert
- Regression: `AutofillHints.newPassword` ließ iOS die Maske als
  **Registrierung** einstufen → keine E-Mail-/Passwort-Vorschläge mehr.
  Zurück auf `AutofillHints.password` (Login-Formular, Schlüsselbund-Zugänge).
- Verstecktes 0×0-URL-Feld aus der `AutofillGroup` entfernt — es störte die
  Feld-Klassifizierung; die Domain-Zuordnung macht das Associated-Domains-
  Entitlement.

### Wording & Zweisprachigkeit
- „Verbindung testen“ → **„Anmelden“ / „Sign In“** (inkl. Fehler-/Hinweistexte).
- Dashboard-Job-Status (Starting/Preparing/Completed/Cancelled …) und alle
  Sync-Fortschrittstexte der Engine (Vorbereitung, Lade hoch, Löschprotokoll,
  Mirror abgeschlossen, Alles aktuell …) sind jetzt DE/EN — Engine-Schichten
  ohne Ref lesen `AppStrings.current` (vom `stringsProvider` aktuell gehalten).
- Zeitplan-Beschreibung lokalisiert (`scheduleDescriptionFor`), Speicherdetails-
  Dialog, Aktivitätsprotokoll-Titel, Datei-/Bild-Vorschau-Fehler, Fallback-
  Anmeldefelder — alles zweisprachig.

---

## 2026-08-22 — Detail-Pass (Typografie, Kontrast, Navigation, Wortwahl)

### Typografie & Kontrast („Steve-Jobs-Auge")
- **Versalien-Header entfernt:** Alle Cupertino-Section-Header (Einstellungen,
  Cloud-Laufwerke, Task-Detail, Sync-Log-Dialog) sind jetzt Title Case, 13 pt,
  sekundär, `letterSpacing 0.3` — statt schreiender `toUpperCase()`-17pt-Header.
  Neuer Helfer `IosTheme.sectionHeader(...)`.
- **Tabellenziffern** (`FontFeature.tabularFigures()`) für Fortschritts-%
  (alle drei Plattform-Panels) und die Speicherkarten-Bytes — Zahlen tanzen
  beim Sync nicht mehr.
- **Kontrast verifiziert:** `textSecondary` liegt bei ~5,2:1 (hell) bzw. ~6,9:1
  (dunkel) auf Surface/Canvas — über der 4,5:1-Schwelle.

### Navigation (ein Modell)
- „Laufwerk hinzufügen" im Setup-Hinweis wechselt jetzt — wie „Aufgabe
  erstellen" — in den Ziel-Tab (Einstellungen) und öffnet dort die
  Cloud-Laufwerke, statt einen Screen über die App zu legen.

### Wortwahl (Nutzen statt Inventur)
- Empty-States sagen, was man gewinnt: „Deine Fotos und Dateien sind dann
  sicher — auch wenn du dein Gerät verlierst." / „Deine Fotos sichern sich
  dann automatisch …".
- „Erste Schritte"-Label entfernt (die Aktionen sind selbsterklärend).
- **Echte typografische Anführungszeichen:** ASCII `"` → „…“ (deutsch) bzw.
  „…" → “…” (englisch) in allen Dialogen.

---

## 2026-08-22 — Setup-Hinweis tappbar, „+"-Hinweise raus, Dead Code bereinigt

### Dashboard-Setup-Hinweis ist jetzt tappbar
- Der Hinweis zeigt nur noch die **fehlenden** Aktionen als Zeilen (Verben):
  - „Laufwerk hinzufügen" → öffnet direkt Cloud-Laufwerke (push).
  - „Aufgabe erstellen" → wechselt in den Aufgaben-Tab (`shellIndexProvider`).
- Überschrift „Erste Schritte" + Icon; Zeilen haben 44 pt Trefferfläche.

### Leichte „+"-Hinweise entfernt
- Tasks- und Cloud-Laufwerks-Leerzustand zeigen nur noch Icon + Titel +
  Beschreibung — kein „Tippe oben rechts auf +" mehr (das „+" ist oben rechts
  bereits sichtbar und selbsterklärend).

### Dead Code bereinigt
- Alle Onboarding-Strings (`app_strings.dart`) entfernt (Welcome, Cloud
  verbinden, Features, Presets, „Zugriff erlauben" …) sowie `openSystemSettings`,
  `systemLanguageSubtitle` und die toten `savedCredentials*`-Strings.
- `AppSettingsData.onboardingCompleted` + `SettingsService.setOnboardingCompleted`
  komplett entfernt (Feld war nach dem Onboarding-Aus verwaist).
- README-Verzeichnisbaum aktualisiert (kein `onboarding/` mehr, `SecureStore`
  statt `CredentialVault`).

---

## 2026-08-22 — Kein Onboarding mehr, Berechtigung erst bei Bedarf, Setup-Hinweis

> Richtungswechsel: Der „eine Seite“-Ansatz (voriger Eintrag) wurde verworfen.
> Die App startet jetzt **ohne Onboarding** direkt in der Shell.

### Onboarding entfernt
- `main.dart` startet direkt in der Shell; `onboarding_screen.dart` +
  `onboarding_controller.dart` gelöscht.
- Fotozugriff wird **erst bei Bedarf** angefragt: im Task-Wizard beim Laden
  der Alben (`PhotoManager.requestPermissionExtend()` in `_loadAlbums`).

### Dashboard: Setup-Hinweis statt leerer Übersicht
- Solange Cloud-Laufwerk und/oder Aufgabe fehlen, zeigt das Dashboard einen
  ruhigen Hinweis: beides fehlt / nur Laufwerk / nur Aufgabe. Erst wenn beides
  da ist, erscheint die normale Übersicht.

### Große Buttons entfernt, leichte „+"-Hinweise
- Tasks-Leerzustand: großer „Aufgabe erstellen“-Button → Hinweis „Tippe oben
  rechts auf +“.
- Cloud-Laufwerke: großer „Laufwerk hinzufügen“-Button → Hinweis; Windows/
  Android haben jetzt ein „+“ in der CommandBar/AppBar (iOS hatte es schon).

---

## 2026-08-22 — Onboarding: eine Seite, ein Button

- Onboarding radikal vereinfacht: eine Seite, ein Hinweis, ein Button
  „Zugriff erlauben“. Kein Karussell, kein Welcome, kein Cloud-Connect,
  kein Skip.
- Nach Erteilen: Häkchen + Haptik → kurze Bestätigung → sanft ausblenden →
  direkt in die App.
- Nach Ablehnen: Button wird zu „In den Einstellungen erlauben“ (iOS zeigt
  den nativen Prompt nicht erneut) — kein Dead-End, keine weitere Seite.
- Desktop (ohne System-Mediathek): Button schließt das Onboarding direkt ab.

---

## 2026-08-22 — Systemsprache, Task-Erkennung, Sync-Crash, Zweittexte

### Systemsprache
- `LocaleModeNotifier` startet jetzt mit `system` statt hart `de` — die App
  folgt der Gerätesprache, bis der Nutzer explizit umstellt.

### Erkennung vorhandener Tasks (Remote)
- **Ursache gefunden:** Der Add-Wizard gab nach dem Anlegen den **Anzeigenamen**
  („Megaaa“) zurück, obwohl rclone nur die interne Kennung (`fibu-f1df9551`)
  kennt. `checkRemoteForConfig`/`catFile` liefen dadurch gegen eine
  nicht existente Sektion → „didn't find section in config file“ (Status 500).
- Der Wizard gibt jetzt die Registry-ID zurück; die Erfolgsmeldung und der
  Import-Dialog lösen daraus den Anzeigenamen auf.

### Sync-Crash „Cannot change an unmodifiable set“
- `_loadVirtualState` lieferte beim ersten Lauf `const`-Sets — die Virtual-Mirror-
  Engine mutiert diese (`blockedRels.add`, `adoptedRels.removeWhere`). Jetzt
  growable (kein `const`).

### Zweittexte entfernt
- Cloud-Laufwerksliste: Provider-Typ unter dem Namen entfernt (nur Name +
  Speicherinfo). Sprach-Zeile und Sprach-Picker ohne Erklär-Untertitel.
  Wizard-Remote-Chips zeigen nur noch den Namen.

### Apple-Schlüsselbund
- Passwortfelder nutzen `AutofillHints.newPassword` → iOS bietet an, den Zugang
  zu **speichern** (statt nur auszufüllen). Hinweis: Das **Erkennen** fremder
  Domains (mega.nz, drive.google.com) verlangt aktives Associated-Domains-
  Entitlement im Provisioning-Profil UND einen im iCloud-Schlüsselbund des
  Nutzers gespeicherten Zugang — das kann die App nicht erzwingen.

---

## 2026-08-22 — Nur Apple-Schlüsselbund, passende Anmeldemaske je Provider

### Login
- Eigene „gespeicherte Zugänge“-Chips/Buttons und `CredentialVaultService` sind weg.
  Die Anmeldemaske ist nur noch das Formular. Speichern/Vorschlagen macht der
  **Apple-Schlüsselbund** (AutofillGroup + `finishAutofillContext` + Associated
  Domains).
- Associated Domains jetzt inkl. der konkreten Hosts: `mega.nz`,
  `drive.google.com`, `accounts.google.com`, `www.dropbox.com`, `login.live.com`,
  `proton.me`, Wasabi, Backblaze, …
- Unsichtbares URL-Feld trägt die Provider-Domain in den Autofill-Kontext.

### Jeder rclone-Anbieter hat seine Maske
- Wizard liest `RcloneProviderRegistry` (AuthType + Felder), nicht mehr
  Namens-Heuristik. **Proton Drive** wurde fälschlich als OAuth erkannt
  (`contains('drive')`) — jetzt Benutzer/Passwort/2FA.
- MEGA: E-Mail + Passwort. S3-Varianten: Access Key / Secret / Endpoint +
  korrekter `provider=`-Wert. WebDAV/SFTP/SMB: Host + User + Pass. Wrapper
  (Crypt, Union, …): ihre eigenen Felder. OAuth: ein Anmelde-Button, kein
  Passwortfeld.

### Jobs-Standards, die Code wirklich halten kann
- Onboarding: sichtbares „Später einrichten“, Foto-Berechtigung blockiert
  den Start nicht mehr (kommt, wenn eine Medien-Aufgabe sie braucht).
- Nutzungsbeschreibungen erklären den Nutzen, nicht „App benötigt Zugriff“.
- Keine Ausrufezeichen in Erfolgsmeldungen. Version in Einstellungen
  kopierbar. Anzeigename wird beim Anbieter-Tipp vorausgefüllt.

### Was diese Liste *nicht* ehrlich abhaken kann
App-Store-Screenshots, ICE-Test, Crash-free 99,9 %, VoiceOver auf Gerät,
Mutter-Test. Das wäre lügen. CI bleibt der Compile-Check.

---

## 2026-08-21 — Remote-Identität, Schlüsselbund nativ, Task-Bearbeitung

### Remote-Registry (Identität ≠ Anzeigename)
- **Problem:** Aufgaben hingen am frei gewählten rclone-Sektionsnamen. Remote
  gelöscht/neu angelegt (oder umbenannt) → „didn't find section in config file“.
- **Neu:** `RemoteRegistryService` (`remotes.json` im privaten App-Support).
  Jedes Remote bekommt eine stabile interne Kennung (`fibu-xxxxxxxx`), die als
  rclone-Sektionsname dient. Der Nutzername ist ab jetzt ein **reiner
  Anzeigename** (umbenennbar ohne rclone, Aufgaben-Referenzen bleiben stabil).
- **Provider-Typ wird echt gespeichert** (beim Anlegen; Alt-Sektionen per
  `config/get` adoptiert) — die alte Anzeige-Heuristik per Namenssuche
  (`name.contains('mega')`…) ist entfernt.
- Alt-Remotes werden beim ersten Start adoptiert (Kennung = bisheriger Name),
  Aufgaben laufen ohne Migration weiter.
- Laufwerksliste & alle Anzeigestellen (Explorer, Wizard-Chips, Task-Detail)
  zeigen Anzeigename + echten Provider; verwaiste Referenzen bekommen ein
  „(nicht gefunden)“-Badge und können im Wizard bewusst neu zugeordnet werden.
- Trennen-Dialog warnt, wenn Aufgaben das Laufwerk noch nutzen; Trennen räumt
  Registry + OAuth-Tokens auf. Doppel-Delete-Bug (Dialog + Aufrufer) behoben.

### Apple-Schlüsselbund ohne Plugin
- `flutter_secure_storage` komplett entfernt. Neuer `SecureStore`: iOS/macOS →
  nativer Keychain via `fibu/keychain`-MethodChannel (Security.framework,
  `AfterFirstUnlockThisDeviceOnly`), andere Plattformen → private Ablage-Datei
  (gleiches Niveau wie rclone.conf). Vault + OAuth-Tokens nutzen SecureStore.
- **Associated Domains** (`webcredentials:`) für MEGA, Google, Dropbox,
  pCloud, Microsoft (live.com/microsoftonline.com), Box, Yandex, Backblaze
  (Apex + Wildcard) in Runner.entitlements → iOS-Autofill schlägt passende
  Zugänge vor und ordnet neu Gespeicherte den Domains zu.

### Task-Bearbeitung (Detail)
- Medien-Quelle bearbeitet man jetzt NUR über die Albumliste: Zähler je Album,
  leere Alben ausgeblendet, bisherige Auswahl vorgehakt; leere Auswahl =
  gesamte Mediathek. Abgewählte/verschwundene Alben bleiben sichtbar.
- **Sync-Modus nachträglich umschaltbar** (Inkrementell ↔ Spiegelung) mit
  Erklär-Footer. Wechsel auf Spiegelung markiert `_runVirtualMirrorSync` per
  Flag-Datei: bestehende Cloud-Dateien werden **adoptiert** statt alle in die
  Mediathek zu laden (adoptions-Liste im Mirror-State).

### Fix
- Widget-Extension-Compile-Fehler (unvollständiger Header-Block in
  `FibuWidget.swift`) korrigiert; `String.localizedDescription`-Fauxpas
  entfernt.


**Branch:** `arena/01a01152-fibu` (Stand `main` @ `3c3925f`)
**Datum:** 2026-08-17
**Fokus dieser Session:** Datei-Vorschau + Einbindung des rclone-Frameworks (kein `librclone_missing`-Fehler mehr).

---

## ✅ Was in dieser Session gemacht wurde

### 1. rclone-Framework vollständig ins iOS-Xcode-Projekt eingebunden

Damit der Laufzeitfehler `librclone_missing` **verschwindet**, muss `Rclone.xcframework` wirklich gebaut und mit der App verlinkt werden. Das war bisher **nicht** eingerichtet (die Datei war nur über `#if canImport(Rclone)` abgesichert, aber nie ins Projekt eingebunden).

**Geänderte Datei:** `ios/Runner.xcodeproj/project.pbxproj`

- ✅ **File-Referenz** `Rclone.xcframework` hinzugefügt (`Frameworks/Rclone.xcframework`).
- ✅ **Link-Phase** (Frameworks build phase): Framework wird in den Runner gelinkt → `canImport(Rclone)` wird `true`, der `librclone_missing`-Fehlerpfad wird kompiliert und die echte Engine genutzt.
- ✅ **Embed-Phase**: Framework wird in die App eingebettet (Code-Sign-On-Copy) → zur Laufzeit verfügbar.
- ✅ **`FRAMEWORK_SEARCH_PATHS`** in Runner **Debug + Release** ergänzt: `$(PROJECT_DIR)/Frameworks`.
- ✅ **Neue Build-Script-Phase „Build librclone (if missing)"** als erste Build-Phase des Runner-Targets: Baut das Framework automatisch (`ios/scripts/build_librclone.sh`) **nur wenn es fehlt**; wenn es vorhanden ist, wird übersprungen. Bei fehlenden Voraussetzungen bricht der Build mit einer klaren Meldung ab (statt stiller Laufzeitfehler).

**Ergebnis:** Beim nächsten iOS-Build auf einem Mac (mit Go ≥ 1.21, gomobile, Xcode) wird `Rclone.xcframework` automatisch erzeugt, verlinkt und eingebettet. Der `librclone_missing`-Fehler tritt danach nicht mehr auf. Bei bereits vorhandenem Framework wird nichts neu gebaut.

### 2. Datei-Vorschau an die echte rclone-Engine angeschlossen

Vorher zeigte die Bildvorschau **erfundene Metadaten** (`4032 × 3024 Pixel • 12.2 MP`) und die Audio-Vorschau eine **Fake-Wellenform** (`FLAC Lossless • 48.0 kHz`). Das ist behoben.

**Geänderte Datei:** `lib/features/dashboard/presentation/widgets/file_preview_dialog.dart`

- ✅ **Bilder werden jetzt wirklich geladen**: Über `FileViewerService.getLocalFile()` → `IosRcloneService.downloadToCache()` (`operations/copyfile`) wird die echte Datei aus der Cloud in den Cache geholt und mit `Image.file` angezeigt (inkl. Zoom via `InteractiveViewer`).
- ✅ **Lade- und Fehlerzustände** hinzugefügt (Spinner, „Datei konnte nicht geladen werden", Option „In Standard-App öffnen").
- ✅ **Fake-Metadaten entfernt**: Der erfundene Bild-Metadaten-Text ist weg.
- ✅ **Fake-Audio-Wellenform entfernt**: Audio/Video/Dokumente/Archive/Binärdaten laufen jetzt über die echte „In Standard-App öffnen"-Aktion (Download + System-Viewer / Quick Look auf iOS) statt über simulierte Player.
- ✅ **Text-Vorschau** nutzt bereits `catFile` (echter Inhalt) — unverändert funktionsfähig.

---

## 🔧 Weitere, von dieser Session betroffene Punkte

- **`docs/UMSETZUNGSPLAN.md`** wurde zuvor um den Abschnitt „0.5 Stand nach main-Merge" ergänzt (Dokumentation des PR #3).

---

## 🆕 Fortsetzung: 3 Punkte + CI (2026-08-17)

Basierend auf der Abstimmung (OAuth + Hintergrund-Scheduling + natives iOS-Design) zusätzlich umgesetzt:

### 3. Natives iOS-Design (SF Pro, Large Titles, Haptik)
- **Neu:** `lib/theme/ios_theme.dart` — zentrale `CupertinoThemeData`-Factory (SF-Pro-Textstile, Large-Title, `primaryColor` aus Sanzo-Wada-`AppThemeData`; Farbvarianten bleiben erhalten).
- **`main.dart`** nutzt im iOS-Zweig jetzt `IosTheme.build(...)` (ersetzt die Inline-Cupertino-Theme).
- **Neu:** `lib/core/utils/ios_haptics.dart` — native `HapticFeedback`-Helfer (light/medium/success/selection), nur auf iOS aktiv.
- **Dashboard (iOS):** natives **Large Title**, gruppierter Inhalt, Haptik bei Refresh/Sync/Abbrechen.
- **Tasks (iOS):** Large Title + Haptik beim „Neues Backup"-Button.
- **Einstellungen (iOS):** Large Title + Haptik bei Switches (WLAN-only, Theme, Dark Mode).

### 4. OAuth-Verdrahtung (Login-Flow)
- **Neu:** `lib/core/services/oauth_service.dart` — `flutter_web_auth_2` (`ASWebAuthenticationSession` auf iOS) + sichere Token-Ablage via `flutter_secure_storage` (Keychain). Callback-Scheme `fibuoauth://`.
- **Add-Remote-Wizard** (`cloud_drives_screen.dart`): Der OAuth-Button faked nicht mehr (vorher `setState(_isOAuthAuthorized = true)`), sondern ruft jetzt `_handleOAuthAuthorize()` auf → öffnet den echten Browser-Flow, zeigt Lade-/Fehlerzustand, speichert den Token.
- Der OAuth-Provider speichert den Token beim Hinzufügen des Remotes in der rclone-Config.
- **`ios/Runner/Info.plist`:** `CFBundleURLTypes` mit `fibuoauth` registriert.
- **⚠️ Wichtig:** Für einen *erfolgreichen* Login braucht es echte `client_id`/`client_secret` pro Anbieter (in `_buildOAuthUrl` steht aktuell ein `__CLIENT_ID__`-Platzhalter). Ohne diese Client-Credentials kann der Browser-Flow die Autorisierung nicht abschließen.

### 5. Hintergrund-Scheduling
- **Neu:** `lib/core/services/scheduler_service.dart` — `workmanager` (iOS `BGTaskScheduler` / Android `WorkManager`), `registerPeriodicTask` alle 2 h, plus `runScheduledSync()` das aktive Tasks aus `tasks.json` lädt und per `IosRcloneService` startet. Top-Level-`@pragma('vm:entry-point')`-Callback.
- **`main.dart`:** `SchedulerService.initialize()` beim Start.
- **`ios/Runner/Info.plist`:** `BGTaskSchedulerPermittedIdentifiers` (`workmanager.background.task`) + `UIBackgroundModes` (`fetch`, `processing`).
- **`ios/Runner/AppDelegate.swift`:** `WorkmanagerPlugin.setPluginRegistrantCallback` + `registerBGProcessingTask`.

### 6. rclone-Framework in der GitHub-Actions-CI
- **`.github/workflows/build-ios.yml`:** + `setup-go`, `go install gomobile/gobind`, `gomobile init`, und ein Step „Build librclone framework" der `ios/scripts/build_librclone.sh` ausführt → das `Rclone.xcframework` wird in CI erzeugt, bevor `flutter build ios` läuft. Die Xcode-Phase „Build librclone (if missing)" überspringt dann (Framework vorhanden) → kein `librclone_missing`-Fehler.

---

## 🆕 Fix: Swipe-to-Delete (2026-08-17)

- **Problem:** In `tasks_screen.dart` wurde `removeTask` **innerhalb von `confirmDismiss`** aufgerufen, während `confirmDismiss` zugleich `true` zurückgab. Das führt zum klassischen Dismissible-Fehler („A dismissed Dismissible widget is still part of the tree") und zu ruckeligem/falschem Verhalten beim Wischen.
- **Fix:** `confirmDismiss` fragt jetzt **nur** die Bestätigung ab (reiner Dialog); das Entfernen passiert in **`onDismissed`** nach abgeschlossener Animation. Angewendet für iOS- und Android-Dismissible. Die Bestätigungs-Dialoge (iOS/Windows/Android) entfernen selbst nichts mehr.
- **Test:** Neuer iOS-Widget-Test in `test/widget/tasks_screen_test.dart` („iOS swipe-to-delete confirms then removes task") — wischen, Dialog bestätigen, prüfen dass der Task nach der Animation entfernt ist.

---

## 🆕 Verfeinerung: OAuth-Credentials aus rclone + Design (2026-08-17)

- **OAuth-Credentials:** rclone liefert selbst Standard-`client_id`/`client_secret` (z. B. Google Drive). `IosRcloneService.getProviderClientCredentials()` liest diese aus `config/providers` (Options-Defaults). Der Add-Remote-Wizard nutzt sie jetzt für die Autorisierungs-URL statt des `__CLIENT_ID__`-Platzhalters. Ohne verfügbare Credentials erscheint eine klare Meldung.
- **Design-Verfeinerung (Dashboard iOS):** Leerzustand „Keine Backup-Laufwerke" ist jetzt ein **aktionsfähiger Leerzustand** mit CTA „Cloud-Laufwerke verwalten" (öffnet CloudDrivesScreen), nativer Cupertino-Button mit Haptik.
- **Haptik:** Task-Wizard speichert mit `medium`-Haptic auf iOS.

---

## 🆕 Tasks überarbeitet: Quell-Auswahl (Alben/Ordner) + Zielordner (2026-08-17)

**Aufgaben-Einrichtung grundlegend überarbeitet (iOS).**

### Datenmodell (`tasks_controller.dart`)
- `BackupTask` um `selectedAlbums` (List<String>) und `selectedFolders` (List<String>) erweitert.
- Persistenz (`toJson`/`fromJson`), `copyWith` und neue `sourceDescription` (menschenlesbar) ergänzt.
- `sourcePath` codiert die Auswahl: `photos:Album1|Album2`, `videos:…`, `all:…` oder `files:<Pfad1>|<Pfad2>`.

### iOS-Wizard (Schritt 0 = Quelle)
- **Zwei Reiter** statt des alten „Alles/Fotos/Videos/Ordner"-Segmentcontrols:
  - **„Fotos & Videos"**: listet alle lokalen Alben (PhotoManager) mit „Alle auswählen"-Umschalter + Einzelauswahl per Häkchen.
  - **„Dateien"**: listet zugängliche lokale Ordner mit „Alle auswählen" + Einzelauswahl.
- Neues State-Management (`_sourceTab`, `_albums`, `_selectedAlbums`, `_localFolders`, `_selectedFolders` + Ladezustände).

### iOS-Wizard (Schritt 1 = Ziel)
- **Zielordner klarer/verständlicher** als 3 deutliche Optionen:
  - **Hauptverzeichnis (Root)** – direkt ins Stammverzeichnis.
  - **Vorhandener Ordner** – durchsucht die **Remote-/Cloud-Ordner** (via `rclone listFiles`), nie lokale Ordner.
  - **Neuer Ordner** – Textfeld für einen neuen Cloud-Ordner.
- Remote-Ordnerliste wird per `IosRcloneService.listFiles(remote, '')` geladen (nur Remote, nie lokal).

### Engine (`ios_rclone_service.dart`)
- `_resolveLocalSource` parst die codierte Auswahl (`photos:`/`videos:`/`all:`/`files:`).
- `_stageMediaLibrary` filtert nach ausgewählten Alben (leer = alle).
- Neu: `_stageFolders`/`_copyTree` für lokale Ordner (1:1-Hierarchie in `Dateien/<Ordner>`).

### Dashboard-Controller
- Include-Filter-Erkennung versteht auch die `photos:`/`videos:`/`all:`-Präfixe.

### Detail-Ansicht
- `_formatSourcePath` zeigt die neuen codierten Quellen verständlich an.

---

## 🆕 Datei-Vorschau: nativ & responsiv für iOS (2026-08-17)

**Datei:** `lib/features/dashboard/presentation/widgets/file_preview_dialog.dart`

- iOS rendert jetzt ein **vollflächiges, natives `CupertinoPageScaffold`** statt der festen Desktop-Box (720×600), die auf dem iPhone überlief.
- **Responsiv:** `SafeArea` + `CustomScrollView`, keine feste Breite/Höhe mehr → keine Overflows, funktioniert auch mit großen Accessibility-Schriften.
- **Nativ:** Cupertino-NavigationBar (X-Schließen, Dateityp-Badge), Cupertino-Icons/Symbole, `CupertinoButton`, `CupertinoActivityIndicator`, `SelectableText` (Text), gruppierte Karten.
- **Aktionen:** „In Standard-App öffnen", „Pfad kopieren" als native Buttons mit `IosHaptics`.
- **Bild:** vollflächige `AspectRatio(4:3)`-Vorschau mit `InteractiveViewer` (Zoom/Pinch) + iOS-Zoom-Buttons.
- Desktop (Windows) / Android behalten die bestehende Dialog-Box unverändert.

---

## 🆕 Echter Download im Cloud-Explorer (2026-08-17)

**Audit-Prio 2 umgesetzt.**

- **Neu:** `RcloneService.downloadFile(remoteName, remotePath, localPath)` im Interface + in allen Implementierungen:
  - `IosRcloneService` (`operations/copyfile`),
  - `WindowsRcloneService` (`copyto`),
  - `MockRcloneService` / `MobileRcloneService` (Stub).
- **Cloud-Explorer:** Die bisher **simulierte** `_simulateDownload`-Aktion (nur „Erfolgreich"-Meldung) ist ersetzt durch `_downloadFile`, das die echte Remote-/Cloud-Datei herunterlädt und in `AppDokumente/Downloads/` speichert (auf iOS via `UIFileSharingEnabled` in der Dateien-App sichtbar). Bei Fehlern wird eine Fehlermeldung angezeigt.
- Neue Strings `downloadComplete`/`downloadFailed`.

---

## 🆕 „Jetzt synchronisieren" sync nur den einzelnen Task (2026-08-17)

**Audit-Prio 3 umgesetzt.**

- **`dashboard_controller.dart`:** Per-Task-Sync-Logik in `_syncSingleTask(task)` extrahiert (Returns: true bei Erfolg). `triggerSyncAll` nutzt sie weiterhin für die Queue; neu `triggerSyncTask(taskId)` synchronisiert **nur die angegebene Aufgabe**.
- **`task_detail_screen.dart`:** „Jetzt synchronisieren" ruft jetzt `triggerSyncTask(task.id)` statt `triggerSyncAll()` auf → startet nicht mehr die komplette aktive Queue.

---

## 🆕 Onboarding-i18n + Zielordner-Unterordner + Leere-Auswahl-Hinweis (2026-08-17)

**Audit-Prio 4 & 5 umgesetzt.**

### Prio 4: Onboarding-Texte in AppStrings ausgelagert
- `lib/core/localization/app_strings.dart`: neue Strings `onboardingWelcomeIntro`, `onboardingConnectCloudTitle/Subtitle`, `onboardingConnectedCount(int)`, `onboardingConnectMoreCloud`, `onboardingGrantAccessTitle/Subtitle`, `onboardingPhotosGranted`, `onboardingAllowPhotos`, `onboardingNext`. Duplikat `onboardingGetStarted` entfernt.
- `lib/features/onboarding/presentation/onboarding_screen.dart`: nutzt jetzt `stringsProvider` statt hartcodierter deutscher Texte → volle DE/EN-i18n.

### Prio 5a: Zielordner-Unterordner-Navigation (Remote)
- Der „Vorhandener Ordner"-Picker durchsucht jetzt **Remote-Unterordner** (bisher nur Root-Ebene): Tap auf einen Ordner öffnet ihn (`_openRemoteFolder`), „Eine Ebene höher" (`_goUpRemoteFolder`), Breadcrumb-Pfad `_remoteFolderPath` + History. Bleibt Remote-only (nie lokal).

### Prio 5b: Leere-Auswahl-Hinweise
- Alben: „Keine Alben ausgewählt – es werden alle Alben gesichert."
- Dateien: „Keine Ordner ausgewählt – bitte mindestens einen Ordner wählen."

---

## 🆕 Restliche Audit-Punkte umgesetzt (2026-08-17)

- **Prio 6 – Scheduler-Zeitpläne granular** (`scheduler_service.dart`):
  - `runScheduledSync` bewertet jetzt `scheduleDay`/`scheduleTime` (`Daily`, `Monday`..`Sunday`, `iOS System`, `Manual` wird nicht automatisch ausgeführt).
  - Toleranzfenster + 2-h-Abstand je Task verhindert Mehrfach-Ausführung der periodischen BG-Aufrufe.
  - **WLAN-only-Guard** eingehalten (ohne Wi-Fi kein Sync).
  - Bugfix: `isEchoMode` nutzt jetzt den gespeicherten `syncMode` (vorher hart `true`).
- **#9 – Shell-TabController** (`shell_screen.dart`): `ShellScreen` ist jetzt `ConsumerStatefulWidget`; der iOS-`CupertinoTabController` wird einmal erzeugt und überlebt Rebuilds (Tab-Inhalte/Scroll-Positionen bleiben erhalten).
- **#10 – Cloud-Drives-Leerzustand**: aktionsfähiger Leerzustand mit CTA „Laufwerk hinzufügen".
- **#13 – Semantics(checked)**: Album- und Ordner-Tiles im Wizard sind jetzt `Semantics(checked:…, toggled:…)` → VoiceOver meldet Auswahlzustand.
- **#12 – Onboarding-Touch-Targets**: iOS-Buttons ≥ 44 pt (minHeight).

---

## 🆕 Mirror-Modus → echter 2-Wege-Sync (Multi-Gerät, iCloud-artig) (2026-08-17)

Umsetzung des im `docs/ABLAUF_AUDIT.md` beschriebenen Defizits (Mirror war einseitiges `rclone sync`). Jetzt iCloud-artiger bidirektionaler Sync.

### 1. Persistenter lokaler Mediathek-Spiegel (`ios_rclone_service.dart`)
- `_stageMediaLibrary` erzeugt jetzt einen **persistenten** Spiegel unter `<Dokumente>/FibuMirror/` (vorher transient, bei jedem Lauf gelöscht).
- **Inkrementell**: nur neue/geänderte Assets kopieren; lokal gelöschte Alben/Assets werden aus dem Spiegel entfernt → Löschung kann remote propagieren.
- Grundlage für echten 2-Wege-Sync.

### 2. Bisync-Engine (`ios_rclone_service.dart`)
- Mirror/Echo-Modus ruft jetzt **`rclone bisync`** (`sync/bisync` RC) statt einseitigem `sync/sync` auf:
  - Lösch-Propagation **beide Richtungen** (lokal↔remote).
  - Konflikt-Handling: `--conflict-resolve newer` + `--conflict-loser num` (beide Versionen bleiben).
  - Sicherheitsnetz `--max-delete 50`, `--resilient`, `--max-lock 2h`, `--check-sync`.
  - Automatisches `--resync` beim ersten Lauf (bisync-State unter `<Dokumente>/.bisync/`), danach ohne.
- Inkrementeller (nicht-Mirror) Modus bleibt `sync/copy` (einseitig).

### 3. `writeConfigToRemote` aktiviert (Neuaufsetzen / weiteres Gerät)
- Nach Task-Erstellung/-Bearbeitung wird die Fibu-Konfiguration als `.fibu/config.json` aufs Ziel-Remote geschrieben → Neuaufsetzen-Import (`checkRemoteForConfig`/`readRemoteConfig`) greift jetzt.
- Bugfix in `copyFileToRemote`: behandelt Remote-Pfade, die einen **Dateinamen** enthalten (z.B. `.fibu/config.json`), korrekt (vorher nur Ordner).

### ⚠️ Wichtige Einschränkungen (dokumentiert, siehe `ABLAUF_AUDIT.md` + `UMSETZUNGSPLAN.md`)
- **Bisync ist kein "continuous/real-time" Sync** und nicht für **gleichzeitige** Schreibzugriffe mehrerer Geräte ausgelegt. Das iCloud-Modell ("jedes Gerät hat lokale Fotos + gemeinsamer Cloud-Katalog") wird erreicht, wenn die Geräte **sequenziell** (z.B. über BGTaskScheduler zu unterschiedlichen Zeiten) synchronisieren.
- Remote→lokal-Änderungen werden in den **lokalen Spiegel** übernommen; ein Zurückschreiben in PhotoKit selbst (Import in die Mediathek) ist ein nativer Folgeschritt und NICHT enthalten.
- Bisync erfordert einen persistenten lokalen Spiegel; der reine (nicht-Mirror) Upload bleibt unverändert.

---

## 🆕 Löschprotokoll (Tombstones) für iCloud-artigen Mirror + Aufräumen (2026-08-17)

Umsetzung der Empfehlungen aus `docs/CODE_AUDIT.md` plus robustes Multi-Gerät-Löschprotokoll.

### 1. Löschprotokoll-basierter Mirror (`mirror_sync_engine.dart`, neu)
- Statt fragilem `bisync` (lokale States/Locks pro Gerät) jetzt **explizite Tombstones**:
  - Lösch-Eintrag = Pfad + Zeitstempel + Gerät-ID.
  - Geführt lokal (`<Spiegel>/.fibu/tombstones.json`) UND remote (`<remotePath>/.fibu/tombstones.json`).
- **Ablauf pro Lauf:**
  1. Neue/geänderte lokale Dateien → remote hochladen (nie remote löschen).
  2. **Lokale Tombstones remote ausführen** (lokale Lösch-Priorität).
  3. **Remote-Tombstones lokal anwenden**, außer die Datei wurde lokal nach der Tombstone wieder neu/geändert (lokale Priorität → bleibt).
  4. Neue remote-Dateien in die lokalen Alben/Ordner downloaden.
  5. Zusammengeführtes Löschprotokoll lokal + remote schreiben.
- `IosRcloneService` Mirror-Modus ruft jetzt die Engine auf (ersetzt `bisync`).

### 2. Toten `MobileRcloneService` gelöscht
- Entfernt die Quelle der „zu vielen Logs" (delete.log/copy.log/download.log) und der „unprofessionellen" manuellen Config (Klartext-rclone.conf). Echte Engine nutzt weiter rclones `config/create` (obscure).

### 3. `global.log` begrenzt (`sync_config_service.dart`)
- `appendLocalLog` rotiert Logs bei 256 KB (kürzt auf die Hälfte) statt unbegrenzt zu wachsen.

### 4. Auto-Adopt vorhandener Remote-Tasks verbessert (`sync_config_service.dart`)
- `convertConfigToTasks` löst geräteabhängige `sourcePath` beim Import neu auf: Medien-Auswahlen bleiben, lokale Ordnerpfade (`files:`/`folders:`) werden geleert → Nutzer wählt auf dem neuen Gerät lokal neu. Dadurch kann ein neues Gerät den Task eines bestehenden Backups übernehmen (Remote-Config wird bei Task-Erstellung via `writeConfigToRemote` geschrieben).

### ⚠️ Ehrliche Grenzen (siehe `CODE_AUDIT.md`)
- Tombstone-Sync ist **nicht Echtzeit** und erfordert sequenzielle Läufe (BGTaskScheduler). Konflikte bei **gleichzeitigem** Schreiben beider Geräte an dieselbe Datei werden über Zeitstempel entschieden (lokal-Priorität), aber kein zentraler Server wie iCloud.
- Remote-Downloads landen im lokalen Spiegel (FibuMirror); ein Rückschreiben in PhotoKit selbst ist nativer Folgeschritt (nicht enthalten).

---

## 🆕 Option B: Mediathek-first + eigener Papierkorb (2026-08-17)

### PhotoKit-Frage beantwortet
- Apples „Zuletzt gelöscht"-Ordner ist für Apps **nicht lesbar** (photo_manager kann ihn nicht öffnen). Deshalb wird ein **eigener, sync-fähiger Papierkorb** verwendet statt PhotoKit.

### Neu
- **`trash_service.dart`**: Eigener Papierkorb — lokal (`<Spiegel>/.fibu/Trash`) + remote (`<Remote>/.fibu-trash`, außerhalb des Sync-Ordners). Löschungen gehen nie hart: lokale/remote-Tombstones verschieben in den Papierkorb (wiederherstellbar), Aufbewahrungsfrist (30 Tage) mit `purge`.
- **`photo_kit_bridge.dart`**: Mediathek-first — liest die Fotos-Bibliothek (Asset-ID→Pfad), führt einen persistenten Snapshot, erkennt **lokal gelöschte Fotos** (Snapshot-Diff) und importiert heruntergeladene Dateien in die Mediathek (`saveImage`/`saveVideo`) → sie erscheinen in der Fotos-App.
- **`mirror_sync_engine.dart`**: `sync()` akzeptiert jetzt `TrashService`; Löschungen gehen über den Papierkorb (lokal + remote) statt hart; gibt `downloadedPaths` zurück.
- **`ios_rclone_service.dart`** (Mirror-Modus): 0) PhotoKit-Lösch-Erkennung → Spiegel bereinigen, 1) Engine-Sync mit Papierkorb, 2) neu heruntergeladene remote-Dateien in die Mediathek importieren, 3) Papierkorb purgen.

### Ehrliche Grenzen (device-testing nötig)
- PhotoKit `saveImage`/`saveVideo` und Lösch-Erkennung brauchen echte iOS-Geräte-Verifikation (hier kein Flutter/Xcode).
- Mediathek-Löschung selbst (Foto aus der Fotos-App dauerhaft entfernen) läuft bewusst **über den Papierkorb** (wiederherstellbar), nicht über PhotoKit-Hard-Delete.

---

## 🆕 Apple-Konformitäts-Audit + Polish (2026-08-17)

- **`docs/APPLE_AUDIT.md`** erstellt: Frontend- & Backend-Audit (Cupertino-Shell, grouped Listen, SF Pro, Berechtigungen, Keychain, rclone-Integration). Konformität überwiegend 🟩, offen: Haptik vervollständigen, dynamische Typo/Kontrast je Palette, VoiceOver-Gerätetest.
- **Polish:** Haptik (selection) am iOS-Tab-Wechsel ergänzt (`shell_screen.dart`).

---

## ⏳ Noch offen / zu prüfen

> **Verifikation läuft auf einem Mac mit Flutter/Xcode** — in dieser Sandbox sind Flutter, Dart, Go und Xcode nicht installiert, daher konnte nichts kompiliert werden.

- [ ] **Einmalige Framework-Einrichtung auf dem Dev-Mac**:
  - `brew install go` (≥ 1.21) + `go install golang.org/x/mobile/cmd/gomobile@latest` + `gomobile init` (Details in `ios/scripts/build_librclone.sh`).
  - Einmal `flutter build ios` / Build in Xcode ausführen → die neue Build-Phase baut `Rclone.xcframework` automatisch.
  - Prüfen, dass kein `librclone_missing`-Laufzeitfehler mehr erscheint und z. B. `listRemotes`/`getQuota` reale Antworten liefern.
- [ ] **Datei-Vorschau auf einem Gerät/Simulator testen**:
  - Bild aus Cloud → echtes Bild wird angezeigt (nicht mehr die Fake-Metadaten).
  - Text → echter Inhalt. Audio/Video → öffnet System-Viewer/Quick Look.
- [ ] **`LibrcloneChannel.ensureInitialized`** macht bei fehlender nativ-Engine eine `PlatformException` → diese landet aktuell als Fehlertext in der UI. Optional: eine freundlichere Meldung statt rohem Fehlertext (niedrige Priorität).
- [ ] **OAuth-Verdrahtung ist jetzt implementiert** (§4) — aber **Verifikation nötig**: für einen echten Login müssen pro Anbieter `client_id`/`client_secret` hinterlegt werden (in `_buildOAuthUrl` ist aktuell `__CLIENT_ID__`). Auf Gerät/Simulator den Flow testen (Keychain-Token, Remote-Anlage).
- [ ] **Hintergrund-Scheduling ist jetzt implementiert** (§5) — aber **Verifikation nötig**: `workmanager` + iOS `BGTaskScheduler` auf echtem Gerät prüfen (periodischer Task alle 2 h, Sync wird ausgelöst).
- [ ] **Natives iOS-Design ist jetzt implementiert** (§3) — SF-Pro-Theme, Large Titles, Haptik auf Dashboard/Tasks/Settings. Verifikation auf Gerät/Simulator (optisch prüfen).

---

## 📁 Geänderte/neue Dateien dieser Session

| Datei | Art |
|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | Framework-Integration (Link, Embed, Search Paths, Auto-Build-Phase) |
| `lib/features/dashboard/presentation/widgets/file_preview_dialog.dart` | Echte Bild-/Datei-Vorschau, Fake-Metadaten entfernt |
| `lib/theme/ios_theme.dart` | neu — zentrale Cupertino-Theme-Factory (SF Pro, Large Title) |
| `lib/core/utils/ios_haptics.dart` | neu — native Haptic-Feedback-Helfer |
| `lib/core/services/oauth_service.dart` | neu — OAuth-Flow (flutter_web_auth_2 + Keychain) |
| `lib/core/services/scheduler_service.dart` | neu — Hintergrund-Scheduling (workmanager) |
| `lib/main.dart` | iOS-Theme + Scheduler-Init |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | iOS Large Title + Haptik |
| `lib/features/tasks/presentation/tasks_screen.dart` | iOS Large Title + Haptik |
| `lib/features/settings/presentation/settings_screen.dart` | iOS Large Title + Haptik |
| `lib/features/settings/presentation/cloud_drives_screen.dart` | OAuth-Button verdrahtet (echter Flow) |
| `pubspec.yaml` | + `flutter_secure_storage`, `workmanager` |
| `ios/Runner/Info.plist` | `fibuoauth`-Scheme, `BGTaskSchedulerPermittedIdentifiers`, `UIBackgroundModes` |
| `ios/Runner/AppDelegate.swift` | Workmanager-Registrierung |
| `.github/workflows/build-ios.yml` | Go/gomobile + librclone-Framework-Build in CI |
| `docs/ARBEITSLOG.md` | dieses Log |

---

# Arbeits-Log — Session 2026-08-20 (Folge-Sessionen)

**Branch:** `arena/01a019b4-fibu` · direkte Pushes auf `main`.

## Behobene Laufzeitprobleme (iOS)
1. **Remote-Anlegen schlug fehl (alle Anbieter):** Wizard reichte den Anzeigenamen („Mega") statt des rclone-Backend-Typs (`mega`) an `config/create`. Jetzt durchgängig `provider.id` (`RcloneProviderInfo.id` neu), alle Provider-Art-Prüfungen (OAuth/MEGA/S3/WebDAV/SFTP) vergleichen gegen die ID; Registrierungs-Aliase (`s3-* → s3`, `gcs → google cloud storage`, `1fichier → fichier`) werden gemappt.
2. **Onboarding überspringbar:** „Jetzt loslegen" ist blockiert, bis die Foto-Berechtigung erteilt ist (verpflichtend, da Task-Wizard Medien-Backups sie braucht); Dialog mit Sprung in die Systemeinstellungen.
3. **Doppelter Doppelpunkt** (`mega::`): `config/listremotes` liefert Trailing-`:` → zentrale Normalisierung in `listRemotes()` + defensiv an allen fs-Aufrufen. Cloud-Explorer/Quota/Sync laufen.
4. **„Is a directory" beim Media-Mirror:** `asset.title` ist unter iOS oft null — nulle/leere Dateinamen trafen `file.copy('<dir>/')`. Jetzt deterministische, kollisionsfreie Spiegel-Dateinamen (Titel → Basename → `asset_<id>.<ext>`, Register gegen Überschreiben gleichnamiger Assets).
5. **Endlos laden / „Timeout nach 60s":** rclone betreibt bei Netzproblemen lange Retry-Ketten (3 Job-Retries × 10 Low-Level). Abfragen (about/list/delete) nutzen jetzt rclone-seitiges Fast-Fail-`_config` (15 s Connect, Retries 1, LLR 2) + Dart-Backstop. Echte Provider-Fehlertexte (z. B. MEGA `couldn't login`) landen in Sekunden in UI & Protokoll.
6. **Foto-Doppeleppien im lokalen Speicher:** Persistenter Spiegel `FibuMirror` nur noch für Echo/2-Wege-Tasks (bisync/Tombstones brauchen ihn). Incremental-Tasks stagen transient (Cache) und löschen nach dem Upload.

## Neue Funktionen
- **iOS-Homescreen-Kontextmenü:** Quick Action „Jetzt synchronisieren" (quick_actions-Plugin, SF-Symbol, Kaltstart-sicher via persistiertem Onboarding-Flag).
- **Diagnose-Protokoll:** zentraler `appLogProvider` (Ringpuffer 300, Zeitstempel/Level/Tags; keine Credentials) + neuer Viewer-Screen in den Einstellungen (kopieren/leeren) + System-Log-Abschnitt im Sync-Log-Dialog.
- **Echter Verbindungstest im Wizard:** temporäres rclone-Remote anlegen → Root listen → löschen (Neuer Interface-Method `testConnection` für iOS/Windows; Mock simuliert). Fehler werden verständlich gemappt (ungültige Zugangsdaten/Netzwerk).
- **Provider-spezifische Zugangs-Vorschläge:** `CredentialVaultService` (Keychain via flutter_secure_storage), Je-Typ-Chips „user @ host" im Wizard; Save on Success; AutofillGroup-Bestand.
- **Offline/Live-UX:** zentraler `networkStatusProvider` (live), Offline-Banner + Sync-Block; Live-Theme-Wechsel ohne Neustart (StateProvider + WidgetsBindingObserver).
- **UX-Sauberkeit:** Fortschrittszähler „x von y Dateien" (rclone `transfers/totalTransfers` + Mirror-Phasen-Callback), pro-Remote Quota + Fibu-Beleg in der Laufwerksliste, Dashboard-„Laufwerke verwalten"-Button im Leerzustand entfernt, WLAN-only-Toggle nur noch global (Wizard/Detail bereinigt).

## Barrierefreiheit & Lesbarkeit
- Dark/Light-Audit: statische CupertinoDyanamic-Farben (`secondaryLabel` usw. unaufgelöst) durch theme-getriebene `textPrimary/textSecondary` ersetzt (Storage-Card, Dashboard-Fortschritt, Einstellungs-Header). Onboarding-Buttons mit expliziter Kontrastfarbe (weiß/Accent, Disabled-State sichtbar).

## CI/Infrastruktur
- Actions auf Node-24-Majors: checkout v5, setup-java v5, setup-go v6 (`cache: false`, kein go.sum im Root), upload-artifact v7. Go auf `stable` (gomobile@latest verlangt ≥ 1.25; Pin 1.21 brach den Build).
- Hinweis: Die Arena-GitHub-App hat keine `workflows`-Permission → Workflow-Dateiänderungen wurden manuell übertragen.
