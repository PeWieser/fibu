import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_provider.dart';

/// Comprehensive localization dictionary for German (de) and English (en).
class AppStrings {
  final AppLocale locale;

  const AppStrings(this.locale);

  /// Aktive Strings für Schichten ohne BuildContext/Ref (z. B. Sync-Engine,
  /// die Fortschrittstexte produziert). Wird vom [stringsProvider] aktuell
  /// gehalten; Fallback ist Deutsch.
  static AppStrings current = const AppStrings(AppLocale.de);

  bool get isGerman => locale == AppLocale.de;

  // --- Navigation ---
  String get navDashboard => isGerman ? 'Übersicht' : 'Dashboard';
  String get navTasks => isGerman ? 'Aufgaben' : 'Tasks';
  String get navSettings => isGerman ? 'Einstellungen' : 'Settings';
  String get navCloudExplorer => isGerman ? 'Dateiexplorer' : 'Cloud Explorer';

  // --- Common Actions ---
  String get save => isGerman ? 'Speichern' : 'Save';
  String get cancel => isGerman ? 'Abbrechen' : 'Cancel';
  String get delete => isGerman ? 'Löschen' : 'Delete';
  String get disconnect => isGerman ? 'Trennen' : 'Disconnect';
  String get close => isGerman ? 'Schließen' : 'Close';
  String get add => isGerman ? 'Hinzufügen' : 'Add';
  String get next => isGerman ? 'Weiter' : 'Next';
  String get back => isGerman ? 'Zurück' : 'Back';
  String get ok => isGerman ? 'OK' : 'OK';
  String get refresh => isGerman ? 'Aktualisieren' : 'Refresh';
  String get edit => isGerman ? 'Bearbeiten' : 'Edit';
  String get loading => isGerman ? 'Wird geladen...' : 'Loading...';
  String get error => isGerman ? 'Fehler' : 'Error';
  String get success => isGerman ? 'Erfolgreich' : 'Success';
  String get retry => isGerman ? 'Wiederholen' : 'Retry';
  String get name => isGerman ? 'Name' : 'Name';
  String get active => isGerman ? 'Aktiv' : 'Active';
  String get paused => isGerman ? 'Pausiert' : 'Paused';
  String get refreshedSuccess => isGerman ? 'Aktualisiert' : 'Refreshed';
  String get drivesRefreshed => isGerman ? 'Cloud-Laufwerke & Speicherplatz wurden aktualisiert.' : 'Cloud drives and quota refreshed.';
  String get filesRefreshed => isGerman ? 'Dateiliste aktualisiert.' : 'File listing refreshed.';

  // --- Dashboard ---
  String get dashboardTitle => isGerman ? 'Backup Übersicht' : 'Backup Dashboard';
  String get allFilesSynced => isGerman ? 'Alle Dateien synchronisiert' : 'All Files Synced';
  String get syncActive => isGerman ? 'Synchronisierung läuft...' : 'Syncing Active...';
  String get syncCancelled => isGerman ? 'Synchronisierung abgebrochen' : 'Sync Cancelled';
  String get syncFailed => isGerman ? 'Synchronisierung fehlgeschlagen' : 'Sync Failed';
  String get syncAll => isGerman ? 'Alle synchronisieren' : 'Sync All Files';
  String get cancelSync => isGerman ? 'Sync abbrechen' : 'Cancel Sync';
  /// Öffnet den Fotos-Manager des Laufwerks (früher: Dateiexplorer).
  String get exploreRemoteFiles =>
      isGerman ? 'Fotos in der Cloud ansehen' : 'View Photos in the Cloud';
  String get viewActivityLogs => isGerman ? 'Aktivitätsprotokoll anzeigen' : 'View Activity Logs';
  String get activityLogsTitle => isGerman ? 'Aktivitätsprotokoll' : 'Activity Logs';
  String get noActivityLogs => isGerman ? 'Keine Protokolleinträge vorhanden.' : 'No activity logs recorded.';
  String get cloudBackupStorage => isGerman ? 'Cloud-Speicherplatz' : 'Cloud Backup Storage';
  String get noDrivesConfigured => isGerman ? 'Keine Backup-Laufwerke eingerichtet. Füge eines in den Einstellungen hinzu.' : 'No backup drives configured. Add one in Settings.';
  String get activeTaskProgress => isGerman ? 'Aktueller Fortschritt' : 'Active Task Progress';
  String get currentFile => isGerman ? 'Aktuelle Datei:' : 'Current File:';
  String get preparing => isGerman ? 'Wird vorbereitet...' : 'Preparing...';
  String get tooltipStorageCard => isGerman ? 'Klicke hier für die detaillierte Speicherbelegung nach Dateitypen.' : 'Click here for detailed storage breakdown by file type.';
  String get tooltipSyncBanner => isGerman ? 'Klicke hier, um das vollständige Aktivitätsprotokoll anzuzeigen.' : 'Click here to view activity logs.';



  // --- Cloud Drives & Wizard ---
  String get cloudDrivesTitle => isGerman ? 'Cloud-Laufwerke verwalten' : 'Manage Cloud Drives';
  String get addCloudDrive => isGerman ? 'Laufwerk hinzufügen' : 'Add Cloud Drive';
  String get connectedDrives => isGerman ? 'Verbundene Laufwerke' : 'Connected Drives';
  String get noDrivesConnected => isGerman ? 'Noch keine Cloud verbunden' : 'No cloud connected yet';
  String get noDrivesDescription => isGerman
      ? 'Deine Fotos und Dateien sind dann sicher — auch wenn du dein Gerät verlierst.'
      : 'Your photos and files will be safe — even if you lose your device.';
  String get wizardStep1Title => isGerman ? 'Schritt 1: Anbieter auswählen' : 'Step 1: Choose Provider';
  String get wizardStep2Title => isGerman ? 'Schritt 2: Zugangsdaten' : 'Step 2: Credentials & Config';
  String get connectionNameLabel => isGerman ? 'Verbindungsname' : 'Connection Name';
  String get connectionNameHint => isGerman ? 'z.B. Mein_Cloud_Backup' : 'e.g. My_Cloud_Backup';
  String get searchProviderHint => isGerman ? 'Anbieter suchen (z.B. google, onedrive, s3, webdav, mega)...' : 'Search provider (e.g. google, onedrive, s3, webdav, mega)...';
  String get emailOrUserLabel => isGerman ? 'E-Mail / Benutzername' : 'Email / Username';
  String get passwordLabel => isGerman ? 'Passwort / API-Key' : 'Password / API Key';
  String get hostLabel => isGerman ? 'Host / Server-Adresse' : 'Host / Server Address';
  String get portLabel => isGerman ? 'Port' : 'Port';
  String get testConnection => isGerman ? 'Anmelden' : 'Sign In';
  /// Validierung für virtuelle Backends (Crypt, Union, …): Es gibt keine
  /// klassische Anmeldung — geprüft wird die Verbindung zum Basis-Laufwerk.
  String get validateSetup => isGerman ? 'Verbindung prüfen' : 'Validate Setup';
  String get providerGuideHeader => isGerman ? 'So funktioniert die Einrichtung' : 'How Setup Works';
  /// Hinweis, wenn Union/Crypt/… angelegt wird, aber noch kein Basis-Laufwerk da ist.
  String get noBaseDrivesForVirtual => isGerman
      ? 'Zuerst ein normales Cloud-Laufwerk verbinden — danach kannst du es hier auswählen.'
      : 'Connect a regular cloud drive first — then you can pick it here.';
  /// Accessibility-Suffix für ausgewählte Laufwerke in der Multiple-Choice-Liste.
  String get selectedLabel => isGerman ? 'ausgewählt' : 'selected';
  String get connectionSuccess => isGerman ? 'Angemeldet – Verbindung steht.' : 'Signed in – connection works.';
  String get oauthMissingClientHint => isGerman
      ? 'Dieser Anbieter braucht eine eigene Anmeldung im Browser. Die ist hier noch nicht eingerichtet.'
      : 'This provider needs a browser sign-in that is not set up yet.';
  String get connectionFailed => isGerman ? 'Anmeldung fehlgeschlagen' : 'Sign-in failed';
  String get nameRequiredError => isGerman ? 'Bitte gib einen Verbindungsnamen ein.' : 'Please enter a connection name.';
  String get providerRequiredError => isGerman ? 'Bitte wähle einen Anbieter aus der Liste aus.' : 'Please select a provider from the list.';
  String get credentialsRequiredError => isGerman ? 'Bitte fülle alle Pflichtfelder aus.' : 'Please fill in all required credentials.';
  String get deleteDriveConfirmTitle => isGerman ? 'Cloud-Laufwerk trennen' : 'Disconnect Cloud Remote';
  String get deleteDriveRule6Notice => isGerman
      ? 'Bereits hochgeladene Dateien bleiben in der Cloud erhalten.'
      : 'Already uploaded files will remain stored in the cloud.';
  String deleteDrivePrompt(String name) => isGerman
      ? 'Möchtest du die Verbindung zu „$name“ wirklich trennen?'
      : 'Do you really want to disconnect from “$name”?';
  // --- Remote-Registry: Umbenennen & Identität ---
  String get renameDrive => isGerman ? 'Umbenennen' : 'Rename';
  String get renameDriveTitle => isGerman ? 'Laufwerk umbenennen' : 'Rename Remote';
  String get renameDriveDescription => isGerman
      ? 'Der Name wird nur lokal in der App angezeigt. Verbindung, Zugangsdaten und Aufgaben bleiben unverändert.'
      : 'The name is only displayed locally in the app. Connection, credentials and tasks stay unchanged.';
  String driveRenamedSuccess(String name) => isGerman
      ? 'Laufwerk heißt jetzt „$name“.'
      : 'Remote is now named “$name”.';
  String deleteDriveTasksWarning(int count) => isGerman
      ? (count == 1
          ? 'Achtung: 1 Aufgabe nutzt dieses Laufwerk und schlägt danach fehl, bis du ihr ein neues Ziel gibst.'
          : 'Achtung: $count Aufgaben nutzen dieses Laufwerk und schlagen danach fehl, bis du ihnen ein neues Ziel gibst.')
      : (count == 1
          ? 'Warning: 1 task uses this remote and will fail until you assign a new target.'
          : 'Warning: $count tasks use this remote and will fail until you assign a new target.');
  String get remoteMissingBadge =>
      isGerman ? 'nicht gefunden' : 'missing';
  String remoteMissingInTask(String id) => isGerman
      ? 'Remote nicht mehr verbunden (Kennung: $id). Weise der Aufgabe ein neues Ziel zu — Verbindungen verwaltest du unter Cloud-Laufwerke.'
      : 'Remote is no longer connected (id: $id). Assign a new target to this task — manage connections under Cloud Drives.';

  // --- Aufgaben-Bearbeitung (Alben & Moduswechsel) ---
  String get albumsSectionTitle => isGerman ? 'Alben' : 'Albums';
  String get albumsEditNote => isGerman
      ? 'Ohne Auswahl wird die gesamte Mediathek gesichert.'
      : 'With nothing selected, the entire library is backed up.';
  String get syncModeChangedNote => isGerman
      ? 'Modus wird nach „Fertig“ aktiv.'
      : 'Mode applies after you tap Done.';
  String get mirrorAdoptionHint => isGerman
      ? 'Beim ersten Spiegel-Lauf werden bereits gesicherte Cloud-Dateien übernommen — nichts wird erneut herunter- oder hochgeladen.'
      : 'On the first mirror run, files already stored in the cloud are adopted — nothing is downloaded or uploaded again.';
  String get mirrorDeletionWarningEdit => isGerman
      ? 'Spiegelung ist 2-Wege: Lokal gelöschte Dateien werden auch in der Cloud entfernt.'
      : 'Mirror is two-way: files deleted locally are also removed from the cloud.';

  String get oauthInfoNotice => isGerman
      ? 'Kein Passwort hier. Du meldest dich direkt beim Anbieter im Browser an.'
      : 'No password here. You sign in with the provider in the browser.';
  String get oauthGenericTooltip => isGerman
      ? 'OAuth 2.0 ermöglicht eine sichere Anmeldung direkt beim Anbieter ohne Speicherung deines Passworts.'
      : 'OAuth 2.0 enables secure login directly with the provider without storing your password.';
  String get authorizeInBrowser => isGerman ? 'Beim Anbieter anmelden' : 'Sign in with provider';
  String get authorizedSuccess => isGerman ? 'Autorisierung erfolgreich verifiziert' : 'Authorization verified successfully';
  String get testingConnection => isGerman ? 'Verbindung wird getestet...' : 'Testing connection...';
  String get addingRemote => isGerman ? 'Laufwerk wird eingerichtet...' : 'Configuring remote...';
  String get deletingRemote => isGerman ? 'Laufwerk wird getrennt...' : 'Disconnecting remote...';
  String driveAddedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk „$name“ wurde erfolgreich hinzugefügt.'
      : 'Cloud drive “$name” added successfully.';
  String driveDeletedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk „$name“ wurde getrennt.'
      : 'Cloud drive “$name” disconnected.';
  String get noMatchingProviders => isGerman ? 'Keine passenden Anbieter gefunden.' : 'No matching providers found.';
  String get showPassword => isGerman ? 'Passwort anzeigen' : 'Show password';
  String get hidePassword => isGerman ? 'Passwort verbergen' : 'Hide password';
  String get connectionNameTooltip => isGerman
      ? 'Ein eindeutiger Name zur Identifikation dieses Cloud-Laufwerks (z.B. Mein_Cloud_Drive).'
      : 'A unique display name to identify this cloud drive (e.g. My_Cloud_Drive).';
  String get searchProviderTooltip => isGerman
      ? 'Suche nach Cloud-Speicher-Anbietern wie Google Drive, OneDrive, Dropbox, Mega, S3, WebDAV, SFTP etc.'
      : 'Search for cloud storage providers such as Google Drive, OneDrive, Dropbox, Mega, S3, WebDAV, SFTP etc.';
  String get emailOrUserTooltip => isGerman
      ? 'Deine E-Mail-Adresse oder dein Benutzername für diesen Cloud-Dienst.'
      : 'Your email address or username for this cloud service.';
  String get passwordTooltip => isGerman
      ? 'Dein Passwort oder API-Token. Wird vor dem Speichern sicher verschlüsselt.'
      : 'Your password or API token. Encrypted securely before saving.';
  String get hostTooltip => isGerman
      ? 'Die Server-Adresse, URL oder Hostname (z.B. sftp.example.com oder 192.168.1.10).'
      : 'The server address, URL, or hostname (e.g. sftp.example.com or 192.168.1.10).';
  String get portTooltip => isGerman
      ? 'Der Netzwerk-Port des Dienstes (Standard: SFTP 22, FTP 21).'
      : 'The network port of the service (Default: SFTP 22, FTP 21).';

  // --- Provider-Specific Strings & Tooltips ---
  String get megaUserLabel => isGerman ? 'Mega E-Mail' : 'Mega Email';
  String get megaUserTooltip => isGerman ? 'Die E-Mail-Adresse deines Mega.nz-Kontos.' : 'The email address of your Mega.nz account.';
  String get megaPassLabel => isGerman ? 'Mega Passwort' : 'Mega Password';
  String get megaPassTooltip => isGerman ? 'Dein Passwort für Mega.nz. Es wird vor dem Speichern sicher verschlüsselt.' : 'Your password for Mega.nz. Encrypted before saving.';
  
  String get s3AccessKeyLabel => isGerman ? 'Access Key ID' : 'Access Key ID';
  String get s3AccessKeyTooltip => isGerman ? 'Dein S3 Access Key ID (z.B. aus der AWS IAM Konsole, Backblaze B2 Application Keys oder MinIO Dashboard).' : 'Your S3 Access Key ID (e.g. from AWS IAM, Backblaze B2, or MinIO dashboard).';
  String get s3SecretKeyLabel => isGerman ? 'Secret Access Key' : 'Secret Access Key';
  String get s3SecretKeyTooltip => isGerman ? 'Dein geheimer S3 Secret Access Key.' : 'Your secret S3 Secret Access Key.';
  String get s3EndpointLabel => isGerman ? 'S3 Endpoint / Host URL' : 'S3 Endpoint / Host URL';
  String get s3EndpointTooltip => isGerman ? 'Der Endpunkt des S3-kompatiblen Dienstes (z.B. s3.eu-central-1.amazonaws.com oder s3.us-west-004.backblazeb2.com).' : 'The endpoint URL for your S3-compatible service.';
  
  String get webdavUrlLabel => isGerman ? 'WebDAV Server-Adresse / URL' : 'WebDAV Server Address / URL';
  String get webdavUrlTooltip => isGerman ? 'Die vollständige WebDAV-URL deines Cloud-Servers (z.B. Nextcloud/ownCloud: https://cloud.example.com/remote.php/dav/files/user/).' : 'The full WebDAV URL of your cloud server (e.g. Nextcloud/ownCloud).';
  String get webdavUserLabel => isGerman ? 'WebDAV Benutzername / E-Mail' : 'WebDAV Username / Email';
  String get webdavUserTooltip => isGerman ? 'Dein Benutzername auf dem WebDAV-Server.' : 'Your username on the WebDAV server.';
  String get webdavPassLabel => isGerman ? 'WebDAV Passwort / App-Token' : 'WebDAV Password / App Token';
  String get webdavPassTooltip => isGerman ? 'Dein Passwort oder generiertes App-Token (empfohlen für Nextcloud/ownCloud).' : 'Your password or generated app token.';
  
  String get sftpHostLabel => isGerman ? 'SFTP Host / Server' : 'SFTP Host / Server';
  String get sftpHostTooltip => isGerman ? 'Die IP-Adresse oder Hostname deines SSH/SFTP-Servers.' : 'The IP or hostname of your SSH/SFTP server.';
  String get sftpPortLabel => isGerman ? 'Port' : 'Port';
  String get sftpPortTooltip => isGerman ? 'Standard: 22 für SFTP, 21 für FTP.' : 'Default: 22 for SFTP, 21 for FTP.';
  String get sftpUserLabel => isGerman ? 'SSH / SFTP Benutzername' : 'SSH / SFTP Username';
  String get sftpUserTooltip => isGerman ? 'Der Benutzername für den SSH/SFTP-Zugang.' : 'The username for SSH/SFTP access.';
  String get sftpPassLabel => isGerman ? 'Passwort / Key-Passphrase' : 'Password / Key Passphrase';
  String get sftpPassTooltip => isGerman ? 'Das Passwort für den Benutzer oder die Passphrase für den SSH-Schlüssel.' : 'Password or SSH key passphrase.';

  // --- Tasks & Backup Modes ---
  String get tasksTitle => isGerman ? 'Backup-Aufgaben' : 'Tasks & Backup Jobs';
  String get addTask => isGerman ? 'Aufgabe erstellen' : 'Add Task';
  String get editTask => isGerman ? 'Aufgabe bearbeiten' : 'Edit Task';
  String get deleteTask => isGerman ? 'Aufgabe löschen' : 'Delete Task';
  String get taskNameLabel => isGerman ? 'Aufgabenname' : 'Task Name';
  String get taskNameHint => isGerman ? 'z.B. Kamera-Fotos Backup' : 'e.g. Camera Photos Backup';
  String get sourcePathLabel => isGerman ? 'Quellordner (Lokal)' : 'Source Folder (Local)';
  String get sourcePathHint => isGerman ? 'z.B. C:\\Bilder' : 'e.g. C:\\Pictures';
  String get selectFolder => isGerman ? 'Ordner wählen' : 'Select Folder';
  String get destinationRemoteLabel => isGerman ? 'Ziel-Cloud-Laufwerke' : 'Destination Cloud Drives';
  String get selectAtLeastOneRemote => isGerman ? 'Bitte wähle mindestens ein Cloud-Laufwerk als Ziel aus.' : 'Please select at least one cloud drive as destination.';
  String get scheduleLabel => isGerman ? 'Zeitplan' : 'Schedule';
  String get scheduleDayLabel => isGerman ? 'Wiederholung' : 'Repeat Frequency';
  String get scheduleTimeLabel => isGerman ? 'Uhrzeit' : 'Time';
  String get sourceCategoryLabel => isGerman ? 'Was soll gesichert werden?' : 'What should be backed up?';
  String get sourceTabPhotosVideos => isGerman ? 'Fotos & Videos' : 'Photos & Videos';
  String get sourceTabFiles => isGerman ? 'Dateien' : 'Files';
  String get selectAllAlbums => isGerman ? 'Alle auswählen' : 'Select All';
  String get selectAllFolders => isGerman ? 'Alle auswählen' : 'Select All';
  String albumMediaCount(int count) => isGerman
      ? (count == 1 ? '1 Foto/Video' : '$count Fotos/Videos')
      : (count == 1 ? '1 photo/video' : '$count photos/videos');
  String albumsTotalMediaCount(int count) => isGerman
      ? 'Insgesamt ${albumMediaCount(count)}'
      : 'Total: ${albumMediaCount(count)}';
  String get emptySelectionAlbumsHint => isGerman
      ? 'Wähle mindestens ein Album aus, damit deine Medien gesichert werden.'
      : 'Select at least one album so your media gets backed up.';
  String get emptySelectionFoldersHint => isGerman
      ? 'Keine Ordner ausgewählt – bitte mindestens einen Ordner wählen.'
      : 'No folders selected – please choose at least one folder.';
  String get targetFolderUp => isGerman ? 'Eine Ebene höher' : 'Up one level';
  String get targetFolderCurrentPath => isGerman ? 'Aktueller Ordner' : 'Current folder';
  String get albumSelectionLabel => isGerman ? 'Alben auswählen' : 'Select Albums';
  String get folderSelectionLabel => isGerman ? 'Lokale Ordner auswählen' : 'Select Local Folders';
  String get noAlbumsFound => isGerman
      ? 'Keine Alben gefunden. Erteile Fotos-Zugriff, um deine Alben zu sehen.'
      : 'No albums found. Grant photo access to see your albums.';
  String get noFoldersFound => isGerman
      ? 'Keine lokalen Ordner gefunden.'
      : 'No local folders found.';
  String get chooseLocalFolder => isGerman ? 'Ordner aus Dateien-App wählen' : 'Choose Folder from Files';
  String get targetFolderExistingLabel => isGerman ? 'Vorhandener Ordner (in der Cloud)' : 'Existing Folder (in cloud)';
  String get targetFolderRemoteHint => isGerman
      ? 'Durchsuche die vorhandenen Ordner in der Cloud (Remote).'
      : 'Browse existing folders in the cloud (remote).';
  String get remoteFolderEmpty => isGerman ? 'Kein Ordner im Cloud-Laufwerk gefunden.' : 'No folders found in this cloud drive.';
  String get remoteFoldersLoadError => isGerman ? 'Cloud-Ordner konnten nicht geladen werden.' : 'Could not load cloud folders.';
  String get targetFolderNameLabel => isGerman ? 'Neuer Ordnername in der Cloud' : 'New cloud folder name';
  String get catchUpNotice => isGerman
      ? 'Verpasste Backups werden automatisch beim nächsten Systemstart nachgeholt.'
      : 'Missed scheduled backups are caught up automatically on next system startup.';
  String get deleteTaskConfirmTitle => isGerman ? 'Backup-Aufgabe löschen' : 'Delete Backup Task';
  String get deleteTaskRule6Notice => isGerman
      ? 'Die bereits hochgeladenen Dateien in der Cloud bleiben erhalten.'
      : 'Already uploaded files in the cloud will remain intact.';
  String deleteTaskPrompt(String name) => isGerman
      ? 'Möchtest du die Aufgabe „$name“ wirklich löschen?'
      : 'Do you really want to delete the task “$name”?';
  String get taskNameRequiredError => isGerman ? 'Bitte gib einen Namen für die Aufgabe ein.' : 'Please enter a task name.';
  String get sourcePathRequiredError => isGerman ? 'Bitte wähle einen Quellpfad aus.' : 'Please select a source path.';
  String get noTasksConfigured => isGerman ? 'Noch keine Aufgabe' : 'No task yet';
  String get noTasksDescription => isGerman
      ? 'Deine Fotos sichern sich dann automatisch in deine Cloud — du musst nichts mehr tun.'
      : 'Your photos will then back themselves up to your cloud — nothing left for you to do.';
  String get activeSyncJob => isGerman ? 'Aktiver Backup-Job' : 'Active Backup Job';
  String get sourcePrefix => isGerman ? 'Quelle:' : 'Source:';
  String get destinationPrefix => isGerman ? 'Ziel:' : 'Destination:';
  String get schedulePrefix => isGerman ? 'Zeitplan:' : 'Schedule:';
  String get hourLabel => isGerman ? 'Stunde' : 'Hour';
  String get minuteLabel => isGerman ? 'Minute' : 'Minute';
  String get allMedia => isGerman ? 'Alles' : 'All';
  String get allPhotos => isGerman ? 'Alle Fotos' : 'All Photos';
  String get allVideos => isGerman ? 'Alle Videos' : 'All Videos';
  String get specificFolders => isGerman ? 'Nur bestimmte Ordner' : 'Specific Folders Only';
  String get specificFoldersShort => isGerman ? 'Ordner' : 'Folders';
  String get specificFoldersHint => isGerman ? 'z.B. WhatsApp Images' : 'e.g. WhatsApp Images';
  String get backupJobsHeader => isGerman ? 'BACKUP-AUFGABEN' : 'BACKUP JOBS';

  // --- Multi-Remote Distribution Strategy ---
  String get distributionStrategyLabel => isGerman ? 'Verteilungs-Strategie' : 'Distribution Strategy';
  String get distributionMirrorAll => isGerman ? 'Vollständige Redundanz (Alle Drives)' : 'Full Redundancy (All Drives)';
  String get distributionMirrorAllDesc => isGerman
      ? 'Jede Datei wird auf alle ausgewählten Cloud-Laufwerke gesichert (maximale Sicherheit).'
      : 'Every file is backed up to all selected cloud drives (maximum safety).';
  String get distributionBalance => isGerman ? 'Automatische Speicherplatz-Aufteilung' : 'Automatic Space Balancing';
  String get distributionBalanceDesc => isGerman
      ? 'Dateien werden intelligent und proportional nach verfügbarem Speicherplatz auf die Drives aufgeteilt.'
      : 'Files are distributed intelligently across drives based on available storage capacity.';
  String get distributionBadgeMirrorAll => isGerman ? 'Redundant (Alle Drives)' : 'Redundant (All Drives)';
  String get distributionBadgeBalance => isGerman ? 'Aufgeteilt (Balanciert)' : 'Space Balanced';
  String get distributionTooltip => isGerman
      ? 'Bestimmt, wie Backups bei mehreren ausgewählten Cloud-Laufwerken abgelegt werden.'
      : 'Determines how files are stored when multiple cloud drives are selected.';

  // --- Cloud Target Folder Mode ---
  String get targetFolderModeLabel => isGerman ? 'Speicherort in der Cloud' : 'Cloud Destination Folder';
  String get targetFolderRoot => isGerman ? 'Hauptverzeichnis (Root /)' : 'Root Directory (/)';
  String get targetFolderCustom => isGerman ? 'Bestehender Ordner' : 'Existing Folder';
  String get targetFolderNew => isGerman ? 'Neuen Ordner anlegen' : 'Create New Folder';
  String get newFolderNameLabel => isGerman ? 'Neuer Ordnername' : 'New Folder Name';
  String get newFolderNameHint => isGerman ? 'z.B. backup_fotos_2026' : 'e.g. backup_photos_2026';
  String get targetFolderTooltip => isGerman
      ? 'Wähle, ob die Dateien direkt im Stammverzeichnis oder in einem Unterordner in der Cloud gespeichert werden sollen.'
      : 'Choose whether files should be stored in the root directory or a subfolder in the cloud.';

  // --- Sync Modes (Incremental vs Mirror / Spiegelung, 2-Wege) ---
  // "Abgleichmethode" instead of "Synchronisations-Modus" to avoid the
  // duplicated "Synchronisation" wording next to section headers.
  String get syncModeLabel => isGerman ? 'Abgleichmethode' : 'Sync Method';
  String get syncModeIncremental => isGerman ? 'Inkrementell' : 'Incremental';
  String get syncModeIncrementalDescription => isGerman
      ? 'Nur neue und geänderte Dateien hochladen. In der Cloud vorhandene Dateien bleiben immer erhalten (sicher).'
      : 'Upload only new and modified files. Remote cloud files are always preserved (safe).';
  String get syncModeMirror => isGerman ? 'Spiegelung (2-Wege Mirror-Sync)' : 'Mirror Sync (two-way)';
  String get syncModeMirrorDescription => isGerman
      ? 'Exakte 2-Wege-Spiegelung: Neue Dateien aus der Cloud werden auch lokal heruntergeladen. Dateien, die du lokal löschst, werden auch in der Cloud gelöscht!'
      : 'Exact 2-way mirror: New files from cloud are downloaded locally. Files deleted locally will also be deleted in the cloud!';
  String get syncModeBadgeIncremental => isGerman ? 'Inkrementell' : 'Incremental';
  String get syncModeBadgeMirror => isGerman ? 'Spiegelung' : 'Mirror Sync';
  String get syncModeTooltipIncremental => isGerman
      ? 'Modus Inkrementell: Neue Dateien hochladen, gelöschte Dateien in der Cloud behalten'
      : 'Incremental mode: Uploads new files, preserves deleted files in cloud';
  String get syncModeTooltipMirror => isGerman
      ? 'Spiegelung (2-Wege): Vollständiger Abgleich zwischen lokalem Ordner und Cloud inkl. Download neuer Cloud-Dateien und Löschabgleich'
      : 'Mirror mode (two-way): Full synchronization between local and cloud including cloud downloads and delete mirroring';

  String excludedFilesBadge(int count) => isGerman
      ? (count == 1 ? '1 Datei ausgeschlossen' : '$count Dateien ausgeschlossen')
      : (count == 1 ? '1 file excluded' : '$count files excluded');
  String excludedFilesTooltip(int count) => isGerman
      ? '$count ausgeschlossene ${count == 1 ? 'Datei' : 'Dateien'}'
      : '$count excluded ${count == 1 ? 'file' : 'files'}';
  String get dayDaily => isGerman ? 'Täglich' : 'Daily';
  String get dayMonday => isGerman ? 'Montag' : 'Monday';
  String get dayTuesday => isGerman ? 'Dienstag' : 'Tuesday';
  String get dayWednesday => isGerman ? 'Mittwoch' : 'Wednesday';
  String get dayThursday => isGerman ? 'Donnerstag' : 'Thursday';
  String get dayFriday => isGerman ? 'Freitag' : 'Friday';
  String get daySaturday => isGerman ? 'Samstag' : 'Saturday';
  String get daySunday => isGerman ? 'Sonntag' : 'Sunday';
  String get dayManual => isGerman ? 'Manuell' : 'Manual';
  String scheduleDisplay({required String day, required String time}) {
    if (day == 'Manual') return isGerman ? 'Manuell' : 'Manual';
    if (day == 'Daily') return isGerman ? 'Täglich um $time' : 'Daily at $time';
    return isGerman ? 'Wöchentlich ($day) um $time' : 'Weekly on ${day}s at $time';
  }

  // --- Tooltips for Tasks ---
  String get tooltipSourcePath => isGerman ? 'Lokaler Ordner auf deinem Computer, dessen Inhalt gesichert wird.' : 'Local folder on your PC that will be backed up.';
  String get tooltipDestinationRemote => isGerman ? 'Ziel-Cloud-Laufwerke und Remote-Ordner.' : 'Destination cloud drives and target folder.';
  String get tooltipCatchUp => isGerman ? 'Wenn dein PC zur geplanten Zeit aus war, wird das Backup beim nächsten Systemstart automatisch nachgeholt.' : 'If PC was offline during scheduled time, backup runs on next startup.';
  String get tooltipSchedule => isGerman ? 'Intervall und Uhrzeit für die automatische Ausführung des Backups.' : 'Interval and time for automatic backup execution.';

  // --- Cloud Explorer & File Details ---
  String get cloudExplorerTitle => isGerman ? 'Cloud-Dateiexplorer' : 'Cloud File Explorer';

  // --- Cloud-Fotos (Fotos-Manager statt Dateiexplorer) ---
  String get cloudPhotosTitle => isGerman ? 'Fotos in der Cloud' : 'Photos in the Cloud';
  String get cloudPhotosAlbums => isGerman ? 'Alben' : 'Albums';
  String get cloudPhotosRecent => isGerman ? 'Zuletzt' : 'Recents';
  String cloudPhotosCount(int n) =>
      isGerman ? '$n ${n == 1 ? 'Aufnahme' : 'Aufnahmen'}' : '$n ${n == 1 ? 'item' : 'items'}';
  String get cloudPhotosEmptyShort => isGerman ? 'Leer' : 'Empty';
  String get cloudPhotosEmptyTitle =>
      isGerman ? 'Keine Aufnahmen gefunden' : 'No photos found';
  String get cloudPhotosEmptyBody => isGerman
      ? 'In diesem Laufwerk liegt noch keine gesicherte Mediathek unter '
          '„fibu-backup/Photos". Sobald eine Sicherungsaufgabe gelaufen ist, '
          'erscheinen hier die Alben.'
      : 'This drive has no backed-up library under “fibu-backup/Photos” yet. '
          'Once a backup task has run, the albums show up here.';
  String get cloudPhotosUnknownDate =>
      isGerman ? 'Ohne Datum' : 'No date';

  /// Tagesüberschrift in der Aufnahmenliste, z. B. „23. September 2026".
  /// Ohne `intl`-Paket — die Monatsnamen reichen hier und halten die
  /// Abhängigkeiten klein.
  String cloudPhotosDayLabel(DateTime day) {
    const monthsDe = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final months = isGerman ? monthsDe : monthsEn;
    final m = months[day.month - 1];
    return isGerman ? '${day.day}. $m ${day.year}' : '$m ${day.day}, ${day.year}';
  }
  String get remoteDriveSelectorLabel => isGerman ? 'Cloud-Laufwerk' : 'Remote Drive';
  String get emptyFolder => isGerman ? 'Dieser Ordner ist leer.' : 'This folder is empty.';
  String get noRemotesInExplorer => isGerman ? 'Keine Cloud-Laufwerke verbunden.' : 'No cloud drives connected.';
  String get addRemoteCTA => isGerman ? 'Laufwerk hinzufügen' : 'Add Cloud Drive';
  String get fileDetailsTitle => isGerman ? 'Datei-Informationen & Metadaten' : 'File Information & Metadata';
  String get fileName => isGerman ? 'Dateiname:' : 'File Name:';
  String get fileSize => isGerman ? 'Dateigröße:' : 'File Size:';
  String get fileModTime => isGerman ? 'Zuletzt geändert:' : 'Last Modified:';
  String get filePath => isGerman ? 'Pfad:' : 'Path:';
  String get downloadFile => isGerman ? 'Herunterladen' : 'Download';
  String get downloadComplete => isGerman ? 'Heruntergeladen nach' : 'Downloaded to';
  String get downloadFailed => isGerman ? 'Download fehlgeschlagen:' : 'Download failed:';
  String get deleteFile => isGerman ? 'Datei löschen' : 'Delete File';
  String get deleteFileConfirmTitle => isGerman ? 'Datei in der Cloud löschen' : 'Delete Cloud File';
  String deleteFileRule6Notice(String name) => isGerman
      ? 'Dateien, die du in der Cloud löschst, werden nicht wiederhergestellt. Zudem wird eine Ausschlussregel erstellt, damit die lokale Datei beim nächsten Sync nicht erneut hochgeladen wird.'
      : 'Files deleted in the cloud cannot be restored. An exclusion rule will be created so local files will not be re-uploaded on the next sync.';
  String deleteFilePrompt(String name) => isGerman
      ? 'Möchtest du „$name“ wirklich aus dem Cloud-Speicher löschen?'
      : 'Do you really want to delete “$name” from cloud storage?';
  String get excludeRuleCreated => isGerman ? 'Ausschlussregel erfolgreich erstellt.' : 'Exclusion rule created successfully.';
  String get previewFile => isGerman ? 'Vorschau' : 'Preview';
  String get quickLook => isGerman ? 'Schnellübersicht' : 'Quick Look';
  String get openInDefaultApp => isGerman ? 'In Standard-App öffnen' : 'Open in Default App';
  String get copyPath => isGerman ? 'Pfad kopieren' : 'Copy Path';
  String get pathCopied => isGerman ? 'Pfad in die Zwischenablage kopiert' : 'Path copied to clipboard';
  String get openingFile => isGerman ? 'Datei wird geöffnet...' : 'Opening file...';
  String get downloadingForPreview => isGerman ? 'Wird für Vorschau geladen...' : 'Loading for preview...';
  String get copy => isGerman ? 'Kopieren' : 'Copy';
  String get copied => isGerman ? 'Kopiert!' : 'Copied!';
  String get zoomIn => isGerman ? 'Vergrößern' : 'Zoom In';
  String get zoomOut => isGerman ? 'Verkleinern' : 'Zoom Out';
  String get resetZoom => isGerman ? 'Originalgröße' : 'Reset Zoom';
  String get playAudio => isGerman ? 'Abspielen' : 'Play';
  String get pauseAudio => isGerman ? 'Pausieren' : 'Pause';
  String get linesLabel => isGerman ? 'Zeilen' : 'Lines';
  String get wordsLabel => isGerman ? 'Wörter' : 'Words';
  String get charactersLabel => isGerman ? 'Zeichen' : 'Characters';
  String get cloudRemote => isGerman ? 'Cloud-Remote:' : 'Cloud Remote:';

  // --- File Metadata Inspector Attributes ---
  String get metadataSectionGeneral => isGerman ? 'Allgemeine Informationen' : 'General Information';
  String get metadataSectionDetails => isGerman ? 'Spezifische Metadaten' : 'Detailed Metadata';
  String get metadataFileType => isGerman ? 'Dateiformat:' : 'File Format:';
  String get metadataMimeType => isGerman ? 'MIME-Typ:' : 'MIME Type:';
  String get metadataExactBytes => isGerman ? 'Genaue Größe:' : 'Exact Size:';
  String get metadataDimensions => isGerman ? 'Abmessungen:' : 'Dimensions:';
  String get metadataMegapixels => isGerman ? 'Auflösung:' : 'Resolution:';
  String get metadataColorSpace => isGerman ? 'Farbraum:' : 'Color Space:';
  String get metadataCamera => isGerman ? 'Kamera-Modell:' : 'Camera:';
  String get metadataLens => isGerman ? 'Objektiv:' : 'Lens:';
  String get metadataExposure => isGerman ? 'Belichtung:' : 'Exposure:';
  String get metadataIso => isGerman ? 'ISO-Wert:' : 'ISO:';
  String get metadataAperture => isGerman ? 'Blende:' : 'Aperture:';
  String get metadataCodec => isGerman ? 'Video-Codec:' : 'Video Codec:';
  String get metadataFramerate => isGerman ? 'Bildrate:' : 'Framerate:';
  String get metadataAudioFormat => isGerman ? 'Audio-Format:' : 'Audio Format:';
  String get metadataBitrate => isGerman ? 'Bitrate:' : 'Bitrate:';
  String get metadataDuration => isGerman ? 'Dauer:' : 'Duration:';
  String get metadataLineCount => isGerman ? 'Zeilenanzahl:' : 'Line Count:';
  String get metadataCharCount => isGerman ? 'Zeichenanzahl:' : 'Character Count:';
  String get metadataEncoding => isGerman ? 'Zeichenkodierung:' : 'Encoding:';
  String get metadataCompression => isGerman ? 'Komprimierung:' : 'Compression:';

  // --- Settings ---
  String get settingsTitle => isGerman ? 'Einstellungen' : 'Settings';
  String get appearanceSection => isGerman ? 'Erscheinungsbild' : 'Appearance';
  String get syncWithSystem => isGerman ? 'Mit System synchronisieren' : 'Sync with System';
  String get useDarkMode => isGerman ? 'Dunkelmodus verwenden' : 'Use Dark Mode';
  String get lightModeSection => isGerman ? 'Light Mode Farbschema' : 'Light Mode Palettes';
  String get darkModeSection => isGerman ? 'Dark Mode Farbschema' : 'Dark Mode Palettes';
  String get lightModePalette => isGerman ? 'Light Mode Farbschema' : 'Light Mode Palette';
  String get darkModePalette => isGerman ? 'Dark Mode Farbschema' : 'Dark Mode Palette';
  String get themeMode => isGerman ? 'Farbschema-Modus' : 'Theme Mode';
  String get cloudStorage => isGerman ? 'Cloud-Speicher' : 'Cloud Storage';
  String get manageCloudDrives => isGerman ? 'Cloud-Laufwerke verwalten' : 'Manage Cloud Drives';
  String get languageSection => isGerman ? 'Sprache' : 'Language';
  String get selectedLanguage => isGerman ? 'Deutsch' : 'English';
  String get preferences => isGerman ? 'Region & Sprache' : 'Region & Language';
  String get appConfiguration => isGerman ? 'Anwendungskonfiguration' : 'Application Configuration';
  String get drivesSection => isGerman ? 'Cloud-Verbindungen' : 'Cloud Connections';
  String get manageDrivesSubtitle => isGerman ? 'Remotes verbinden, bearbeiten und trennen' : 'Connect, edit, and disconnect cloud remotes';
  String get aboutSection => isGerman ? 'Über Fibu' : 'About Fibu';
  String get tooltipNetwork => isGerman
      ? 'Lege fest, ob Backups auch über mobile Daten laufen dürfen.'
      : 'Choose whether backups may also run over cellular data.';

  /// Einstellung: Einsatz der Paletten-Charakterfarbe.
  String get primaryUsageSection =>
      isGerman ? 'Charakterfarbe' : 'Accent character colour';
  String get primaryUsageIdentity =>
      isGerman ? 'Nur Vorschau' : 'Preview only';
  String get primaryUsageIdentityHint => isGerman
      ? 'Die Charakterfarbe erscheint nur in der Paletten-Vorschau.'
      : 'The character colour appears only in the palette preview.';
  String get primaryUsageWash => isGerman ? 'Farbwaschung' : 'Colour wash';
  String get primaryUsageWashHint => isGerman
      ? 'Dezente Hintergrund-Tönung der Abschnitts-Titel. Rein dekorativ.'
      : 'Subtle background tint on section titles. Purely decorative.';
  String get primaryUsageAccessible =>
      isGerman ? 'Abgesichert' : 'Contrast-safe';
  String get primaryUsageAccessibleHint => isGerman
      ? 'Charakterfarbe färbt die Abschnitts-Titel, auf 3:1 Kontrast angehoben.'
      : 'Character colour tints section titles, raised to 3:1 contrast.';

  String get tooltipLanguage => isGerman ? 'Wähle die Sprache der Benutzeroberfläche.' : 'Choose the interface language.';
  String get tooltipThemeMode => isGerman
      ? 'Wähle zwischen automatischem System-Modus oder manuellem Dunkel-/Hellmodus.'
      : 'Choose between automatic system mode or manual dark/light mode.';
  String get tooltipWadaPalette => isGerman
      ? 'Wähle eine traditionelle japanische Sanzo Wada Farbpalette für ein harmonisches Design.'
      : 'Choose a traditional Japanese Sanzo Wada color palette for balanced styling.';

  // --- Task 3-Step Wizard ---
  // Titles are rendered next to the numbered step badges ("Schritt 1" etc.),
  // so they must not repeat the word "Schritt"/"Step" (avoid duplicates).
  String get taskWizardStep1Title => isGerman ? 'Grundlagen' : 'Basics';
  String get taskWizardStep1Subtitle => isGerman ? 'Aufgabenname & Quellverzeichnis' : 'Task name & source directory';
  String get taskWizardStep2Title => isGerman ? 'Cloud-Ziel' : 'Cloud Destination';
  String get taskWizardStep2Subtitle => isGerman ? 'Ziel-Laufwerke & Cloud-Ordner' : 'Destination drives & remote folder';
  String get taskWizardStep3Title => isGerman ? 'Zeitplan & Modus' : 'Schedule & Mode';
  String get taskWizardStep3Subtitle => isGerman ? 'Wiederholung & Abgleichmethode' : 'Recurrence & sync method';
  String get stepIndicator => isGerman ? 'Schritt' : 'Step';

  // --- Config Detection & Sync Logs ---
  String get existingConfigDetectedTitle => isGerman ? 'Bestehende Fibu-Konfiguration gefunden' : 'Existing Fibu Configuration Found';
  String existingConfigDetectedMessage(String remoteName) => isGerman
      ? 'Auf dem Cloud-Laufwerk „$remoteName“ wurde eine bestehende Fibu-Konfiguration (.fibu/config.json) gefunden.\n\nMöchtest du diese Konfiguration importieren und eine lokale Kopie samt Spiegel-Task anlegen?'
      : 'An existing Fibu configuration (.fibu/config.json) was found on cloud remote “$remoteName”.\n\nWould you like to import this configuration and create a local mirror sync task?';
  String get importConfigAndSync => isGerman ? 'Importieren & Spiegeln' : 'Import & Mirror';
  String get skipConfigImport => isGerman ? 'Überspringen' : 'Skip';
  String get configImportSuccess => isGerman ? 'Konfiguration übernommen.' : 'Configuration imported.';
  String get localLog => isGerman ? 'Lokales Protokoll' : 'Local Log';
  String get remoteLog => isGerman ? 'Remote-Protokoll' : 'Remote Log';
  String get defaultBackupFolder => isGerman ? 'fibu-backup' : 'fibu-backup';

  // --- iOS Background Sync Notice & WiFi-Only Sync ---
  String get iosBackgroundScheduleNotice => isGerman
      ? 'Hinweis: Unter iOS steuert das Betriebssystem Hintergrund-Backups (BGProcessingTask) eigenständig nach Kriterien wie Ladezustand, Inaktivität und WLAN-Verbindung. Eine feste Uhrzeit ist nicht erforderlich.'
      : 'Notice: On iOS, background backups (BGProcessingTask) are managed dynamically by the system when charging, idle, and connected to Wi-Fi. An exact minute schedule is not required.';
  String get iosBackgroundScheduleBadge => isGerman ? 'Automatisch (iOS System)' : 'Automatic (iOS System)';
  String get wifiOnlySyncLabel => isGerman ? 'Nur über WLAN synchronisieren' : 'Sync on Wi-Fi Only';
  String get wifiOnlySyncDescription => isGerman
      ? 'Verhindert die Datennutzung über Mobilfunkverbindungen, um dein mobiles Datenvolumen zu schonen.'
      : 'Prevents sync over cellular data connections to preserve your mobile data plan.';
  String get networkSectionTitle => isGerman ? 'Netzwerk & Mobilfunk' : 'Network & Cellular';

  // --- Task Presets ---
  String get presetSelectHeader => isGerman ? 'Vorlage wählen (Schnellstart)' : 'Select Preset (Quick Start)';
  String get presetSelectSubtitle => isGerman
      ? 'Wähle eine vorkonfigurierte Vorlage oder erstelle eine individuelle Aufgabe:'
      : 'Choose a preconfigured preset or create a custom task:';
  String get presetMediaMirrorTitle => isGerman ? 'Mediathek-Spiegelung (Fotos & Videos)' : 'Media Library Mirror (Photos & Videos)';
  String get presetMediaMirrorSubtitle => isGerman
      ? 'Vollständiges 2-Wege-Spiegel-Backup aller Fotos & Videos mit Cloud-Löschabgleich.'
      : 'Full 2-way mirror backup of all photos & videos with cloud deletion synchronization.';
  String get presetMediaMirrorBadge => isGerman ? '2-Wege Spiegelung' : '2-Way Mirror';
  String get presetMediaIncrementalTitle => isGerman ? 'Medien-Sicherung (Inkrementell)' : 'Media Backup (Incremental)';
  String get presetMediaIncrementalSubtitle => isGerman
      ? 'Sichert alle neuen Fotos und Videos in die Cloud; Cloud-Dateien bleiben stets erhalten.'
      : 'Uploads all new photos and videos to the cloud; cloud files are always preserved.';
  String get presetDocsTitle => isGerman ? 'Dokumente & Lokale Dateien' : 'Documents & Local Files';
  String get presetDocsSubtitle => isGerman
      ? 'Sichert alle lokalen Dokumente, PDFs und Arbeitsordner zuverlässig in die Cloud.'
      : 'Backs up local documents, PDFs, and working folders reliably to the cloud.';
  String get presetCustomTitle => isGerman ? 'Benutzerdefinierte Aufgabe' : 'Custom Task';
  String get presetCustomSubtitle => isGerman
      ? 'Alle Parameter (Quelle, Ordner, Zeitplan, Modus) schrittweise manuell festlegen.'
      : 'Configure all parameters (source, destination, schedule, mode) manually step-by-step.';
  String get usePresetButton => isGerman ? 'Vorlage anwenden' : 'Apply Preset';
  String get customizeTaskButton => isGerman ? 'Details anpassen' : 'Customize Details';

  // --- 70+ Provider Categories & Progressive Disclosure ---
  String get popularProvidersHeader => isGerman ? 'Beliebte Cloud-Dienste' : 'Popular Cloud Services';
  String get allProvidersHeader => isGerman ? 'Alle 70+ Cloud-Dienste' : 'All 70+ Cloud Services';
  String get categoryCloudStorage => isGerman ? 'Cloud-Speicher' : 'Cloud Storage';
  String get categoryS3Compatible => isGerman ? 'S3 & Object Storage' : 'S3 & Object Storage';
  String get categoryEnterprise => isGerman ? 'Enterprise & Native APIs' : 'Enterprise & Native APIs';
  String get categoryProtocols => isGerman ? 'Server & Protokolle' : 'Servers & Protocols';
  String get categoryWrappers => isGerman ? 'Verschlüsselung & Wrapper' : 'Encryption & Wrappers';
  String get advancedSettings => isGerman ? 'Erweiterte Einstellungen anzeigen' : 'Show Advanced Settings';
  String get hideAdvancedSettings => isGerman ? 'Erweiterte Einstellungen ausblenden' : 'Hide Advanced Settings';
  String get noMediaPermissionError => isGerman
      ? 'Zugriff auf Mediathek verweigert. Bitte erlaube den Foto-Zugriff in den iOS-Einstellungen.'
      : 'Photo library access denied. Please grant photo permission in iOS Settings.';
  String get networkUnavailableError => isGerman
      ? 'Keine aktive Internetverbindung vorhanden.'
      : 'No active internet connection available.';
  String get cellularSyncBlockedNotice => isGerman
      ? 'Synchronisierung pausiert: Verbindung über Mobilfunk nicht erlaubt (WLAN erforderlich).'
      : 'Sync paused: Cellular data connection blocked (Wi-Fi required).';

  // --- Offline-Banner & Netzwerk-Hinweise ---
  String get offlineBannerTitle => isGerman ? 'Offline' : 'Offline';
  String get offlineBannerMessage => isGerman
      ? 'Keine Internetverbindung – Synchronisierung pausiert, bis du wieder online bist.'
      : 'No internet connection – syncing is paused until you are back online.';
  String get syncBlockedOfflineLog => isGerman
      ? 'Sync blockiert: Offline (keine Internetverbindung).'
      : 'Sync blocked: offline (no internet connection).';
  String get syncBlockedCellularLog => isGerman
      ? 'Sync blockiert: Mobilfunkverbindung, WLAN-only ist aktiv (siehe Einstellungen).'
      : 'Sync blocked: on cellular, Wi-Fi-only is enabled (see Settings).';

  // --- Freundliche Sync-Fehlermeldungen ---
  String get syncAuthError => isGerman
      ? 'Authentifizierung fehlgeschlagen. Bitte verbinde das Cloud-Laufwerk in den Einstellungen neu.'
      : 'Authentication failed. Please reconnect the cloud drive in Settings.';
  String get remoteNotFoundHint => isGerman
      ? 'Das Cloud-Laufwerk ist nicht (mehr) verbunden — wurde das Remote gelöscht oder umbenannt? Bitte den Task anpassen oder das Laufwerk neu verbinden.'
      : 'The cloud drive is no longer connected — was the remote deleted or renamed? Please update the task or reconnect the drive.';
  String get syncQuotaError => isGerman
      ? 'Nicht genügend Speicherplatz im Cloud-Laufwerk verfügbar.'
      : 'Not enough storage space available on the cloud drive.';
  String get syncRemoteFullWarning => isGerman
      ? 'Nicht genug Speicherplatz in der Cloud für den Upload'
      : 'Not enough cloud storage space for the upload';
  String get syncLocalFullWarning => isGerman
      ? 'Nicht genug freier Speicher auf dem Gerät für den Download'
      : 'Not enough free device storage for the download';
  String syncItemsProgress(int done, int total) =>
      isGerman ? '$done von $total Dateien' : '$done of $total files';
  String get mirrorUpToDate => isGerman
      ? 'Alles aktuell — nichts zu übertragen.'
      : 'Everything is up to date — nothing to transfer.';
  String get selectAtLeastOneAlbum => isGerman
      ? 'Bitte wähle mindestens ein Album aus.'
      : 'Please select at least one album.';
  String get taskWizardNextBlockedHint => isGerman
      ? 'Wähle zuerst ein Album oder eine Datei-Quelle aus.'
      : 'Select an album or file source first.';
  String get onlySpecificAlbums => isGerman ? 'Nur bestimmte Alben' : 'Specific albums only';

  // --- Speicherplatz-Anzeige der Cloud-Laufwerke ---
  String get storageNotAvailable => isGerman ? 'n. v.' : 'n/a';
  String quotaSummaryUsedOf(String used, String total) =>
      isGerman ? '$used von $total belegt' : '$used of $total used';
  String get quotaSummaryUnavailable =>
      isGerman ? 'Speicherplatz n. v.' : 'Storage n/a';
  /// „n/a" für Werte, die nicht ermittelt werden können (nicht „0 MB").
  /// Ausstehende lokale Löschungen aus einem Hintergrundtask.
  String pendingDeletionsNotice(int count) => isGerman
      ? '$count lokale Löschung(en) ausstehend – antippen zum Ausführen'
      : '$count local deletion(s) pending – tap to run';
  String get pendingDeletionsTitle => isGerman
      ? 'Lokale Löschungen ausführen'
      : 'Run local deletions';
  String pendingDeletionsConfirm(int count) => isGerman
      ? 'Diese $count Dateien wurden in der Cloud gelöscht und sollen auch lokal entfernt werden. iOS fragt danach für jede Datei einzeln nach.'
      : 'These $count files were deleted in the cloud and should be removed locally too. iOS will ask for each file individually.';
  String pendingDeletionsDone(int count) => isGerman
      ? '$count Datei(en) lokal gelöscht.'
      : '$count file(s) deleted locally.';

  String get valueNotAvailable => isGerman ? 'n/a' : 'n/a';

  String get fibuSpaceLabel => isGerman ? 'Fibu-Beleg' : 'Used by Fibu';

  // --- Fehlerhinweise beim Verbinden ---
  String get invalidCredentialsHint => isGerman
      ? 'Zugangsdaten ungültig – bitte Benutzername/Passwort (und Host) prüfen.'
      : 'Invalid credentials – please check username/password (and host).';
  String get oauthAuthorizeFirstHint => isGerman
      ? 'Bitte zuerst über \u201eIn Browser autorisieren\u201c anmelden.'
      : 'Please authorize via “Authorize in browser” first.';
  String get testRequiredBeforeAddHint => isGerman
      ? 'Bitte zuerst erfolgreich über „Anmelden“ verbinden – erst dann kann das Laufwerk hinzugefügt werden.'
      : 'Please sign in successfully first – the drive can only be added afterwards.';
  String debugLogFileLocation(String path) => isGerman
      ? 'Logdatei: $path — im privaten App-Ordner, nicht in der Dateien-App sichtbar. Zum Teilen bitte hier kopieren.'
      : 'Log file: $path — stored in the private app folder, not visible in the Files app. Copy it here if you need to share it.';

  // --- Homescreen Quick Action (iOS) ---
  String get quickActionSyncNow => isGerman ? 'Jetzt synchronisieren' : 'Sync Now';

  // --- Diagnose-Protokoll / Debug-Log ---
  String get debugLogTitle => isGerman ? 'Sync-Protokoll & Diagnose' : 'Sync Log & Diagnostics';
  String get debugLogSubtitle => isGerman
      ? 'Alle Aktionen, Netzwerk- und Sync-Ereignisse mit Zeitstempel'
      : 'All actions, network and sync events with timestamps';
  String get debugLogEmpty => isGerman
      ? 'Noch keine Protokoll-Einträge vorhanden.'
      : 'No log entries yet.';
  String get clearLog => isGerman ? 'Protokoll leeren' : 'Clear Log';
  String get systemLogSection =>
      isGerman ? 'System-Protokoll (alle Aktionen)' : 'System log (all actions)';
  String get taskLogSection =>
      isGerman ? 'Aktueller Sync-Verlauf (aktive Queue)' : 'Current sync run (active queue)';

  // --- About / Über Section & System Language ---
  String get systemLanguage => isGerman ? 'System (Automatisch)' : 'System (Automatic)';
  String get aboutSectionTitle => isGerman ? 'Über Fibu' : 'About Fibu';
  /// Zeile im „Über Fibu“-Abschnitt (nicht erneut „Über Fibu“ nennen).
  String get aboutAppTitle => isGerman ? 'App-Informationen' : 'App Information';
  String get aboutAppSubtitle => isGerman
      ? 'Multi-Cloud-Backup & Mediathek-Spiegelung'
      : 'Multi-Cloud Backup & Media Library Mirror';
  String get appVersionLabel => isGerman ? 'Version' : 'Version';
  String get appVersionValue => '1.0.0 (Build 1)';
  String get developerLabel => isGerman ? 'Entwickler' : 'Developer';
  String get developerValue => 'Fibu Open Source Team';
  String get cloudEngineLabel => isGerman ? 'Cloud-Engine' : 'Cloud Engine';
  String get cloudEngineValue => isGerman ? 'rclone (70+ Anbieter)' : 'rclone (70+ providers)';
  String get licenseLabel => isGerman ? 'Lizenz' : 'License';
  String get licenseValue => 'MIT License';
  String get aboutDescription => isGerman
      ? 'Fibu ist eine dezentrale, plattformadaptive Multi-Cloud-Backup-App für iOS, Android und Windows. Deine Daten bleiben stets unter deiner Kontrolle — ohne Zwischenserver.'
      : 'Fibu is a decentralized, platform-adaptive multi-cloud backup app for iOS, Android, and Windows. Your data remains entirely under your control — no intermediary servers.';

  // --- Task Details & Actions ---
  String get taskDetailsTitle => isGerman ? 'Aufgaben-Details' : 'Task Details';
  String get statusActive => isGerman ? 'Aktiv' : 'Active';
  String get statusInactive => isGerman ? 'Inaktiv' : 'Inactive';
  String get syncTaskNow => isGerman ? 'Jetzt synchronisieren' : 'Sync Now';
  String get syncTriggeredSuccess => isGerman ? 'Synchronisierung wurde gestartet' : 'Sync started successfully';
  String get swipeToDelete => isGerman ? 'Wischen zum Löschen' : 'Swipe to delete';
  String get generalSection => isGerman ? 'Allgemein' : 'General';
  String get sourceAndTargetSection => isGerman ? 'Quelle & Ziel' : 'Source & Destination';
  String get syncSettingsSection => isGerman ? 'Synchronisation' : 'Synchronization';
  String get scheduleAndNetworkSection => isGerman ? 'Zeitplan & Netzwerk' : 'Schedule & Network';
  String get targetFolderLabel => isGerman ? 'Zielordner' : 'Destination Folder';
  String get distributionLabel => isGerman ? 'Verteilung' : 'Distribution';
  String get excludedFilesLabel => isGerman ? 'Dateifilter' : 'File Filters';
  String get noExcludedFiles => isGerman ? 'Keine (Alle Dateien)' : 'None (All files)';
  // --- In-Place-Bearbeitung & Remote-Ordner-Löschung (Task-Detail) ---
  String get editTaskInline => isGerman ? 'Bearbeiten' : 'Edit';
  String get doneEditing => isGerman ? 'Fertig' : 'Done';
  String get syncSection => isGerman ? 'Synchronisieren' : 'Synchronize';
  String get deleteRemoteFolderLabel => isGerman ? 'Zielordner in der Cloud löschen' : 'Delete Target Folder in Cloud';
  String deleteRemoteFolderPrompt(String path) => isGerman
      ? 'Löscht den kompletten Ordner „$path“ samt Inhalt unwiderruflich aus der Cloud. Gib zur Bestätigung exakt den Ordnerpfad ein:'
      : 'This permanently deletes the entire cloud folder “$path” including all contents. Type the exact folder path to confirm:';
  String get deleteRemoteFolderTypeHint => isGerman ? 'Ordnerpfad eingeben' : 'Enter folder path';
  String get confirmationMismatch => isGerman ? 'Der eingegebene Name stimmt nicht überein.' : 'The typed name does not match.';
  /// Rückmeldung NACH dem Löschen einer Aufgabe (Regel 6: Konsequenz klar
  /// benennen — auch im Erfolgsfall, sonst bleibt unklar, ob etwas geschah).
  String taskDeletedNotice(String name) => isGerman
      ? 'Aufgabe „$name“ wurde gelöscht. Die bereits hochgeladenen Dateien in der Cloud bleiben erhalten.'
      : 'Task “$name” deleted. Files already uploaded to the cloud are kept.';

  /// Rückmeldung NACH dem Löschen eines Cloud-Ordners, mit Klartext was weg ist.
  String remoteFolderDeletedDetail(String folder) => isGerman
      ? 'Cloud-Ordner „$folder“ wurde gelöscht.'
      : 'Cloud folder “$folder” deleted.';

  /// Klartext, welche Pfade gelöscht werden (Scoping auf Album-Ordner).
  String purgeScopeInfo(List<String> paths) => isGerman
      ? 'Gelöscht werden: ${paths.join(', ')}'
      : 'Will delete: ${paths.join(', ')}';

  /// Warnung, wenn weitere Aufgaben denselben Cloud-Ordner benutzen — deren
  /// Dateien liegen im selben Baum und werden mitgelöscht.
  String purgeSharedFolderWarning(String folder, List<String> others) => isGerman
      ? 'Achtung: ${others.length} andere Aufgabe(n) nutzen ebenfalls „$folder“ '
          '(${others.join(', ')}). Deren Dateien liegen im selben Ordner und werden MITGELÖSCHT.'
      : 'Warning: ${others.length} other task(s) also use “$folder” '
          '(${others.join(', ')}). Their files live in the same folder and WILL be deleted too.';

  String get remoteFolderDeleted => isGerman ? 'Cloud-Ordner wurde gelöscht.' : 'Cloud folder deleted.';
  String get remoteFolderDeleteError => isGerman ? 'Cloud-Ordner konnte nicht gelöscht werden.' : 'Could not delete the cloud folder.';
  String get dangerZone => isGerman ? 'Aktionen' : 'Actions';

  // --- Sync-Warteschlange & Job-Status (Dashboard) ---
  String get storageDetailsTitle => isGerman ? 'Speicherdetails' : 'Storage Details';
  String get syncActivityLogsTitle => isGerman ? 'Sync-Aktivitätsprotokoll' : 'Sync Activity Logs';
  String get queuePreparingJobs => isGerman
      ? 'Aktive Backup-Aufgaben werden vorbereitet …'
      : 'Preparing active backup jobs…';
  String preparingTask(String name) =>
      isGerman ? '„$name“ wird vorbereitet …' : 'Preparing “$name”…';
  String startingTask(String name) =>
      isGerman ? 'Start: $name …' : 'Starting: $name…';
  String get noActiveTasksError => isGerman
      ? 'Keine aktiven Backup-Aufgaben gefunden. Aktiviere Aufgaben im Reiter „Aufgaben“.'
      : 'No active backup tasks found. Enable tasks in the Tasks tab.';
  String get taskNotFoundError =>
      isGerman ? 'Aufgabe nicht gefunden.' : 'Task not found.';
  String get backupStopped => isGerman ? 'Backup gestoppt.' : 'Backup stopped.';
  String get syncCancelledByUser =>
      isGerman ? 'Sync vom Nutzer abgebrochen.' : 'Sync cancelled by user.';
  String get allTasksCompleted => isGerman
      ? 'Alle aktiven Backup-Aufgaben erfolgreich abgeschlossen.'
      : 'All active backup tasks completed successfully.';
  String get taskSyncedSuccess => isGerman
      ? 'Aufgabe erfolgreich synchronisiert.'
      : 'Task synchronized successfully.';

  // --- Sync-Fortschritt: EINFACHE Verben, keine Technik-Sätze ---
  /// Ein Sync läuft bereits — parallele Läufe sind bewusst gesperrt, weil
  /// sich Mirror-Zustand und Transfers sonst gegenseitig korrumpieren.
  /// Bearbeitung gesperrt, solange ein Sync läuft.
  String get editBlockedDuringSyncTitle =>
      isGerman ? 'Synchronisierung läuft' : 'Synchronization running';
  String get editBlockedDuringSyncMessage => isGerman
      ? 'Bitte warte, bis die laufende Synchronisierung beendet ist. Die Aufgabe kann währenddessen nicht geändert werden.'
      : 'Please wait until the running synchronization finishes. The task cannot be changed meanwhile.';

  String get syncAlreadyRunning => isGerman
      ? 'Es läuft bereits eine Synchronisierung.'
      : 'A synchronization is already running.';

  String get syncOfflineNoNetwork => isGerman
      ? 'Offline — keine Internetverbindung'
      : 'Offline — no internet connection';
  String syncStagePreparing(String label) =>
      isGerman ? 'Vorbereiten …' : 'Preparing…';
  String get syncMirrorRunning => isGerman ? 'Überprüfen …' : 'Checking…';
  String get syncDeletionScan => isGerman ? 'Überprüfen' : 'Checking';
  String get syncPhaseScan => isGerman ? 'Überprüfen' : 'Checking';
  String get syncPhaseUpload => isGerman ? 'Hochladen' : 'Uploading';
  String get syncPhaseTombstones => isGerman ? 'Aufräumen' : 'Cleaning up';
  String get syncPhaseDownload => isGerman ? 'Herunterladen' : 'Downloading';
  String get syncPhaseDeleteLocal => isGerman ? 'Löschen' : 'Deleting';

  // --- Statusleiste: genau drei Zustände (Vorgabe) ---
  //
  // Die Statusleiste kennt bewusst nur diese drei Texte. Alles vor dem ersten
  // Transfer (Scan, Staging, Lösch-Erkennung) ist „Auf Änderungen überprüfen",
  // alles nach dem letzten Transfer (Tombstones, lokale Löschungen, Zustand
  // schreiben) ist „Abschließen".
  /// Importierte Aufgabe ohne Quelle (Quelle eines anderen Geräts, z. B. eine
  /// iOS-Mediathek, die es hier nicht gibt).
  // --- Autostart (Windows) ---
  String get autostartLabel =>
      isGerman ? 'Mit Windows starten' : 'Start with Windows';
  String get autostartDescription => isGerman
      ? 'Fibu startet im Hintergrund, sobald du dich anmeldest, und führt den Zeitplan auch aus, wenn du die App nicht geöffnet hast. Verpasste Läufe werden beim nächsten Start nachgeholt.'
      : 'Fibu starts in the background when you sign in and runs the schedule even if you never open the app. Missed runs are caught up on the next start.';

  String get syncSourceMissing => isGerman
      ? 'Keine Quelle gewählt — bitte in der Aufgabe einen Ordner auswählen'
      : 'No source selected — please choose a folder in the task';

  String get syncStatusChecking =>
      isGerman ? 'Auf Änderungen überprüfen' : 'Checking for changes';
  String get syncStatusFinishing => isGerman ? 'Abschließen' : 'Finishing up';

  /// „„IMG_0001.HEIC" auf „MEGA" übertragen" bzw. „… von „MEGA" übertragen".
  String syncStatusTransfer(String file, String cloud, bool upload) => isGerman
      ? '„$file“ ${upload ? 'auf' : 'von'} „$cloud“ übertragen'
      : 'Transferring “$file” ${upload ? 'to' : 'from'} “$cloud”';

  /// Restdauer ohne das Wort „ETA": „12 Minuten verbleibend".
  /// Aufgerundet, damit die Anzeige nie „0 Minuten" zeigt, während noch
  /// etwas läuft. Unter einer Minute wird in Sekunden gerechnet.
  String etaRemaining(int seconds) {
    if (seconds < 60) {
      return isGerman
          ? '$seconds ${seconds == 1 ? 'Sekunde' : 'Sekunden'} verbleibend'
          : '$seconds ${seconds == 1 ? 'second' : 'seconds'} remaining';
    }
    if (seconds < 3600) {
      final m = (seconds / 60).ceil();
      return isGerman
          ? '$m ${m == 1 ? 'Minute' : 'Minuten'} verbleibend'
          : '$m ${m == 1 ? 'minute' : 'minutes'} remaining';
    }
    final h = (seconds / 3600).ceil();
    return isGerman
        ? '$h ${h == 1 ? 'Stunde' : 'Stunden'} verbleibend'
        : '$h ${h == 1 ? 'hour' : 'hours'} remaining';
  }

  /// Solange noch keine brauchbare Geschwindigkeit gemessen wurde.
  String get etaCalculating => isGerman
      ? 'Restdauer wird berechnet …'
      : 'Calculating remaining time …';
  String get syncAllUpToDate =>
      isGerman ? 'Alles aktuell.' : 'Everything up to date.';
  String syncDoneCounts(int uploaded, int downloaded) => isGerman
      ? 'Fertig — $uploaded hochgeladen · $downloaded heruntergeladen'
      : 'Done — $uploaded uploaded · $downloaded downloaded';
  String get syncCompletedLabel => isGerman ? 'Fertig' : 'Done';
  String get syncMirrorReady => isGerman ? 'Vorbereitet' : 'Prepared';
  String syncReadAlbum(String album) =>
      isGerman ? 'Überprüfen …' : 'Checking…';
  String get syncStartAnalysis => isGerman ? 'Überprüfen …' : 'Checking…';
  String get errNoJobId => isGerman
      ? 'rclone lieferte keine Job-ID zurück'
      : 'rclone did not return a job id';
  String get errUnknown => isGerman ? 'Unbekannter Fehler' : 'Unknown error';
  String get errPhotoPermission => isGerman
      ? 'Kein Zugriff auf Fotos & Mediathek (Berechtigung verweigert)'
      : 'No access to Photos library (permission denied)';

  // --- Zeitplan-Beschreibung (lokalisiert, ersetzt Modell-Hardcodes) ---
  String scheduleDescriptionFor(String scheduleDay, String scheduleTime) {
    if (scheduleDay == 'iOS System' || scheduleDay == 'System') {
      return isGerman ? 'Automatisch (iOS-System)' : 'Automatic (iOS system)';
    }
    if (scheduleDay == 'Daily') {
      // Keine Uhrzeit: iOS entscheidet selbst, wann der Hintergrundtask
      // läuft. Eine feste Zeit zu versprechen wäre falsch.
      return isGerman
          ? 'Täglich (Hintergrundtask, von iOS gesteuert)'
          : 'Daily (background task, scheduled by iOS)';
    }
    if (scheduleDay == 'Manual') {
      return isGerman ? 'Manuell' : 'Manual';
    }
    final day = _weekdayLabel(scheduleDay);
    return isGerman
        ? 'Wöchentlich am $day (Hintergrundtask, von iOS gesteuert)'
        : 'Weekly on ${day}s (background task, scheduled by iOS)';
  }

  String _weekdayLabel(String key) {
    switch (key) {
      case 'Monday':
        return dayMonday;
      case 'Tuesday':
        return dayTuesday;
      case 'Wednesday':
        return dayWednesday;
      case 'Thursday':
        return dayThursday;
      case 'Friday':
        return dayFriday;
      case 'Saturday':
        return daySaturday;
      case 'Sunday':
        return daySunday;
      default:
        return key;
    }
  }

  // --- Datei-Vorschau ---
  String get previewLoadFailed => isGerman
      ? 'Vorschau konnte nicht geladen werden.'
      : 'Preview could not be loaded.';
  String get fileLoadFailed => isGerman
      ? 'Datei konnte nicht geladen werden.'
      : 'File could not be loaded.';
  String get imageDisplayFailed => isGerman
      ? 'Bild konnte nicht angezeigt werden.'
      : 'Image could not be displayed.';

  // --- Anmeldefelder (Fallback ohne Provider-Metadaten) ---
  String get passwordFieldLabel => isGerman ? 'Passwort' : 'Password';

  // --- Sprachauswahl (Einstellungen) ---
  String get languageModeSystem => isGerman ? 'System (automatisch)' : 'System (automatic)';

  /// Übersetzt die (deutsch gepflegten) Feldlabels der Provider-Registry
  /// für die englische Oberfläche. Unbekannte oder bereits englische Labels
  /// werden unverändert durchgereicht.
  String providerFieldLabel(String label) {
    if (isGerman) return label;
    const map = <String, String>{
      '2FA Code (falls aktiv)': '2FA code (if enabled)',
      'API-Key / Passwort': 'API key / password',
      'API-Schlüssel': 'API key',
      'Account Key oder SAS-Token': 'Account key or SAS token',
      'App-Passwort': 'App password',
      'Basis-Remote & Pfad': 'Base remote & path',
      'Benutzer-Token': 'User token',
      'Benutzerdefinierter Endpoint (optional)': 'Custom endpoint (optional)',
      'Benutzername / E-Mail': 'Username / email',
      'Benutzername': 'Username',
      'Chunk-Größe': 'Chunk size',
      'Dateinamen-Passwort (Salt / optional)': 'Filename password (salt, optional)',
      'Dateinamen-Verschlüsselung': 'Filename encryption',
      'E-Mail / Telefonnummer': 'Email / phone number',
      'E-Mail': 'Email',
      'E-Mail-Adresse': 'Email address',
      'Explizites FTPS (TLS) verwenden': 'Use explicit FTPS (TLS)',
      'FTP Hostname / IP': 'FTP hostname / IP',
      'GCP Projektnummer (optional)': 'GCP project number (optional)',
      'HTTP Ordner URL': 'HTTP folder URL',
      'Hadoop Benutzer': 'Hadoop user',
      'Hauptpasswort für Verschlüsselung': 'Master password for encryption',
      'Laufwerk-Typ': 'Drive type',
      'Passwort / API-Token': 'Password / API token',
      'Passwort / App-Token': 'Password / app token',
      'Passwort': 'Password',
      'Pfad zum privaten SSH-Key (optional)': 'Path to private SSH key (optional)',
      'SSH Benutzername': 'SSH username',
      'SSH Passwort (optional falls Key genutzt)': 'SSH password (optional if key is used)',
      'Satellite Adresse (optional)': 'Satellite address (optional)',
      'Schreib-Strategie': 'Write strategy',
      'Server Host / IP': 'Server host / IP',
      'Server-Typ': 'Server type',
      'Server-URL': 'Server URL',
      'Service Account JSON Pfad (optional)': 'Service account JSON path (optional)',
      'Tenant Name (optional)': 'Tenant name (optional)',
      'Upstreams (z.B. ordner1=drive:a ordner2=b2:b)':
          'Upstreams (e.g. folder1=drive:a folder2=b2:b)',
      'Verknüpfte Remotes (getrennt durch Leerzeichen)':
          'Linked remotes (space-separated)',
      'Verschlüsselungs-Passphrase': 'Encryption passphrase',
      'Wasabi Access Key': 'Wasabi access key',
      'Wasabi Secret Key': 'Wasabi secret key',
      'Windows Domain (optional)': 'Windows domain (optional)',
      'Ziel-Remote & Pfad': 'Target remote & path',
    };
    return map[label] ?? label;
  }

  /// Einstellungs-Erklärung für Anbieter, deren Einrichtung über die einfache
  /// Eingabe von E-Mail/Benutzername + Passwort hinausgeht. Beschreibt in
  /// klaren Worten, WAS man braucht, WAS passiert und WIE es funktioniert.
  /// null, wenn der Anbieter selbsterklärend ist (z. B. MEGA).
  String? providerSetupGuide(String providerId) {
    final id = providerId.trim().toLowerCase();
    if (isGerman) {
      const de = <String, String>{
        'drive':
            'Die Anmeldung erfolgt direkt bei Google im Browser — Fibu erhält dabei nur die Berechtigung, Dateien in deinem Drive zu lesen und zu schreiben. Dein Passwort wird nicht in der App gespeichert. Fortgeschrittene Nutzer können optional eine eigene Client-ID aus der Google Cloud Console hinterlegen, um höhere Übertragungsraten zu erreichen.',
        'google photos':
            'Die Anmeldung erfolgt direkt bei Google im Browser. Fibu erhält Zugriff auf deine Foto-Mediathek, um sie zu sichern. Dein Passwort wird nicht in der App gespeichert.',
        'onedrive':
            'Die Anmeldung erfolgt direkt bei Microsoft im Browser. In den erweiterten Optionen kannst du zwischen privatem OneDrive, OneDrive for Business und SharePoint wählen.',
        'dropbox':
            'Die Anmeldung erfolgt direkt bei Dropbox im Browser — Fibu erhält nur Zugriff auf seinen eigenen App-Ordner bzw. die erteilte Berechtigung. Dein Passwort wird nicht in der App gespeichert.',
        'crypt':
            'Der Tresor verschlüsselt jede Datei bereits auf deinem Gerät, bevor sie in ein bereits verbundenes Cloud-Laufwerk hochgeladen wird. Wähle unten ein vorhandenes Laufwerk und vergib ein eigenes Hauptpasswort. Die Cloud sieht ausschließlich verschlüsselte Inhalte. Wichtig: Ohne das Hauptpasswort sind die Daten unwiederbringlich verloren — bewahre es sicher auf.',
        'chunker':
            'Chunker teilt große Dateien beim Hochladen automatisch in handliche Blöcke auf und setzt sie beim Herunterladen wieder zusammen — sinnvoll für Clouds mit Beschränkungen der Dateigröße. Wähle unten ein verbundenes Basis-Laufwerk. Die Chunk-Größe bestimmt die maximale Größe der Einzelteile (Standard: 2 GB).',
        'union':
            'Union fasst mehrere Cloud-Laufwerke zu einem einzigen großen virtuellen Laufwerk zusammen. Wähle unten mindestens zwei bereits verbundene Laufwerke aus. Neue Dateien werden je nach Schreib-Strategie verteilt: „epall“ schreibt auf alle Laufwerke, „lfs“ auf das Laufwerk mit dem meisten freien Speicher, „rand“ zufällig. Gelesen wird übergreifend aus allen Laufwerken.',
        'combine':
            'Combine bündelt Ordner verschiedener Cloud-Laufwerke in einem einzigen virtuellen Laufwerk, in dem jede Quelle als eigener Unterordner erscheint. Wähle unten die gewünschten, bereits verbundenen Laufwerke aus.',
        'alias':
            'Ein Alias ist eine einfache Verknüpfung auf ein vorhandenes Laufwerk — praktisch, um es unter einem eigenen Namen anzusprechen. Wähle unten das Ziel-Laufwerk aus.',
        'compress':
            'Dieses Laufwerk komprimiert Dateien vor dem Hochladen transparent mit gzip und entpackt sie beim Zugriff automatisch. Wähle unten ein verbundenes Basis-Laufwerk. Gut geeignet für Dokumente; bei bereits komprimierten Medien wie Fotos oder Videos ist der Gewinn gering.',
        's3':
            'Du benötigst ein Zugriffsschlüssel-Paar aus AWS IAM (Access Key ID und Secret Access Key) sowie die Region deines Buckets. Fibu erstellt keine Buckets — der Bucket muss bereits existieren. Neue Schlüssel legst du in der AWS-Konsole unter „IAM → Zugriffsdaten“ an.',
        's3-wasabi':
            'Du benötigst einen Wasabi Access Key und Secret Key (in der Wasabi-Konsole unter „Access Keys“) sowie den zu deiner Region passenden Endpoint. Der europäische Standard-Endpoint ist bereits vorbelegt.',
        's3-b2':
            'Backblaze B2 wird hier über die S3-Schnittstelle angesprochen. Du benötigst eine Application Key ID und einen Application Key aus der B2-Konsole („App Keys“) sowie den zur Bucket-Region passenden S3-Endpoint, z. B. s3.eu-central-003.backblazeb2.com.',
        's3-r2':
            'Cloudflare R2 verzichtet auf Egress-Gebühren. Du benötigst ein R2-API-Token-Paar (im Cloudflare-Dashboard unter „R2 → Manage R2 API Tokens“) und deine Account-ID für den Endpoint im Format https://<ACCOUNT_ID>.r2.cloudflarestorage.com.',
        's3-minio':
            'MinIO läuft üblicherweise in deinem eigenen Netzwerk. Du benötigst die Server-URL deines MinIO sowie die dort eingerichteten Zugangsdaten (Access Key und Secret Key).',
        's3-digitalocean':
            'Du benötigst einen Spaces Access Key und Secret Key aus dem DigitalOcean-Control-Panel sowie den Endpoint deiner Spaces-Region (z. B. fra1.digitaloceanspaces.com).',
        's3-idrive':
            'Du benötigst Access Key ID und Secret Access Key sowie die Endpoint-URL aus der IDrive-e2-Konsole.',
        's3-synology':
            'Du benötigst Access Key ID und Secret Key aus dem Synology C2 Storage Portal sowie den dort angezeigten S3-Endpoint.',
        's3-ceph':
            'Du benötigst den S3-Endpoint deines Ceph-Clusters sowie die dafür ausgestellten Zugangsdaten (Access Key und Secret Key).',
        's3-generic':
            'Für jeden beliebigen S3-kompatiblen Speicher: Trage die Endpoint-URL des Dienstes sowie deine Access Key ID und den Secret Access Key ein. Die Region ist optional.',
        'b2':
            'Die native B2-API benötigt deine Account-ID (Backblaze-Konsole → „Account“) und einen Application Key („App Keys“). Alternativ kannst du Backblaze B2 auch über die S3-Schnittstelle verbinden.',
        'gcs':
            'Die Anmeldung erfolgt über dein Google-Konto im Browser. Projektnummer und Service-Account sind optional und nur für spezielle Enterprise-Konstellationen nötig.',
        'azureblob':
            'Du benötigst den Namen deines Azure Storage Accounts sowie einen Account Key oder ein SAS-Token (im Azure-Portal unter „Storage Account → Access keys“). Fibu greift damit auf deine Blob-Container zu.',
        'azurefiles':
            'Du benötigst den Namen deines Azure Storage Accounts und den zugehörigen Account Key (im Azure-Portal unter „Storage Account → Access keys“).',
        'storj':
            'Storj ist dezentraler Objektspeicher. Du benötigst einen API-Key und die Verschlüsselungs-Passphrase aus deinem Storj-Projekt (Dashboard → „Access → Create Access“). Die Satellite-Adresse kann auf dem Standardwert bleiben.',
        'swift':
            'OpenStack Swift benötigt die Auth-URL deines Identity-Endpunkts (Keystone) sowie Benutzername und API-Key bzw. Passwort. Der Tenant (Projektname) ist optional.',
        'qingstor':
            'Du benötigst Access Key ID, Secret Access Key und die Zone deines QingStor-Buckets aus der QingCloud-Konsole.',
        'internetarchive':
            'Du benötigst deine S3-Zugangsdaten von archive.org („Account Settings → S3-like API keys“). Damit lädst du Dateien in deine Archive.org-Items hoch.',
        'webdav':
            'Gib die vollständige WebDAV-Adresse deines Servers an und wähle den passenden Server-Typ. Bei Nextcloud und ownCloud empfiehlt sich ein App-Token statt des normalen Passworts — Du erzeugst es in den Server-Einstellungen unter „Sicherheit“.',
        'sftp':
            'Du benötigst Host, Port und Benutzernamen deines SSH-Servers. Die Anmeldung funktioniert entweder per Passwort oder — sicherer — per SSH-Schlüssel; den Pfad zum privaten Schlüssel findest du in den erweiterten Optionen.',
        'ftp':
            'Klassischer Datei-Transfer. Explizites FTPS (TLS) ist aus Sicherheitsgründen aktiviert und sollte nur für ältere Server ohne TLS-Unterstützung deaktiviert werden.',
        'smb':
            'Für Windows-Netzwerkfreigaben und Samba: Du benötigst Host, Benutzernamen und Passwort der Freigabe. In Active-Directory-Umgebungen kann zusätzlich die Domäne angegeben werden.',
        'http':
            'Bindet einen öffentlichen Web-Ordner schreibgeschützt ein. Unterstützt werden HTTP(S)-Verzeichnislisten; Uploads sind bei diesem Protokoll nicht möglich.',
        'hdfs':
            'Du benötigst die Adresse des NameNode-Knotens (host:port) sowie den Hadoop-Benutzernamen, unter dem Fibu auf das Dateisystem zugreift.',
        'protondrive':
            'Melde dich mit deinen Proton-Zugangsdaten an. Falls du die Zwei-Faktor-Authentifizierung aktiviert hast, trage zusätzlich den aktuellen 2FA-Code ein.',
        'mailru':
            'Verwende ein Mail.ru-App-Passwort statt des normalen Kontopassworts — du erzeugst es im Mail.ru-Konto unter „Sicherheit → App-Passwörter“.',
        'koofr':
            'Verwende ein Koofr-App-Passwort statt deines normalen Passworts — zu finden im Koofr-Konto unter „Preferences → Password → App password“.',
        'sugarsync':
            'SugarSync nutzt Entwickler-Zugangsdaten statt Benutzername und Passwort: Fordere einmalig eine App-ID und Access Key ID bei SugarSync an („Developer“-Bereich) und trage beide hier ein. Der Refresh-Token wird danach automatisch verwaltet.',
        '1fichier':
            'Du benötigst deinen persönlichen API-Schlüssel — zu finden im 1Fichier-Konto unter „Account → API Key“.',
        'uptobox':
            'Du benötigst dein persönliches Benutzer-Token aus den Uptobox-Kontoeinstellungen.',
        'quatrix':
            'Du benötigst einen API-Schlüssel sowie den Hostnamen deiner Quatrix-Instanz (z. B. firma.quatrix.it).',
        'seafile':
            'Du benötigst die URL deines Seafile-Servers sowie deine Zugangsdaten. Statt des Passworts kann auch ein in Seafile erzeugtes API-Token verwendet werden.',
      };
      return de[id];
    }
    const en = <String, String>{
      'drive':
          'You sign in directly with Google in your browser — Fibu only receives permission to read and write files in your Drive. Your password is never stored in the app. Advanced users can optionally provide their own client ID from the Google Cloud Console for higher transfer quotas.',
      'google photos':
          'You sign in directly with Google in your browser. Fibu gains access to your photo library in order to back it up. Your password is never stored in the app.',
      'onedrive':
          'You sign in directly with Microsoft in your browser. Advanced options let you choose between personal OneDrive, OneDrive for Business and SharePoint.',
      'dropbox':
          'You sign in directly with Dropbox in your browser — Fibu only receives the granted permission. Your password is never stored in the app.',
      'crypt':
          'The vault encrypts every file on your device before it is uploaded to an already connected cloud drive. Pick an existing drive below and set your own master password. The cloud only ever sees encrypted content. Important: without the master password the data cannot be recovered — keep it somewhere safe.',
      'chunker':
          'Chunker automatically splits large files into manageable pieces on upload and reassembles them on download — useful for clouds with file size limits. Pick a connected base drive below. The chunk size defines the maximum size of each part (default: 2 GB).',
      'union':
          'Union pools multiple cloud drives into one single large virtual drive. Select at least two already connected drives below. New files are distributed according to the write policy: “epall” writes to all drives, “lfs” to the drive with the most free space, “rand” randomly. Reads work across all drives.',
      'combine':
          'Combine merges folders from different cloud drives into one virtual drive where each source appears as its own subfolder. Select the connected drives you want below.',
      'alias':
          'An alias is a simple shortcut to an existing drive — handy for addressing it under its own name. Pick the target drive below.',
      'compress':
          'This drive transparently compresses files with gzip before uploading and unpacks them on access. Pick a connected base drive below. Works well for documents; photos and videos gain little.',
      's3':
          'You need an access key pair from AWS IAM (Access Key ID and Secret Access Key) and the region of your bucket. Fibu does not create buckets — the bucket must already exist. Create new keys in the AWS console under “IAM → Access keys”.',
      's3-wasabi':
          'You need a Wasabi access key and secret key (in the Wasabi console under “Access Keys”) plus the endpoint matching your region. The European default endpoint is pre-filled.',
      's3-b2':
          'Backblaze B2 is addressed via its S3 interface here. You need an Application Key ID and Application Key from the B2 console (“App Keys”) plus the S3 endpoint matching your bucket region, e.g. s3.eu-central-003.backblazeb2.com.',
      's3-r2':
          'Cloudflare R2 has zero egress fees. You need an R2 API token pair (Cloudflare dashboard → “R2 → Manage R2 API Tokens”) and your account ID for the endpoint of the form https://<ACCOUNT_ID>.r2.cloudflarestorage.com.',
      's3-minio':
          'MinIO usually runs on your own network. You need the server URL of your MinIO instance and its access credentials (access key and secret key).',
      's3-digitalocean':
          'You need a Spaces access key and secret key from the DigitalOcean control panel plus the endpoint of your Spaces region (e.g. fra1.digitaloceanspaces.com).',
      's3-idrive':
          'You need the Access Key ID, Secret Access Key and endpoint URL from the IDrive e2 console.',
      's3-synology':
          'You need the Access Key ID and secret key from the Synology C2 Storage portal plus the S3 endpoint shown there.',
      's3-ceph':
          'You need the S3 endpoint of your Ceph cluster plus the credentials issued for it (access key and secret key).',
      's3-generic':
          'For any S3-compatible storage: enter the service’s endpoint URL plus your Access Key ID and Secret Access Key. The region is optional.',
      'b2':
          'The native B2 API needs your account ID (Backblaze console → “Account”) and an application key (“App Keys”). Alternatively connect Backblaze B2 via its S3 interface.',
      'gcs':
          'You sign in with your Google account in the browser. Project number and service account are optional and only needed for special enterprise setups.',
      'azureblob':
          'You need the name of your Azure storage account and an account key or SAS token (Azure portal → “Storage Account → Access keys”). Fibu uses them to access your blob containers.',
      'azurefiles':
          'You need the name of your Azure storage account and its account key (Azure portal → “Storage Account → Access keys”).',
      'storj':
          'Storj is decentralized object storage. You need an API key and the encryption passphrase from your Storj project (dashboard → “Access → Create Access”). The satellite address can stay on its default.',
      'swift':
          'OpenStack Swift needs the auth URL of your identity endpoint (Keystone) plus username and API key or password. The tenant (project name) is optional.',
      'qingstor':
          'You need the Access Key ID, Secret Access Key and the zone of your QingStor bucket from the QingCloud console.',
      'internetarchive':
          'You need your S3 credentials from archive.org (“Account Settings → S3-like API keys”). They are used to upload files into your Archive.org items.',
      'webdav':
          'Enter the full WebDAV URL of your server and choose the matching server type. For Nextcloud and ownCloud an app token is recommended instead of the regular password — create it in the server settings under “Security”.',
      'sftp':
          'You need the host, port and username of your SSH server. Sign-in works either with a password or — more securely — with an SSH key; the path to the private key is available in the advanced options.',
      'ftp':
          'Classic file transfer. Explicit FTPS (TLS) is enabled for security and should only be disabled for older servers without TLS support.',
      'smb':
          'For Windows network shares and Samba: you need the host, username and password of the share. In Active Directory environments the domain can be provided as well.',
      'http':
          'Connects a public web folder read-only. HTTP(S) directory listings are supported; uploads are not possible with this protocol.',
      'hdfs':
          'You need the address of the NameNode (host:port) and the Hadoop username Fibu should use to access the file system.',
      'protondrive':
          'Sign in with your Proton credentials. If you have two-factor authentication enabled, also enter the current 2FA code.',
      'mailru':
          'Use a Mail.ru app password instead of your regular account password — create it in your Mail.ru account under “Security → App passwords”.',
      'koofr':
          'Use a Koofr app password instead of your regular password — find it in your Koofr account under “Preferences → Password → App password”.',
      'sugarsync':
          'SugarSync uses developer credentials instead of username and password: request an App ID and Access Key ID once from SugarSync (its “Developer” section) and enter both here. The refresh token is then managed automatically.',
      '1fichier':
          'You need your personal API key — find it in your 1Fichier account under “Account → API Key”.',
      'uptobox':
          'You need your personal user token from the Uptobox account settings.',
      'quatrix':
          'You need an API key and the hostname of your Quatrix instance (e.g. company.quatrix.it).',
      'seafile':
          'You need the URL of your Seafile server and your credentials. An API token generated in Seafile can be used instead of the password.',
    };
    return en[id];
  }

  // --- Speicherdetails-Dialog ---
  String get storageDetailedUtilization => isGerman
      ? 'Detaillierte Speicherbelegung:'
      : 'Detailed storage space utilization:';
  String get legendPhotos => isGerman ? 'Fotos & Bilder' : 'Photos & Images';
  String get legendVideos => isGerman ? 'Videos' : 'Videos';
  String get legendOtherDocs => isGerman ? 'Andere Dokumente' : 'Other Documents';
  String get legendFreeSpace => isGerman ? 'Freier Speicher' : 'Free Space';
  String get legendTotalCapacity => isGerman ? 'Gesamtkapazität' : 'Total Capacity';

  // --- Sync-Bedarfs-Prüfung (Aktualisieren-Button & Status-Banner) ---
  String get syncNeededBanner => isGerman
      ? 'Änderungen gefunden — Sync fällig'
      : 'Changes found — sync needed';
  String get syncNeededMessage => isGerman
      ? 'Es gibt neue oder geänderte Inhalte. Tippe auf „Alle synchronisieren“.'
      : 'There is new or changed content. Tap “Sync All Files”.';
  String get checkedUpToDate => isGerman
      ? 'Geprüft: Alles aktuell — kein Sync nötig.'
      : 'Checked: everything up to date — no sync needed.';
  String get syncButtonWaitTasks => isGerman
      ? 'Aufgaben werden geladen …'
      : 'Loading tasks…';

  // --- Rechtliches ---
  String get legalSectionTitle => isGerman ? 'Rechtliches' : 'Legal';
  String get privacyNoticeTitle =>
      isGerman ? 'Datenschutzerklärung' : 'Privacy Policy';
  String get privacyNoticeSubtitle => isGerman
      ? 'Welche Daten die App nutzt – und welche sie bewusst nicht nutzt'
      : 'Which data the app uses – and which it deliberately does not';
  String get imprintTitle => isGerman ? 'Impressum & Anbieter' : 'Imprint & Provider';
  String get imprintSubtitle => isGerman
      ? 'Anbieter, Haftung, Marken und Open Source'
      : 'Provider, liability, trademarks and open source';
  String get openSourceLicenses =>
      isGerman ? 'Open-Source-Lizenzen' : 'Open-Source Licenses';
  String get openSourceLicensesSubtitle => isGerman
      ? 'Verwendete Bibliotheken und ihre Lizenzen'
      : 'Bundled libraries and their licenses';
  String get licensesIntro => isGerman
      ? 'Fibu ist Open Source und unter der MIT-Lizenz veröffentlicht. Die App baut auf bewährten Open-Source-Komponenten auf — nachfolgend sind alle verwendeten Bibliotheken mit ihren Lizenzbedingungen transparent aufgeführt.'
      : 'Fibu is open source and released under the MIT license. The app builds on proven open-source components — all bundled libraries and their license terms are listed below for full transparency.';
  String get licensesLoading =>
      isGerman ? 'Lizenzen werden zusammengestellt …' : 'Collecting licenses…';
  String get licensesCoreComponents =>
      isGerman ? 'Kernkomponenten' : 'Core Components';
  String get licensesAllPackages =>
      isGerman ? 'Alle Bibliotheken' : 'All Libraries';
  String get licensesPackageListHint => isGerman
      ? 'Tippe auf eine Komponente, um den vollständigen Lizenztext zu lesen.'
      : 'Tap a component to read its full license text.';
  String get licensesDetailTitle => isGerman ? 'Lizenztext' : 'License Text';
  String get licensesRcloneDescription => isGerman
      ? 'Die Cloud-Engine von Fibu: rclone überträgt Dateien zuverlässig zu über 70 Cloud-Diensten und Protokollen und ist fest in die App integriert.'
      : 'Fibu’s cloud engine: rclone reliably transfers files to more than 70 cloud services and protocols and is built directly into the app.';
  String get licensesGomobileDescription => isGerman
      ? 'Werkzeug des Go-Projekts, mit dem rclone als native Bibliothek für iOS und Android kompiliert wird.'
      : 'The Go project tooling used to compile rclone into a native library for iOS and Android.';
  String get licensesFlutterDescription => isGerman
      ? 'Das Framework, mit dem die Fibu-Benutzeroberfläche entwickelt wurde.'
      : 'The framework used to build the Fibu user interface.';

  /// Offline-Hinweis unter deaktivierten Schaltflächen (Sync, Explorer).
  String get offlineActionHint => isGerman
      ? 'Nur mit Internetverbindung verfügbar'
      : 'Only available with an internet connection';

  // --- Letztes Backup (Dashboard) ---
  String get lastBackupNever => isGerman ? 'Noch kein Backup' : 'No backup yet';
  String lastBackupAt(String when) =>
      isGerman ? 'Letztes Backup: $when' : 'Last backup: $when';

  /// Kompakte, lokalisierte Datums-/Zeitformatierung (ohne intl-Paket).
  String formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = dt.toLocal();
    final date = isGerman
        ? '${two(d.day)}.${two(d.month)}.${d.year}'
        : '${d.year}-${two(d.month)}-${two(d.day)}';
    return '$date, ${two(d.hour)}:${two(d.minute)}';
  }

  // --- Status-Banner (ein Banner, klare Zustände) ---
  String get statusOffline =>
      isGerman ? 'Offline — keine Internetverbindung' : 'Offline — no internet connection';

  // --- Plus-Menü & Remote-Task-Import ---
  String get newTaskOption => isGerman ? 'Neue Aufgabe' : 'New Task';
  String importDetectedTasksOption(int count) => isGerman
      ? 'Erkannte Aufgaben importieren ($count)'
      : 'Import detected tasks ($count)';
  String get importRemoteTasksTitle =>
      isGerman ? 'Aufgaben importieren' : 'Import Tasks';
  String get importAction => isGerman ? 'Importieren' : 'Import';
  String get remoteTasksExplanation => isGerman
      ? 'Diese Aufgaben wurden auf deinen Cloud-Laufwerken gefunden (.fibu/config.json). Wähle aus, welche du übernehmen möchtest.'
      : 'These tasks were found on your cloud drives (.fibu/config.json). Choose which ones to adopt.';
  String tasksImportedSuccess(int count) => isGerman
      ? (count == 1 ? '1 Aufgabe importiert.' : '$count Aufgaben importiert.')
      : (count == 1 ? '1 task imported.' : '$count tasks imported.');
}

/// Riverpod provider delivering active AppStrings based on current AppLocale.
final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  final strings = AppStrings(locale);
  // Service-Schichten ohne Ref (Sync-Fortschritt etc.) lesen AppStrings.current.
  AppStrings.current = strings;
  return strings;
});

/// Context extension for fast, clean strings lookup in widgets.
extension StringsExtension on BuildContext {
  AppStrings get strings {
    final container = ProviderScope.containerOf(this, listen: false);
    return container.read(stringsProvider);
  }
}
