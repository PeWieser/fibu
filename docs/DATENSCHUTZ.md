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
Cloud-Konten, die du selbst eingerichtet hast.

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
device only". Sie werden damit nicht in ein Geräte-Backup und nicht auf ein
anderes Gerät übertragen. Auf anderen Plattformen liegen sie in einer Datei im
privaten App-Ordner. Zugangsdaten werden niemals protokolliert und niemals an
den Entwickler übermittelt.

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
