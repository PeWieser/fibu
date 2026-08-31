# Fibu — Rechts-Audit

Stand: `main` @ `4e681c4`, geprüft am 2026-08-31. Jeder Befund ist gegen den
echten Code geprüft und mit Datei/Zeile belegt. Externe Anforderungen
(Apple, Google, DSGVO, DDG, UWG, EAR) sind mit Quelle verlinkt.

> **Keine Rechtsberatung.** Dieses Dokument ist eine technische
> Compliance-Prüfung durch einen Entwickler. Vor einer kommerziellen
> Veröffentlichung sollte es ein Anwalt für IT-Recht gegenlesen — insbesondere
> die Punkte L-08 (Impressum), L-24 (Name/Marke) und L-23 (Vertriebsweg).

## Legende

| Zeichen | Bedeutung |
|---|---|
| 🔴 | Blocker — verhindert App-Store-Freigabe oder verletzt geltendes Recht |
| 🟠 | Erheblich — muss vor Veröffentlichung geklärt sein |
| 🟡 | Mittel — Risiko unter realistischen Bedingungen |
| 🔵 | Hinweis / Empfehlung |
| ✅ | Geprüft und in Ordnung |

## Ergebnis in einem Absatz

Die App ist datenschutzfreundlich gebaut: kein Server, keine Analytics, keine
Tracker, Zugangsdaten im Keychain ohne Backup-Export. Genau das macht die
rechtliche Lage einfach — **der Entwickler ist weder Verantwortlicher noch
Auftragsverarbeiter für die Inhalte**, die Nutzer sichern. Was gefehlt hat,
waren die **Formalien**: fremde Lizenzdatei, keine Datenschutzerklärung, kein
Privacy Manifest, falsche Marken-Associated-Domains, keine Export-Compliance.
Von 32 Befunden sind 9 behoben, 4 brauchen deine Entscheidung oder deine
persönlichen Daten, der Rest ist dokumentiert oder unkritisch.

| Kategorie | 🔴 | 🟠 | 🟡 | 🔵 | ✅ | Behoben |
|---|---|---|---|---|---|---|
| A. Urheberrecht / Open Source | 1 | 0 | 1 | 1 | 1 | 1 |
| B. Datenschutz (DSGVO) | 2 | 2 | 2 | 0 | 2 | 3 |
| C. Apple App Store | 2 | 1 | 2 | 1 | 1 | 3 |
| D. Android / Google Play | 0 | 1 | 1 | 1 | 0 | 0 |
| E. Distribution | 0 | 1 | 0 | 0 | 0 | 0 |
| F. Marke / Name | 0 | 0 | 1 | 1 | 0 | 0 |
| G. Deutsches Recht | 0 | 0 | 1 | 1 | 0 | 0 |
| H. Anbieter-Bedingungen | 0 | 2 | 1 | 1 | 0 | 1 |

---

## A. Urheberrecht und Open-Source-Compliance

### 🔴 L-01 — Die LICENSE-Datei gehörte einem Dritten — **behoben**

**Befund.** `LICENSE` enthielt die MIT-Lizenz von **Expo**:

```
$ git show HEAD:LICENSE | head -3
The MIT License (MIT)

Copyright (c) 2015-present 650 Industries, Inc. (aka Expo)
```

**Warum das ernst ist.** Zwei Fehler gleichzeitig:

1. Die Datei erklärt, Urheber des Werks sei 650 Industries, Inc. Das ist eine
   falsche Urheberrechtsbezeichnung (§ 106 UrhG betrifft zwar nur das
   Anbringen einer unzulässigen Urheberbezeichnung, aber zivilrechtlich ist
   die Zuschreibung schlicht unwirksam und irreführend).
2. Für das eigene Werk existierte damit **keine** wirksame Lizenz. GitHub
   meldete für das Repo `license: MIT` — mit fremdem Urheber. Jeder Fork
   befand sich in einer unklaren Rechtslage.

**Fix.** `LICENSE` enthält jetzt die MIT-Lizenz mit
`Copyright (c) 2025-present PeWieser (Fibu)` plus einen Abschnitt
„Third-party components", der rclone (MIT, Nick Craig-Wood) und
golang.org/x/mobile (BSD-3, The Go Authors) nennt.

**Nacharbeit für dich:** „PeWieser" ist der GitHub-Handle. Für eine
Veröffentlichung gehört dort der bürgerliche Name hin (siehe L-08). Das Jahr
muss das Erstveröffentlichungsjahr sein.

### ✅ L-02 — Lizenzpflichten für eingebundene Software sind erfüllt

MIT und BSD-3-Clause verlangen, dass der Copyright-Vermerk „in all copies or
substantial portions" mitgeliefert wird. Das ist erfüllt:

- Alle pub-Pakete: automatisch über `LicenseRegistry`, dargestellt unter
  Einstellungen → Rechtliches → Open-Source-Lizenzen
  (`lib/features/settings/presentation/licenses_screen.dart`).
- Die beiden statisch eingebundenen Nicht-Dart-Komponenten, die kein
  Paketmanager kennt, sind manuell registriert:
  `lib/main.dart:26–75` (rclone MIT, gomobile BSD-3).
- Jetzt zusätzlich statisch in `LICENSE`.

rclone ist MIT-lizenziert — Einbetten in eine proprietäre oder eigene
Open-Source-App ist damit erlaubt. Es gibt keine GPL-/AGPL-Komponente im
Projekt (grep nach `general public license` liefert nur den Erkennungscode in
`licenses_screen.dart:80`).

### 🟡 L-03 — In-App-Text behauptet Open Source

`lib/core/localization/app_strings.dart:1134` sagt: „Fibu ist Open Source und
unter der MIT-Lizenz veröffentlicht." Das war solange falsch, wie die
LICENSE-Datei einem Dritten gehörte (L-01). Seit dem Fix stimmt die Aussage —
aber nur, solange das Repo öffentlich bleibt. Wird es privat, muss der Text
mit.

### 🔵 L-04 — README-Badges nutzen Fremdlogos

`README.md:3–5` bindet `?logo=flutter`, `?logo=dart`, `?logo=rclone` ein. Das
sind Marken von Google und dem rclone-Projekt. Als Nominativnutzung
(„unterstützt diese Technologien") unkritisch; ein Endorsement-Eindruck
entsteht aber leicht. Der Klarstellungs-Satz steht jetzt im Impressum
(`legal_documents_screen.dart`) und in `LICENSE`.

---

## B. Datenschutz (DSGVO)

### 🔴 L-05 — Keine Datenschutzerklärung — **behoben**

**Befund.** Weder in der App noch im Repo gab es eine Datenschutzerklärung.
Einstellungen → Rechtliches enthielt ausschließlich die Open-Source-Lizenzen
(`settings_screen.dart` vor dem Fix, Legal-Section mit genau einer Zeile).

**Warum das ein Blocker ist.** Apple App Store Review Guideline 5.1.1(i):
*„All apps must include a link to their privacy policy in the App Store Connect
metadata field and within the app in an easily accessible manner."* Das gilt
auch für Apps, die gar keine Daten erheben. Google Play verlangt dasselbe.

**Fix.**

- Neue Ansicht `lib/features/settings/presentation/legal_documents_screen.dart`
  mit Datenschutzerklärung und Impressum als Volltext, erreichbar unter
  Einstellungen → Rechtliches auf allen drei Plattformen (iOS/Windows/Android).
- Veröffentlichbare Fassungen unter `docs/DATENSCHUTZ.md` und
  `docs/IMPRESSUM.md` — daraus kann die URL für App Store Connect erzeugt
  werden (GitHub Pages reicht).

**Inhaltlich wichtig:** Die Erklärung nennt ausdrücklich den
OAuth-Proxy `rclone.org` (L-07) und stellt klar, dass der Entwickler keinen
Zugriff auf Inhalte hat.

### 🟠 L-06 — Diagnoseprotokoll lag offen im Dokumente-Ordner — **behoben**

**Befund.** `AppLog.attachFileSink()` schrieb nach
`getApplicationDocumentsDirectory()/fibu.log`. Gleichzeitig stehen in
`ios/Runner/Info.plist:106,108`:

```xml
<key>UIFileSharingEnabled</key>          <true/>
<key>LSSupportsOpeningDocumentsInPlace</key>  <true/>
```

Damit ist der Dokumente-Ordner in der Dateien-App unter „Auf meinem iPhone →
Fibu" sichtbar, exportierbar, per AirDrop teilbar und in unverschlüsselten
Finder-Backups enthalten.

**Warum das personenbezogene Daten sind.** Der Kommentar in
`app_log_service.dart` behauptete: *„Es werden NIEMALS Passwörter/Tokens oder
Zugangsdaten geloggt."* Das stimmt — aber geloggt werden:

| Beleg | Inhalt |
|---|---|
| `ios_rclone_service.dart:242` | `Remote-Datei gelöscht: $remote:$path` — voller Dateipfad |
| `ios_rclone_service.dart:221` | `Auflistung $remote:$listedPath` — Remote-Pfad |
| `ios_rclone_service.dart:695` | `Im Spiegel gelöscht: $rel` — relativer Dateipfad |
| `ios_rclone_service.dart:1208,1766` | `Album „$albumName": $count Assets` — Albennamen |
| `mirror_sync_engine.dart:263,344,385,543` | `$rel` — Dateipfade |
| `photo_kit_bridge.dart:159` | `Import „${asset.title}"` — echte Dateinamen |

Dateinamen wie `Steuer2025.pdf`, `Arztbericht_Mueller.jpg` und Albennamen wie
`Familie` sind personenbezogene Daten (Art. 4 Nr. 1 DSGVO). Sie unverschlüsselt
in einen exportierbaren Ordner zu legen, ist eine Schwäche bei den
technisch-organisatorischen Maßnahmen (Art. 32 DSGVO).

**Fix.** Die Logdatei liegt jetzt über `privateAppFile('fibu.log')` im privaten
`Library/Application Support`-Ordner — derselbe Ort, an dem `rclone.conf`
bereits liegt. Eine Alt-Datei im Dokumente-Ordner wird einmalig migriert und
dort gelöscht (`lib/core/utils/app_paths.dart:22–38`). Der
In-App-Bildschirm „Sync-Protokoll & Diagnose" kann das Protokoll weiterhin
kopieren; der Hinweistext wurde angepasst
(`app_strings.dart` `debugLogFileLocation`).

**Trade-off:** Das README bewarb die Sichtbarkeit in der Dateien-App. Der
Komfort war die Datenschwäche. Kopieren geht weiterhin in der App.

### 🟠 L-07 — rclone.org als OAuth-Zwischenstation war nirgends offengelegt — **behoben**

**Befund.** `lib/features/settings/presentation/add_remote_wizard.dart:241`
und `:268` bauen für alle Provider ohne eigenen `client_id` (also im
Normalfall) diese URL:

```dart
'https://rclone.org/oauth/?provider=$providerId&state=$state&redirect_uri=$redirect'
```

Der Anmeldevorgang läuft damit über einen Server des rclone-Projekts
(Nick Craig-Wood). Dorthin gehen: Provider-Kennung, interner Remote-Name,
Autorisierungscode.

**Warum das relevant ist.** Art. 13 Abs. 1 lit. e DSGVO verlangt die Angabe
der Empfänger oder Kategorien von Empfängern. Ein fremder Server im
Anmeldepfad ist genau so ein Empfänger — und keiner der Nutzer hat davon
erfahren.

**Fix.** Eigener Abschnitt „Anmeldung über OAuth — wichtiger Hinweis zu
rclone.org" in der Datenschutzerklärung, mit dem konkreten Ausweg
(eigene `client_id` anlegen → Direktverbindung).

### 🔴 L-08 — Impressum ist unvollständig — **offen, braucht deine Daten**

**Befund.** Es gab kein Impressum. § 5 DDG (Digitale-Dienste-Gesetz, seit
17.05.2024 in Kraft, Nachfolger des TMG) verlangt Name und **ladungsfähige
Anschrift** bei geschäftsmäßigen digitalen Diensten. Apple verlangt im
App Store Connect zusätzlich den Entwickler-Namen, Google Play eine
verifizierte Adresse.

**Stand nach dem Fix.** Das Impressum existiert als Ansicht und als
`docs/IMPRESSUM.md`, enthält aber einen sichtbaren Platzhalter:

```
[Name und ladungsfähige Anschrift vor Veröffentlichung ergänzen —
 siehe docs/RECHTS_AUDIT.md, Befund L-08]
```

**Zu tun.** In `legal_documents_screen.dart` (Methode
`LegalDocuments.imprint`, beide Sprachen) und in `docs/IMPRESSUM.md`
eintragen: bürgerlicher Name, Straße, PLZ, Ort, E-Mail. Solange das fehlt,
darf die App nicht veröffentlicht werden — ein Impressum mit Platzhalter ist
schlechter als keines, weil es die Pflicht vorgibt zu erfüllen.

**Abgrenzung:** Eine rein private, unentgeltliche App ohne geschäftsmäßige
Absicht fällt wahrscheinlich nicht unter § 5 DDG. Sobald sie im App Store
steht, verlangt Apple die Angaben aber ohnehin.

### ✅ L-09 — Rollenklärung: kein Auftragsverarbeiter, keine AVV nötig

Wichtigster Befund des Audits, und er ist positiv. Fibu hat **keinen Server**.
Daten fließen ausschließlich vom Gerät des Nutzers in dessen eigenes
Cloud-Konto. Damit:

- Der Entwickler ist **kein Verantwortlicher** für die gesicherten Inhalte
  (Art. 4 Nr. 7 DSGVO) — er bestimmt weder Zwecke noch Mittel und hat keinen
  Zugriff.
- Er ist **kein Auftragsverarbeiter** (Art. 28 DSGVO) — er verarbeitet nichts
  im Auftrag. Es ist **kein AVV** nötig.
- Der **Nutzer** ist Verantwortlicher für das, was er sichert. Sichert ein
  Unternehmen damit Kundendaten, ist das Unternehmen verantwortlich und muss
  die Übertragung in die Cloud in sein eigenes Verarbeitungsverzeichnis
  aufnehmen.

Diese Klarstellung steht jetzt in der Datenschutzerklärung. Sie ist der Grund,
warum die Privacy Nutrition Labels auf **„Data Not Collected"** stehen können.

### 🟡 L-10 — Drittlandtransfers

Die App selbst überträgt nichts in Drittländer. Wohl aber die Cloud-Anbieter
des Nutzers (Google, Microsoft, Dropbox, Backblaze …). Die Rechtsgrundlage
dafür liegt beim jeweiligen Anbieter (i. d. R. Standardvertragsklauseln der
EU-Kommission). In der Datenschutzerklärung ausgewiesen, Details verweisen auf
die Anbieter-Erklärungen. Nichts zu tun.

### ✅ L-11 — Zugangsdaten sauber im Keychain

`ios/Runner/AppDelegate.swift:241`:

```swift
attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

Damit sind Tokens und Passwörter nicht in Geräte-Backups und nicht auf anderen
Geräten wiederherstellbar — das ist der stärkste praktische Schutz im Projekt.
Der Fallback auf anderen Plattformen ist eine JSON-Datei im privaten
App-Support-Ordner (`lib/core/services/secure_store_service.dart:18–21`), also
auf dem Niveau der ohnehin vorhandenen `rclone.conf`. Angemessen im Sinne des
Art. 32 DSGVO.

### 🟡 L-12 — Destruktive Operationen an personenbezogenen Daten

Die Spiegel-Synchronisation **löscht lokale Fotos**, wenn sie in der Cloud
nicht mehr vorhanden sind. Das ist gewollt, aber es ist ein Eingriff in
personenbezogene Daten mit Schadenspotenzial. Vorhandene Schutzmechanismen
(siehe `docs/STRESSTEST_DAU.md`, Abschnitt F): Asset-Existenzprüfung je
Kandidat, >50 %-Anomaliebremse, System-Bestätigungsdialog, Überspringen bei
eingeschränktem Fotozugriff. Damit ist das technisch angemessen abgesichert.
Der Hinweis auf Aufbewahrungspflichten steht jetzt im Impressum (L-26).

---

## C. Apple App Store

### 🔴 L-13 — Kein Privacy Manifest — **behoben**

**Befund.** `find . -iname '*xcprivacy*'` lieferte vor dem Fix **keinen
Treffer**.

**Warum das ein Blocker ist.** Seit dem 01.05.2024 akzeptiert App Store
Connect keine App mehr, die Required-Reason-APIs nutzt, ohne sie in einer
`PrivacyInfo.xcprivacy` zu erklären ([Apple: Describing use of required reason
API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)).
Fehlerbild: `ITMS-91053: Missing API declaration`. Zusätzlich stehen
**`Flutter`, `path_provider`, `path_provider_ios`, `url_launcher`,
`url_launcher_ios` und `Reachability` auf Apples Liste der SDKs, die zwingend
ein eigenes Manifest brauchen** ([Third-party SDK
requirements](https://developer.apple.com/support/third-party-SDK-requirements/));
Fehlerbild `ITMS-91061`. Fibu nutzt `Flutter` und `path_provider` direkt.

**Fix.** Neue Datei `ios/Runner/PrivacyInfo.xcprivacy`, eingetragen in
`project.pbxproj` (PBXFileReference, Runner-Group, PBXResourcesBuildPhase) —
ohne den Eintrag landet die Datei nicht im Bundle. Inhalt:

| Kategorie | Code | Beleg im Code |
|---|---|---|
| `UserDefaults` | `1C8F.1` | `AppDelegate.swift:154`, `FibuWidget.swift:80` — App-Group-Suite |
| `UserDefaults` | `CA92.1` | Standard-Suite der Flutter-Plugins |
| `DiskSpace` | `E174.1` | `AppDelegate.swift:98` (`volumeAvailableCapacityForImportantUsageKey`) — Vorprüfung vor Transfers |
| `FileTimestamp` | `C617.1` | librclone `stat`/`fstat`; `sync_manifest_service.dart` nutzt Größe + mtime |
| `FileTimestamp` | `3B52.1` | Dateien, auf die der Nutzer per Dateien-App/Mediathek Zugriff gibt |
| `SystemBootTime` | `35F9.1` | monotone Uhr der statisch eingebundenen Go-Runtime |

`NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []`,
`NSPrivacyCollectedDataTypes = []`.

**Ehrliche Einschränkung.** Ob die Go-Runtime in librclone tatsächlich
`mach_absolute_time` und `stat` referenziert, kann ich hier nicht prüfen (kein
macOS, kein Xcode, kein Flutter-SDK in dieser Umgebung). Die Deklaration ist
deshalb bewusst vollständig — Apple sanktioniert Über-Deklaration nicht, wohl
aber fehlende Einträge. Nach dem ersten echten `Product → Archive → Generate
Privacy Report` in Xcode sollte die Liste gegen den Report abgeglichen werden.

**Grauzone, bewusst dokumentiert.** Apples Reason-Codes für FileTimestamp
sagen, die Information dürfe das Gerät nicht verlassen. Ein Sync-Programm
schreibt Dateinamen, Größe und mtime aber genau dorthin, wo der Nutzer sie
hinhaben will — in sein eigenes Cloud-Konto. Das ist eine nutzergerichtete
Übertragung an das eigene Konto, keine Übermittlung an den Entwickler. Falls
App Review das hinterfragt, ist das die Begründung.

### 🔴 L-14 — Associated Domains behaupteten Verbindungen zu 11 fremden Marken — **behoben**

**Befund.** `ios/Runner/Runner.entitlements` enthielt vor dem Fix
`webcredentials:`-Einträge für:

```
mega.nz, drive.google.com, accounts.google.com, google.com, *.google.com,
www.dropbox.com, dropbox.com, *.dropbox.com, login.live.com, live.com,
*.live.com, login.microsoftonline.com, microsoftonline.com,
*.microsoftonline.com, my.pcloud.com, pcloud.com, *.pcloud.com,
account.box.com, box.com, *.box.com, passport.yandex.com, yandex.com,
*.yandex.com, yandex.ru, *.yandex.ru, proton.me, *.proton.me,
secure.backblaze.com, backblaze.com, *.backblaze.com,
console.wasabisys.com, wasabisys.com, *.wasabisys.com
```

**Zwei Fehler.**

1. *Technisch wirkungslos.* Shared Web Credentials verlangt, dass die Domain
   unter `/.well-known/apple-app-site-association` eine Datei hostet, die
   `TEAMID.com.example.fibu` auflistet. Keine dieser Domains tut das. iOS
   verwirft die Zuordnung. Der Passwort-Autofill-Vorschlag funktioniert
   trotzdem — er kommt über `UITextContentType`
   (`AutofillHints.username`/`.password` in
   `provider_login_fields.dart`), nicht über Associated Domains.
2. *Rechtlich problematisch.* Die Einträge behaupten eine geprüfte Verbindung
   der App zu den Marken Google, Microsoft, Dropbox, Yandex, MEGA, Proton,
   Box, pCloud, Backblaze und Wasabi. Das ist eine kennzeichenrechtliche
   Benutzung fremder Marken ohne Berechtigung und ein Ablehnungsgrund nach
   App Store Review Guideline 4.1 (Copycats) und 5.2.2 (Third-Party
   Sites/Services).

**Fix.** Entitlement entfernt, mit Begründung im Kommentar. Die App-Group
bleibt.

### 🟠 L-15 — Keine Export-Compliance-Angabe — **behoben**

**Befund.** `ITSAppUsesNonExemptEncryption` fehlte in
`ios/Runner/Info.plist`. Ohne diesen Schlüssel fragt App Store Connect bei
jedem einzelnen Build interaktiv nach der Export-Compliance — und ein Build,
der automatisiert hochgeladen wird, bleibt dort hängen.

**Einordnung.** Die App nutzt (a) TLS/HTTPS aus Betriebssystem- bzw.
Standard-Bibliotheken und (b) die Krypto-Routinen von rclone auf Basis von
`golang.org/x/crypto`. Beides fällt unter die Ausnahmen für
Standard-/Massenmarkt-Kryptographie: US EAR `5D992.c` bzw. EU-Verordnung
2021/821, Anhang II Nr. 4. Damit: **nicht genehmigungspflichtig**, aber
erklärungsbedürftig.

**Fix.** `ITSAppUsesNonExemptEncryption = false` in
`ios/Runner/Info.plist:38`.

### 🟡 L-16 — Bundle-ID `com.example.fibu` — **offen, Entscheidung nötig**

**Befund.** `project.pbxproj:495` `PRODUCT_BUNDLE_IDENTIFIER =
com.example.fibu`, dazu `group.com.example.fibu` in beiden Entitlements und
`com.example.fibu.oauth` in `Info.plist:81`.

**Risiken.**

- `example.com` ist eine von der IANA reservierte Dokumentations-Domain. Die
  Reverse-Domain-Konvention behauptet damit eine Domain, die niemand besitzt.
- Apple prüft die Verfügbarkeit der Bundle-ID bei der Anlage in App Store
  Connect. Wer `com.example.fibu` zuerst anlegt, blockiert den Namen.
- Für SDKs, Push, IAP und Analytics wird die Bundle-ID als Schlüssel verwendet —
  eine Kollision mit einem anderen Entwickler verursacht reale Störungen.

**Wichtig:** Nach der ersten Veröffentlichung im App Store ist die Bundle-ID
**nicht mehr änderbar**. Die Entscheidung muss jetzt fallen. Vorschlag: eine
Domain sichern (z. B. `fibu-backup.app`) und auf `app.fibu-backup.fibu` o. Ä.
umstellen — zusammen mit der App-Group (`group.<neue-id>`) und der
`CFBundleURLName`. Das ist ein eigener, kleiner Commit.

### 🟡 L-17 — Berechtigungs-Strings nur auf Deutsch

`ios/Runner/Info.plist:100,102`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Damit deine Fotos und Videos 1:1 in deiner eigenen Cloud landen.</string>
```

Die App ist zweisprachig (Deutsch/Englisch), die Systemdialoge sind es nicht.
Ein englischsprachiger Nutzer bekommt einen deutschen Berechtigungsdialog.
Kein Rechtsproblem, aber ein App-Review-Risiko (Guideline 2.1) und
unprofessionell. Lösung: `ios/Runner/en.lproj/InfoPlist.strings` mit den
englischen Texten anlegen.

### ✅ L-18 — Kein Tracking, kein ATT nötig

Es gibt kein `NSUserTrackingUsageDescription`, keine Advertising-ID, keine
Analytics- oder Crash-SDKs, keine Tracking-Domains. `NSPrivacyTracking=false`
ist damit zutreffend. Kein App-Tracking-Transparency-Prompt erforderlich.

### 🔵 L-19 — Konto-Löschung (Guideline 5.1.1(v)) nicht anwendbar

Guideline 5.1.1(v) verlangt von Apps, die Konten anlegen, eine
In-App-Kontolöschung. Fibu legt keine Konten an — es verbindet bestehende
Cloud-Konten des Nutzers. Das Trennen eines Laufwerks löscht dessen
Zugangsdaten aus dem Keychain (`cloud_drives_screen.dart:708`). Nicht zu tun,
aber in der Datenschutzerklärung erklärt.

---

## D. Android / Google Play

### 🟠 L-20 — OAuth-Callback-Scheme ist auf Android nicht registriert

**Befund.** `lib/core/services/oauth_service.dart:37` definiert
`callbackScheme = 'fibuoauth'`, `ios/Runner/Info.plist:84` registriert ihn als
`CFBundleURLSchemes`. In `android/app/src/main/AndroidManifest.xml` kommt
`fibuoauth` **null Mal** vor (`grep -c` → `0`):

```
$ grep -c "fibuoauth" android/app/src/main/AndroidManifest.xml
0
```

**Folge.** Auf Android kann der OAuth-Login nicht zur App zurückkehren —
funktional kaputt, nicht nur juristisch unschön.

**Zusätzlich:** RFC 8252 §8.4 rät von Custom URI Schemes als
OAuth-Redirect ausdrücklich ab, weil jede andere App dasselbe Scheme
registrieren und den Autorisierungscode abfangen kann. Auf iOS entschärft
`ASWebAuthenticationSession` das (die Callback geht an die öffnende App), auf
Android mit Chrome Custom Tab + Intent-Filter nicht. Sauber wären App Links
mit `autoVerify="true"`.

### 🟡 L-21 — Data-Safety-Erklärung für Play Console fehlt

Google Play verlangt vor der Veröffentlichung ein ausgefülltes
Data-Safety-Formular. Grundlage ist dieselbe Analyse wie für Apples Privacy
Labels (L-09): keine Datenerhebung durch den Entwickler, Fotos und Dateien
werden an die vom Nutzer gewählten Dienste übertragen. Aus
`docs/DATENSCHUTZ.md` ableitbar.

### 🔵 L-22 — Legacy-Speicherberechtigungen

`WRITE_EXTERNAL_STORAGE` mit `maxSdkVersion="29"` und
`READ_EXTERNAL_STORAGE` mit `maxSdkVersion="32"` — korrekt versioniert, also
kein Befund. Ab API 33 greifen `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`. Für
„Auswahl …" (Photo Picker, API 34+) fehlt
`READ_MEDIA_VISUAL_USER_SELECTED`; ohne sie verhält sich eingeschränkter
Zugriff auf neuen Android-Versionen anders als auf iOS.

---

## E. Distribution

### 🟠 L-23 — Unsignierte IPA als öffentliches CI-Artefakt — **Vertriebsweg festlegen**

**Befund.** `.github/workflows/build-ios.yml` baut
`flutter build ios --release --no-codesign`, packt eine
`app-release-unsigned.ipa` und lädt sie als Artefakt `ios-app-release` hoch
(7 Tage Aufbewahrung). Das Repo ist öffentlich:

```
$ gh api repos/PeWieser/fibu --jq '.visibility'
public
```

**Rechtliche Lage.**

- Eine **unsignierte** IPA lässt sich auf einem normalen iPhone gar nicht
  installieren. Sie muss vorher mit einem Zertifikat um-signiert werden.
- Das Um-signieren mit einem persönlichen kostenlosen/paid
  Entwickler-Zertifikat und die Weitergabe an Dritte verstößt gegen
  § 3.3.2 des Apple Developer Program License Agreement — das ist ein
  **Vertragsbruch**, keine Straftat, führt aber zum Ausschluss aus dem
  Developer Program.
- In der EU ist seit iOS 17.4 die Verteilung über das Web erlaubt (DMA), aber
  nur nach **Notarisierung durch Apple** und mit bezahltem Developer Program.
- TestFlight ist der einzig saubere Weg für geschlossene Testkreise.

**Empfehlung.** Entweder das Artefakt auf `private`-Repos beschränken bzw.
die Upload-Stufe entfernen, oder den Vertriebsweg formal festlegen:
TestFlight während der Entwicklung, App Store für die Veröffentlichung.

---

## F. Marke und Name

### 🟡 L-24 — Name „Fibu": Marken- und Irreführungsrisiko

**Zwei getrennte Fragen.**

1. *Kennzeichenrecht.* „Fibu" ist die gängige deutsche Abkürzung für
   **Finanzbuchhaltung**. Ob identische oder ähnliche Marken in den
   Nizza-Klassen 9 (Software) und 42 (SaaS) eingetragen sind, konnte ich nicht
   prüfen — DPMA- und EUIPO-Register sind aus dieser Umgebung nicht
   erreichbar. **Zu tun:** Recherche unter `register.dpma.de` und
   `euipo.europa.eu/eSearch`, Klassen 9 und 42, Wort und Klang. DPMA und
   EUIPO prüfen Kollisionen **nicht** von Amts wegen; das Risiko liegt beim
   Anmelder.
2. *Irreführung, § 5 UWG.* Der Name verspricht Finanzbuchhaltung. Die App
   macht **Medien-Backup** — sie schreibt keine Buchungssätze, erzeugt keine
   Konten, wertet nichts aus. `README.md:1` sagt das richtig („Multi-Cloud
   Backup & Media Library Mirroring"), aber der App-Name allein führt in die
   Irre. Sobald die App beworben wird, ist das ein UWG-Risiko.
   Empfehlung: Namenszusatz („Fibu Sicherung", „Fibu Backup") oder Umbenennung.

### 🔵 L-25 — Provider-Namen

Google Drive, OneDrive, Dropbox, MEGA, Proton Drive etc. werden nur
nennend verwendet, um die unterstützten Dienste zu kennzeichnen. Das ist
zulässige Nominativnutzung. Der Klarstellungssatz („unabhängiges Projekt, nicht
gebilligt") steht jetzt im Impressum und in `LICENSE`. Wichtig bleibt: **keine
Logos** dieser Anbieter in der App oder im Store-Listing verwenden.

---

## G. Deutsches Recht

### 🟡 L-26 — Aufbewahrungspflichten vs. Spiegel-Löschung

Wenn ein Nutzer die App für aufbewahrungspflichtige Unterlagen einsetzt,
können Spiegel-Löschungen (Cloud → Gerät, `ios_rclone_service.dart` +
`photo_kit_bridge.dart`) Originale vernichten. Relevante Normen: § 147 AO
(10 Jahre für Buchungsbelege), § 257 HGB, GoBD (Unveränderbarkeit,
Verlustfreiheit).

**Was die App nicht ist:** kein revisionssicheres Archiv. Es gibt keine
WORM-Speicherung, keine Verfahrensdokumentation, kein Zertifikat.

**Stand nach dem Fix.** Der Hinweis steht im Impressum („Die App ist ein
Werkzeug zur Sicherung eigener Daten … Wer die App für geschäftliche oder
aufbewahrungspflichtige Unterlagen einsetzt, ist für die Einhaltung seiner
Aufbewahrungspflichten selbst verantwortlich").

**Empfehlung für später:** eine einmalige Warnung in der App, sobald eine
Aufgabe mit bidirektionaler Löschung auf Dateien (nicht Fotos) zeigt.

### 🔵 L-27 — Barrierefreiheitsstärkungsgesetz (BFSG)

Das BFSG gilt seit dem 28.06.2025 für Dienstleistungen im elektronischen
Geschäftsverkehr. Eine reine Backup-App ohne eigenen Verkaufskanal im
App-Inneren fällt voraussichtlich nicht darunter — der Kauf läuft über Apple
bzw. Google, nicht über die App. Unabhängig davon erfüllt die App bereits
WCAG-AA-Ziele (44-pt-Ziele, geprüfte Kontraste in 8 Paletten × 2 Modi, siehe
`docs/STRESSTEST_DAU.md` J3, `accessibilityLabel` auf Icons).

---

## H. Bedingungen der Cloud-Anbieter

### 🟠 L-29 — Googles geteilte rclone-`client_id` wird 2026 abgeschaltet

**Befund.** Der Normalpfad der App verlässt sich auf rclones geteilte
Anmeldedaten (`add_remote_wizard.dart:196` — `getProviderClientCredentials`,
Fallback auf `rclone.org/oauth`). rclone dokumentiert inzwischen:

> „The shared client_id is being retired and will stop working during 2026, so
> creating your own is now strongly recommended."
> — [rclone.org/drive](https://rclone.org/drive/),
> [rclone.org/googlephotos](https://rclone.org/googlephotos/)

**Zusätzlich:** Der angeforderte Scope `https://www.googleapis.com/auth/drive`
ist ein **restricted scope**. Ab 100 Nutzern verlangt Google dafür eine
jährliche CASA-Sicherheitsprüfung, und ein nicht verifiziertes
OAuth-Zustimmungsbildschirm erscheint mit Warnung.

**Zu tun.** Eigene OAuth-App in der Google Cloud Console anlegen,
`client_id`/`client_secret` als Einstellung in der App abfragen und den
Nutzer im Wizard darauf hinweisen. Ohne das bricht die Google-Anbindung
im Lauf von 2026 weg.

### 🟠 L-30 — Google Photos verlangte den Drive-Scope — **behoben**

**Befund.** Vor dem Fix liefen `drive`, `google_photos` und `google photos`
durch denselben `case` und forderten
`https://www.googleapis.com/auth/drive` an
(`add_remote_wizard.dart`, `_buildOAuthUrl`). Der Drive-Scope gewährt **keinen**
Zugriff auf die Photos Library API — der Login konnte technisch nicht
funktionieren, und rechtlich wäre ein Drive-Vollzugriff für einen
Photos-Anbieter ein Verstoß gegen die Datenminimierung (Art. 5 Abs. 1 lit. c
DSGVO).

**Fix.** Eigener `case` für Google Photos mit den drei Scopes, die rclone
seit Googles Umstellung auf die Photos-Picker-API verlangt:

```
https://www.googleapis.com/auth/photoslibrary.appendonly
https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata
https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata
```

**Einschränkung, ungeprüft:** Ich konnte den Anmeldefluss nicht gegen Google
durchtesten (kein Gerät, kein Google-Konto in dieser Umgebung). Die Scopes
sind aus der rclone-Dokumentation übernommen.

### 🟡 L-31 — Drive-Vollzugriff statt `drive.file`

`add_remote_wizard.dart:246` fordert `auth/drive` (Vollzugriff auf alle
Dateien). Für eine Backup-App, die in einen eigenen Ordner `fibu-backup/`
schreibt, wäre `drive.file` (nur von der App erzeugte Dateien) die
datenminimale Wahl — und ein *sensitive* statt *restricted* Scope, also keine
CASA-Pflicht.

**Nicht umgesetzt, bewusst.** Ein Wechsel des Scopes bricht den Zugriff auf
alle Dateien, die nicht von der App stammen — bestehende Nutzer würden ihre
Sicherungen nicht wiederfinden. Das ist eine Produktentscheidung, keine
Code-Korrektur.

### 🟡 L-32 — `state`-Parameter ist kein Zufallswert

`add_remote_wizard.dart:236`:

```dart
final state = Uri.encodeQueryComponent(remoteName);
```

RFC 6749 §10.12 verlangt für `state` einen nicht vorhersagbaren Wert als
CSRF-Schutz. Hier ist es der vom Nutzer vergebene Remote-Name — vorhersagbar.
Zusätzlich wird `state` beim Callback in `oauth_service.dart` gar nicht
ausgewertet; die Zuordnung läuft über den Namen aus dem Textfeld.

**Nicht umgesetzt.** Ein echter Fix braucht eine `state`-Generierung mit
Zufallsanteil plus Verifikation beim Callback — das zieht sich durch
`OAuthService.authorize`, `flutter_web_auth_2` und den Wizard. Gehört in einen
eigenen Commit mit Test.

---

## Offene Punkte, sortiert nach Dringlichkeit

| # | Befund | Was zu tun ist | Wer |
|---|---|---|---|
| 1 | L-08 | Name + ladungsfähige Anschrift in Impressum eintragen | du |
| 2 | L-16 | Bundle-ID vor der ersten Store-Einreichung ändern (danach unmöglich) | du + Code |
| 3 | L-24 | DPMA-/EUIPO-Recherche für „Fibu", Klassen 9 und 42 | du |
| 4 | L-23 | Vertriebsweg festlegen (TestFlight / App Store), CI-Artefakt prüfen | du |
| 5 | L-29 | Eigene Google-OAuth-App anlegen, `client_id`-Abfrage in der App | Code |
| 6 | L-05 | `docs/DATENSCHUTZ.md` als GitHub Pages veröffentlichen → URL für App Store Connect | du |
| 7 | L-20 | `fibuoauth`-Intent-Filter in AndroidManifest.xml | Code |
| 8 | L-17 | `en.lproj/InfoPlist.strings` | Code |
| 9 | L-32 | `state` mit Zufallsanteil + Callback-Verifikation | Code |
| 10 | L-13 | Nach erstem Xcode-Archive den Privacy Report gegen das Manifest abgleichen | du (Xcode) |

## Was hier nicht geprüft werden konnte

- **Kein Flutter/Dart in dieser Umgebung.** `flutter analyze` und
  `flutter test` laufen nur in CI (`.github/workflows/build-ios.yml`).
  Dart-Änderungen sind hier nicht kompilierbar.
- **Kein macOS/Xcode.** Der Privacy Report (`Product → Archive → Generate
  Privacy Report`) kann nicht erzeugt werden; ob librclone tatsächlich
  `stat`/`mach_absolute_time` referenziert, ist deshalb Annahme, nicht Befund.
- **Kein Registerzugriff.** DPMA und EUIPO waren nicht erreichbar (L-24).
- **Kein Gerät.** OAuth-Flows, Keychain-Verhalten und Permission-Dialoge sind
  aus dem Code gelesen, nicht ausgeführt.
- **Keine Rechtsberatung.** Dieses Dokument ersetzt keinen Anwalt.
