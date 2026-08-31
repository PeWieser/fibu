import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../theme/theme.dart';

/// Ein Abschnitt eines Rechtstexts (Überschrift + Fließtext).
class LegalDocSection {
  final String heading;
  final String body;
  const LegalDocSection(this.heading, this.body);
}

/// Die Rechtstexte der App: Datenschutzerklärung und Impressum.
///
/// Warum als Volltext und nicht nur als Link: App Store Review Guideline
/// 5.1.1 verlangt einen leicht erreichbaren Zugang zur Datenschutzerklärung
/// *in der App*. Fibu hat keine eigene Website, also ist dieser Volltext die
/// Datenschutzerklärung. Derselbe Text liegt unter `docs/DATENSCHUTZ.md` und
/// `docs/IMPRESSUM.md`; daraus kann die öffentliche URL erzeugt werden, die
/// App Store Connect und Google Play verlangen.
///
/// Pflegehinweis: Jede Änderung an Datenflüssen (neuer Provider, neuer
/// Dritt-Server, neues Plugin mit Netzwerkzugriff) muss hier nachgezogen
/// werden — die Erklärung ist sonst unwahr, und das ist der eigentliche
/// Rechtsverstoß.
class LegalDocuments {
  const LegalDocuments._();

  /// Kontakt- bzw. Anbieterkennung. Muss vor einer Veröffentlichung durch die
  /// echte ladungsfähige Anschrift ersetzt werden (siehe docs/RECHTS_AUDIT.md).
  static String providerName(bool german) =>
      german ? 'PeWieser (Einzelentwickler)' : 'PeWieser (individual developer)';

  static List<LegalDocSection> privacy(bool german) => german
      ? [
          const LegalDocSection(
            'Kurz gesagt',
            'Fibu hat keinen eigenen Server. Die App enthält keine Analytics-, '
                'Werbungs- oder Absturz-SDKs, legt keine Konten an und überträgt '
                'nichts an den Entwickler. Alles, was die App liest — Fotos, '
                'Videos, Dateien und deine Zugangsdaten — bleibt auf deinem Gerät '
                'oder geht ausschließlich in die Cloud-Konten, die du selbst '
                'eingerichtet hast.',
          ),
          LegalDocSection(
            'Verantwortlicher',
            '${providerName(german)}\n'
                'Kontakt und Quellcode: https://github.com/PeWieser/fibu\n\n'
                'Verantwortlich im Sinne der DSGVO ist für die Datenverarbeitung '
                'durch die App der Entwickler. Für die Inhalte, die du in deine '
                'eigenen Cloud-Konten sicherst, bist du selbst verantwortlich.',
          ),
          const LegalDocSection(
            'Welche Daten auf dem Gerät verarbeitet werden',
            '• Fotos, Videos und Alben aus deiner Mediathek (nur nach deiner '
                'Freigabe, nur die ausgewählten Alben).\n'
                '• Dateien und Ordner, die du über die Dateien-App auswählst.\n'
                '• Zugangsdaten für deine Cloud-Konten (Passwörter, API-Schlüssel, '
                'OAuth-Tokens).\n'
                '• Technische Zustandsdaten: Aufgaben, Synchronisationsstände, '
                'Dateiliste mit Name, Größe und Änderungszeit, Geräte-Sprache, '
                'Erscheinungsbild.\n\n'
                'Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO (Vertrag über die '
                'Nutzung der App) bzw. Art. 6 Abs. 1 lit. f DSGVO — das berechtigte '
                'Interesse besteht darin, die Sicherung deiner eigenen Daten '
                'überhaupt durchführen zu können.',
          ),
          const LegalDocSection(
            'Wo Zugangsdaten liegen',
            'Auf iOS und macOS werden Zugangsdaten im nativen Apple-Schlüsselbund '
                '(Security.framework) gespeichert, Zugriffsklasse '
                '„After First Unlock, this device only“. Sie werden damit nicht in '
                'ein Geräte-Backup und nicht auf ein anderes Gerät übertragen. Auf '
                'anderen Plattformen liegen sie in einer Datei im privaten '
                'App-Ordner. Zugangsdaten werden niemals protokolliert und niemals '
                'an den Entwickler übermittelt.',
          ),
          const LegalDocSection(
            'Anmeldung über OAuth — wichtiger Hinweis zu rclone.org',
            'Fibu nutzt für die Cloud-Anbindung die quelloffene Bibliothek rclone. '
                'Wenn du bei einem Anbieter keinen eigenen „client_id“ hinterlegst, '
                'verwendet die App die öffentlich geteilte Anmeldung des '
                'rclone-Projekts. Dabei wird der Anmeldevorgang über den Server '
                'https://rclone.org/oauth/ des rclone-Projekts (Nick Craig-Wood) '
                'geleitet.\n\n'
                'An diesen Server werden übermittelt: die Kennung des Anbieters '
                '(z. B. „dropbox“), der von dir vergebene interne Name des '
                'Laufwerks und der vom Anbieter ausgestellte Autorisierungscode. '
                'Es werden keine Inhalte deiner Dateien übertragen.\n\n'
                'Wenn du das nicht möchtest, kannst du für jeden Anbieter eine '
                'eigene client_id anlegen. Dann verbindet sich die App direkt mit '
                'dem Anbieter und rclone.org ist nicht beteiligt.',
          ),
          const LegalDocSection(
            'Wohin deine Dateien gehen',
            'Die App überträgt deine Dateien ausschließlich an die Cloud-Dienste, '
                'die du selbst verbunden hast (z. B. Google Drive, OneDrive, '
                'Dropbox, MEGA, Backblaze, eigene WebDAV-/SFTP-/S3-Server). '
                'Empfänger ist damit der jeweilige Dienstanbieter, mit dem du '
                'einen eigenen Vertrag hast — nicht der Entwickler dieser App. '
                'Der Entwickler hat zu keinem Zeitpunkt Zugriff auf deine Dateien '
                'und erhält keine Kopie.\n\n'
                'Sitzt dein Anbieter außerhalb der EU, stützt er den Transfer in '
                'der Regel auf die Standardvertragsklauseln der EU-Kommission. '
                'Einzelheiten findest du in der Datenschutzerklärung des jeweiligen '
                'Anbieters.',
          ),
          const LegalDocSection(
            'Berechtigungen',
            '• Fotos: Nur nach deiner Freigabe. Bei eingeschränkter Freigabe '
                '(„Auswahl …“) sieht die App ausschließlich die von dir gewählten '
                'Bilder.\n'
                '• Dateien: Nur die Ordner, die du über die Dateien-App freigibst.\n'
                '• Netzwerk: Für die Übertragung an deine Cloud-Konten.\n'
                '• Hintergrundaktualisierung: Für geplante Sicherungen, die iOS '
                'zeitlich selbst steuert.\n\n'
                'Du kannst jede Berechtigung jederzeit in den Systemeinstellungen '
                'widerrufen.',
          ),
          const LegalDocSection(
            'Diagnoseprotokoll',
            'Die App führt ein Protokoll über ihre eigenen Aktionen. Darin stehen '
                'Zeitstempel, Dateinamen, Albennamen und Zielordner — also auch '
                'personenbezogene Daten. Zugangsdaten werden nie protokolliert. '
                'Die Datei liegt im privaten App-Ordner und ist in der '
                'Dateien-App nicht sichtbar. Sie verlässt das Gerät nur, wenn du '
                'sie selbst kopierst und weitergibst — etwa für eine '
                'Fehlermeldung.',
          ),
          const LegalDocSection(
            'Speicherdauer und Löschung',
            'Alle Daten liegen nur so lange auf dem Gerät, bis du sie löschst. '
                'Das Entfernen eines Cloud-Laufwerks löscht dessen Zugangsdaten '
                'aus dem Schlüsselbund. Das Löschen der App entfernt sämtliche '
                'lokalen Daten; was bereits in deine Cloud-Konten übertragen '
                'wurde, bleibt dort und muss dort gelöscht werden.',
          ),
          const LegalDocSection(
            'Deine Rechte',
            'Dir stehen die Rechte aus Art. 15 bis 21 DSGVO zu: Auskunft, '
                'Berichtigung, Löschung, Einschränkung der Verarbeitung, '
                'Datenübertragbarkeit und Widerspruch. Da die App keine Daten an '
                'den Entwickler übermittelt, bestehen praktisch keine '
                'beim Entwickler gespeicherten Datenbestände; die Auskunft bezieht '
                'sich dann auf die Kontaktdaten und den Umgang mit Anfragen.\n\n'
                'Beschwerden kannst du bei jeder Datenschutz-Aufsichtsbehörde '
                'einreichen (Art. 77 DSGVO), in Deutschland bei der für dein '
                'Bundesland zuständigen Landesbeauftragten.',
          ),
          const LegalDocSection(
            'Nicht genutzt werden',
            'Tracking, Werbung, Profiling, automatisierte Entscheidungen im Sinne '
                'des Art. 22 DSGVO, Weiterverkauf von Daten und eine Verarbeitung '
                'von Kinderdaten. Die App richtet sich nicht gezielt an Kinder '
                'unter 16 Jahren.',
          ),
          const LegalDocSection(
            'Änderungen',
            'Diese Erklärung wird angepasst, sobald sich Datenflüsse ändern — '
                'etwa durch neue Anbieter oder neue Funktionen. Die jeweils '
                'aktuelle Fassung findest du immer an dieser Stelle in der App.',
          ),
        ]
      : [
          const LegalDocSection(
            'In short',
            'Fibu has no server of its own. The app contains no analytics, '
                'advertising or crash SDKs, does not create accounts and sends '
                'nothing to the developer. Everything the app reads — photos, '
                'videos, files and your credentials — stays on your device or goes '
                'exclusively to the cloud accounts you connected yourself.',
          ),
          LegalDocSection(
            'Controller',
            '${providerName(german)}\n'
                'Contact and source code: https://github.com/PeWieser/fibu\n\n'
                'The developer is the controller for the processing performed by '
                'the app. For the content you back up into your own cloud '
                'accounts, you are the controller.',
          ),
          const LegalDocSection(
            'Data processed on the device',
            '• Photos, videos and albums from your library (only after you grant '
                'access, and only the albums you select).\n'
                '• Files and folders you pick through the Files app.\n'
                '• Credentials for your cloud accounts (passwords, API keys, '
                'OAuth tokens).\n'
                '• Technical state: tasks, sync progress, file lists with name, '
                'size and modification time, device language, appearance.\n\n'
                'The legal basis is Art. 6(1)(b) GDPR (performance of the '
                'contract for using the app) and Art. 6(1)(f) GDPR — the '
                'legitimate interest being that backing up your own data is '
                'impossible without this processing.',
          ),
          const LegalDocSection(
            'Where credentials are stored',
            'On iOS and macOS credentials are stored in the native Apple Keychain '
                '(Security.framework) with the access class “After First Unlock, '
                'this device only”. They are therefore never written into a device '
                'backup and never migrated to another device. On other platforms '
                'they are kept in a file inside the private app folder. '
                'Credentials are never logged and never sent to the developer.',
          ),
          const LegalDocSection(
            'OAuth sign-in — important note on rclone.org',
            'Fibu uses the open-source library rclone for cloud access. If you do '
                'not provide your own “client_id” for a provider, the app uses the '
                'shared credentials published by the rclone project. In that case '
                'the sign-in is routed through the rclone project server at '
                'https://rclone.org/oauth/ (operated by Nick Craig-Wood).\n\n'
                'What is transmitted to that server: the provider identifier (for '
                'example “dropbox”), the internal name you gave the drive, and the '
                'authorization code issued by the provider. No file content is '
                'transmitted.\n\n'
                'If you prefer not to do this, create your own client_id for each '
                'provider. The app then talks to the provider directly and '
                'rclone.org is not involved.',
          ),
          const LegalDocSection(
            'Where your files go',
            'The app uploads your files only to the cloud services you connected '
                'yourself (for example Google Drive, OneDrive, Dropbox, MEGA, '
                'Backblaze, or your own WebDAV/SFTP/S3 server). The recipient is '
                'therefore that service provider, with whom you have your own '
                'contract — not the developer of this app. The developer never has '
                'access to your files and receives no copy.\n\n'
                'If your provider is located outside the EU, the transfer is '
                'usually based on the EU Commission standard contractual clauses. '
                'Details are in that provider’s own privacy policy.',
          ),
          const LegalDocSection(
            'Permissions',
            '• Photos: only after you grant access. With limited access '
                '(“Select …”) the app sees only the items you chose.\n'
                '• Files: only the folders you share through the Files app.\n'
                '• Network: to transfer data to your cloud accounts.\n'
                '• Background refresh: for scheduled backups, whose timing iOS '
                'controls itself.\n\n'
                'You can revoke any permission at any time in the system '
                'settings.',
          ),
          const LegalDocSection(
            'Diagnostics log',
            'The app keeps a log of its own actions. It contains timestamps, file '
                'names, album names and target folders — that is, personal data. '
                'Credentials are never logged. The file lives in the private app '
                'folder and is not visible in the Files app. It leaves the device '
                'only if you copy and share it yourself, for example when filing a '
                'bug report.',
          ),
          const LegalDocSection(
            'Retention and deletion',
            'All data stays on the device only for as long as you keep it. '
                'Removing a cloud drive deletes its credentials from the Keychain. '
                'Deleting the app removes all local data; anything already '
                'uploaded to your cloud accounts stays there and must be deleted '
                'there.',
          ),
          const LegalDocSection(
            'Your rights',
            'You have the rights under Art. 15 to 21 GDPR: access, '
                'rectification, erasure, restriction, portability and objection. '
                'Since the app sends no data to the developer, there is in '
                'practice no stored dataset held by the developer; access then '
                'relates to the contact details and to how enquiries are '
                'handled.\n\n'
                'You may lodge a complaint with any data protection supervisory '
                'authority (Art. 77 GDPR).',
          ),
          const LegalDocSection(
            'Not used',
            'Tracking, advertising, profiling, automated decision-making under '
                'Art. 22 GDPR, selling of data, and processing of children’s '
                'data. The app is not directed at children under 16.',
          ),
          const LegalDocSection(
            'Changes',
            'This notice is updated whenever data flows change — for example '
                'through new providers or new features. The current version is '
                'always available at this place in the app.',
          ),
        ];

  static List<LegalDocSection> imprint(bool german) => german
      ? [
          LegalDocSection(
            'Anbieter',
            '${providerName(german)}\n'
                '[Name und ladungsfähige Anschrift vor Veröffentlichung ergänzen — '
                'siehe docs/RECHTS_AUDIT.md, Befund L-08]\n\n'
                'Kontakt: https://github.com/PeWieser/fibu',
          ),
          const LegalDocSection(
            'Angaben zur App',
            'Name: Fibu — Multi-Cloud-Backup für Mediendateien\n'
                'Plattformen: iOS, Android, Windows\n'
                'Vertriebsweg: derzeit keine Veröffentlichung in einem App Store; '
                'der Quellcode ist öffentlich.\n'
                'Lizenz: MIT-Lizenz (vollständiger Text unter „Open-Source-Lizenzen“).',
          ),
          const LegalDocSection(
            'Verantwortlich für den Inhalt',
            'Verantwortlich im Sinne des § 18 Abs. 2 MStV ist der oben genannte '
                'Anbieter.',
          ),
          const LegalDocSection(
            'Haftung für Inhalte',
            'Die App ist ein Werkzeug zur Sicherung eigener Daten. Der Anbieter '
                'übernimmt keine Gewähr dafür, dass eine Sicherung vollständig, '
                'fehlerfrei oder wiederherstellbar ist. Eine Sicherung ersetzt '
                'keine eigene Prüfung der Wiederherstellbarkeit. Wer die App für '
                'geschäftliche oder aufbewahrungspflichtige Unterlagen einsetzt, '
                'ist für die Einhaltung seiner Aufbewahrungspflichten (u. a. '
                '§ 147 AO, § 257 HGB, GoBD) selbst verantwortlich.',
          ),
          const LegalDocSection(
            'Urheberrecht und Marken',
            'Die App enthält Open-Source-Software Dritter, die unter ihren '
                'jeweiligen Bedingungen eingebunden ist; die vollständige Liste '
                'steht unter „Open-Source-Lizenzen“. „rclone“ ist ein Projekt von '
                'Nick Craig-Wood und den rclone-Mitwirkenden. Fibu ist ein '
                'unabhängiges Projekt und wird vom rclone-Projekt weder betrieben '
                'noch gebilligt. Genannte Marken und Namen Dritter (u. a. Google '
                'Drive, OneDrive, Dropbox) dienen ausschließlich der '
                'Kennzeichnung der unterstützten Dienste.',
          ),
          const LegalDocSection(
            'Streitbeilegung',
            'Der Anbieter ist nicht verpflichtet und nicht bereit, an einem '
                'Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle '
                'teilzunehmen.',
          ),
        ]
      : [
          LegalDocSection(
            'Provider',
            '${providerName(german)}\n'
                '[Full legal name and postal address to be added before release — '
                'see docs/RECHTS_AUDIT.md, finding L-08]\n\n'
                'Contact: https://github.com/PeWieser/fibu',
          ),
          const LegalDocSection(
            'About the app',
            'Name: Fibu — multi-cloud backup for media files\n'
                'Platforms: iOS, Android, Windows\n'
                'Distribution: not published in an app store at this time; the '
                'source code is public.\n'
                'License: MIT License (full text under “Open-Source Licenses”).',
          ),
          const LegalDocSection(
            'Responsible for the content',
            'Responsible within the meaning of § 18(2) MStV (German Interstate '
                'Media Treaty) is the provider named above.',
          ),
          const LegalDocSection(
            'Liability for content',
            'The app is a tool for backing up your own data. The provider gives no '
                'warranty that a backup is complete, error-free or restorable. A '
                'backup does not replace verifying for yourself that restoration '
                'works. If you use the app for business records or records you are '
                'required to retain, you remain responsible for meeting those '
                'obligations.',
          ),
          const LegalDocSection(
            'Copyright and trademarks',
            'The app includes third-party open-source software under its own '
                'terms; the complete list is available under “Open-Source '
                'Licenses”. “rclone” is a project of Nick Craig-Wood and the '
                'rclone contributors. Fibu is an independent project and is '
                'neither operated nor endorsed by the rclone project. Third-party '
                'names and marks mentioned (including Google Drive, OneDrive, '
                'Dropbox) are used solely to identify the supported services.',
          ),
          const LegalDocSection(
            'Dispute resolution',
            'The provider is neither obliged nor willing to take part in dispute '
                'resolution proceedings before a consumer arbitration board.',
          ),
        ];
}

/// Ansicht für einen Rechtstext (Datenschutzerklärung / Impressum).
class LegalDocumentScreen extends ConsumerWidget {
  final String title;
  final List<LegalDocSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme live verfolgen, damit Dark-/Light-/Palettenwechsel sofort greift.
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;

    final content = ListView(
      padding: EdgeInsets.all(theme.lg),
      children: [
        for (final section in sections) ...[
          Text(
            section.heading,
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: theme.sm),
          // Ausgewählte Systemschrift statt 'monospace': Rechtstext braucht
          // keine Festbreitenschrift, Lesbarkeit geht vor.
          Text(
            section.body,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              height: 1.55,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: theme.xl),
        ],
      ],
    );

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(title),
          previousPageTitle: strings.back,
          backgroundColor: theme.surface,
        ),
        child: SafeArea(child: content),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(title),
          leading: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: fluent.IconButton(
                icon: const Icon(fluent.FluentIcons.back, semanticLabel: 'Back'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        content: content,
      );
    }
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        title: Text(title),
        backgroundColor: theme.surface,
        elevation: 0,
      ),
      body: content,
    );
  }
}
