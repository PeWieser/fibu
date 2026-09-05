# Datenschutzerklärung — Fibu

> Diese Fassung ist die veröffentlichbare Form des Textes, der in der App unter
> **Einstellungen → Rechtliches → Datenschutzerklärung** steht. Quelle des
> Textes ist `lib/features/settings/presentation/legal_documents_screen.dart`
> (`LegalDocuments.privacy`). **Beide Fassungen müssen gleich bleiben** — eine
> Datenschutzerklärung, die nicht dem tatsächlichen Datenfluss entspricht, ist
> der eigentliche Rechtsverstoß.
>
> Diese Datei kann unverändert über GitHub Pages veröffentlicht werden; die
> daraus entstehende URL gehört in das Feld „Privacy Policy URL" in App Store
> Connect und in die Data-Safety-Angaben der Play Console.

---

## Kurz gesagt

Fibu hat keinen eigenen Server. Die App enthält keine Analytics-, Werbungs-
oder Absturz-SDKs, legt keine Konten an und überträgt nichts an den
Entwickler. Alles, was die App liest — Fotos, Videos, Dateien und deine
Zugangsdaten — bleibt auf deinem Gerät oder geht ausschließlich in die
Cloud-Konten, die du selbst eingerichtet hast. Auf ein anderes Gerät gelangt
etwas nur, wenn du die Gerät-zu-Gerät-Übertragung selbst auslöst und am
Empfänger bestätigst.

## Verantwortlicher

PeWieser (Einzelentwickler)
Kontakt und Quellcode: <https://github.com/PeWieser/fibu>

Verantwortlich im Sinne der DSGVO ist für die Datenverarbeitung durch die App
der Entwickler. Für die Inhalte, die du in deine eigenen Cloud-Konten
sicherst, bist du selbst verantwortlich.

## Welche Daten auf dem Gerät verarbeitet werden

- Fotos, Videos und Alben aus deiner Mediathek (nur nach deiner Freigabe, nur
  die ausgewählten Alben).
- Dateien und Ordner, die du über die Dateien-App auswählst.
- Zugangsdaten für deine Cloud-Konten (Passwörter, API-Schlüssel,
  OAuth-Tokens).
- Technische Zustandsdaten: Aufgaben, Synchronisationsstände, Dateiliste mit
  Name, Größe und Änderungszeit, Geräte-Sprache, Erscheinungsbild.

Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO (Vertrag über die Nutzung der
App) bzw. Art. 6 Abs. 1 lit. f DSGVO — das berechtigte Interesse besteht
darin, die Sicherung deiner eigenen Daten überhaupt durchführen zu können.

## Wo Zugangsdaten liegen

Auf iOS und macOS werden Zugangsdaten im nativen Apple-Schlüsselbund
(Security.framework) gespeichert, Zugriffsklasse „After First Unlock, this
device only". Sie gelangen damit **nicht** in ein Geräte-Backup (iCloud-Backup,
iTunes) und verlassen das Gerät nicht von selbst. Auf anderen Plattformen
liegen sie in einer Datei im privaten App-Ordner. Zugangsdaten werden niemals
protokolliert und niemals an den Entwickler übermittelt.

Die einzige Ausnahme ist die Übertragung, die du selbst auslöst — siehe
nächsten Abschnitt.

## Konfiguration von Gerät zu Gerät übertragen

Wenn du ein zweites Gerät einrichtest, kannst du Laufwerke, Zugangsdaten und
Aufgaben direkt von einem Gerät auf das andere übertragen. Dabei gilt:

- **Nur dein lokales Netz.** Die Daten gehen direkt von Gerät zu Gerät
  (WLAN/LAN). Es gibt keinen Server dazwischen, keine Cloud und kein Konto —
  der Entwickler sieht nichts davon.
- **Nur auf deinen ausdrücklichen Wunsch.** Das sendende Gerät überträgt erst
  nach einem Tipp auf ein gefundenes Gerät. Das empfangende Gerät schreibt
  nichts, bevor du dort „Übernehmen" angetippt hast; vorher siehst du, von
  welchem Gerät die Konfiguration kommt und wie viele Laufwerke und Aufgaben
  sie enthält. „Ablehnen" ändert nichts.
- **Verschlüsselt.** Die Übertragung ist mit AES-256-GCM verschlüsselt; der
  Schlüssel wird je Sitzung zufällig erzeugt. Eine verfälschte Übertragung
  fällt beim Entschlüsseln auf und wird verworfen.
- **Sichtbar im Netz, solange du wartest.** Ein Gerät, das auf eine
  Konfiguration wartet, meldet seinen Namen und seine Adresse im lokalen Netz
  (UDP-Port 47831), damit das andere Gerät es finden kann. In einem fremden
  Netz (Hotel, Café) solltest du die Funktion deshalb nicht offen laufen
  lassen. Geschrieben wird am Empfänger trotzdem nichts ohne deine
  Bestätigung.
- **Was übernommen wird:** `rclone.conf` (Laufwerke **mit** Zugangsdaten),
  die Laufwerksliste und die Aufgaben. Aufgaben, die auf die Foto-Mediathek
  des anderen Geräts zeigen, bekommen ihre Quelle entzogen und müssen neu
  gewählt werden. Bestehende Laufwerke und Aufgaben auf dem Empfänger werden
  dabei ersetzt.

Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO — die Übertragung ist die
Durchführung der von dir gewünschten Funktion.

## Anmeldung über OAuth — wichtiger Hinweis zu rclone.org

Fibu nutzt für die Cloud-Anbindung die quelloffene Bibliothek rclone. Wenn du
bei einem Anbieter keinen eigenen „client_id" hinterlegst, verwendet die App
die öffentlich geteilte Anmeldung des rclone-Projekts. Dabei wird der
Anmeldevorgang über den Server <https://rclone.org/oauth/> des rclone-Projekts
(Nick Craig-Wood) geleitet.

An diesen Server werden übermittelt: die Kennung des Anbieters (z. B.
„dropbox"), der von dir vergebene interne Name des Laufwerks und der vom
Anbieter ausgestellte Autorisierungscode. Es werden keine Inhalte deiner
Dateien übertragen.

Wenn du das nicht möchtest, kannst du für jeden Anbieter eine eigene
client_id anlegen. Dann verbindet sich die App direkt mit dem Anbieter und
rclone.org ist nicht beteiligt.

## Wohin deine Dateien gehen

Die App überträgt deine Dateien ausschließlich an die Cloud-Dienste, die du
selbst verbunden hast (z. B. Google Drive, OneDrive, Dropbox, MEGA, Backblaze,
eigene WebDAV-/SFTP-/S3-Server). Empfänger ist damit der jeweilige
Dienstanbieter, mit dem du einen eigenen Vertrag hast — nicht der Entwickler
dieser App. Der Entwickler hat zu keinem Zeitpunkt Zugriff auf deine Dateien
und erhält keine Kopie.

Sitzt dein Anbieter außerhalb der EU, stützt er den Transfer in der Regel auf
die Standardvertragsklauseln der EU-Kommission. Einzelheiten findest du in der
Datenschutzerklärung des jeweiligen Anbieters.

## Berechtigungen

- **Fotos:** Nur nach deiner Freigabe. Bei eingeschränkter Freigabe
  („Auswahl …") sieht die App ausschließlich die von dir gewählten Bilder.
- **Dateien:** Nur die Ordner, die du über die Dateien-App freigibst.
- **Netzwerk:** Für die Übertragung an deine Cloud-Konten.
- **Lokales Netz (iOS):** Nur für die Gerät-zu-Gerät-Übertragung. iOS fragt
  einmal nach, ob Fibu Geräte im selben Netz finden darf. Ohne diese Freigabe
  funktioniert allein die Übertragung nicht — Sicherung und Wiederherstellung
  laufen davon unberührt.
- **Hintergrundaktualisierung:** Für geplante Sicherungen, die iOS zeitlich
  selbst steuert.

Du kannst jede Berechtigung jederzeit in den Systemeinstellungen widerrufen.

## Diagnoseprotokoll

Die App führt ein Protokoll über ihre eigenen Aktionen. Darin stehen
Zeitstempel, Dateinamen, Albennamen und Zielordner — also auch
personenbezogene Daten. Zugangsdaten werden nie protokolliert. Die Datei liegt
im privaten App-Ordner und ist in der Dateien-App nicht sichtbar. Sie verlässt
das Gerät nur, wenn du sie selbst kopierst und weitergibst — etwa für eine
Fehlermeldung.

## Speicherdauer und Löschung

Alle Daten liegen nur so lange auf dem Gerät, bis du sie löschst. Das
Entfernen eines Cloud-Laufwerks löscht dessen Zugangsdaten aus dem
Schlüsselbund. Das Löschen der App entfernt sämtliche lokalen Daten; was
bereits in deine Cloud-Konten übertragen wurde, bleibt dort und muss dort
gelöscht werden.

## Deine Rechte

Dir stehen die Rechte aus Art. 15 bis 21 DSGVO zu: Auskunft, Berichtigung,
Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und
Widerspruch. Da die App keine Daten an den Entwickler übermittelt, bestehen
praktisch keine beim Entwickler gespeicherten Datenbestände; die Auskunft
bezieht sich dann auf die Kontaktdaten und den Umgang mit Anfragen.

Beschwerden kannst du bei jeder Datenschutz-Aufsichtsbehörde einreichen
(Art. 77 DSGVO), in Deutschland bei der für dein Bundesland zuständigen
Landesbeauftragten.

## Nicht genutzt werden

Tracking, Werbung, Profiling, automatisierte Entscheidungen im Sinne des
Art. 22 DSGVO, Weiterverkauf von Daten und eine Verarbeitung von Kinderdaten.
Die App richtet sich nicht gezielt an Kinder unter 16 Jahren.

## Änderungen

Diese Erklärung wird angepasst, sobald sich Datenflüsse ändern — etwa durch
neue Anbieter oder neue Funktionen. Die jeweils aktuelle Fassung findest du
immer an dieser Stelle und in der App.
