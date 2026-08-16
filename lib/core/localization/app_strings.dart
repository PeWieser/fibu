import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_provider.dart';

/// Comprehensive localization dictionary for German (de) and English (en).
class AppStrings {
  final AppLocale locale;

  const AppStrings(this.locale);

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
  String get exploreRemoteFiles => isGerman ? 'Cloud-Dateien durchsuchen' : 'Explore Remote Files';
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
  String get noDrivesConnected => isGerman ? 'Keine Cloud-Laufwerke verbunden' : 'No Cloud Drives Connected';
  String get noDrivesDescription => isGerman
      ? 'Verbinde dein erstes Cloud-Laufwerk, um Backups zu sichern.'
      : 'Connect your first cloud account to start backing up files securely.';
  String get wizardStep1Title => isGerman ? 'Schritt 1: Anbieter auswählen' : 'Step 1: Choose Provider';
  String get wizardStep2Title => isGerman ? 'Schritt 2: Zugangsdaten' : 'Step 2: Credentials & Config';
  String get connectionNameLabel => isGerman ? 'Verbindungsname' : 'Connection Name';
  String get connectionNameHint => isGerman ? 'z.B. Mein_Cloud_Backup' : 'e.g. My_Cloud_Backup';
  String get searchProviderHint => isGerman ? 'Anbieter suchen (z.B. google, onedrive, s3, webdav, mega)...' : 'Search provider (e.g. google, onedrive, s3, webdav, mega)...';
  String get emailOrUserLabel => isGerman ? 'E-Mail / Benutzername' : 'Email / Username';
  String get passwordLabel => isGerman ? 'Passwort / API-Key' : 'Password / API Key';
  String get hostLabel => isGerman ? 'Host / Server-Adresse' : 'Host / Server Address';
  String get portLabel => isGerman ? 'Port' : 'Port';
  String get testConnection => isGerman ? 'Verbindung testen' : 'Test Connection';
  String get connectionSuccess => isGerman ? 'Verbindung erfolgreich hergestellt!' : 'Connection established successfully!';
  String get connectionFailed => isGerman ? 'Verbindungstest fehlgeschlagen' : 'Connection test failed';
  String get nameRequiredError => isGerman ? 'Bitte gib einen Verbindungsnamen ein.' : 'Please enter a connection name.';
  String get providerRequiredError => isGerman ? 'Bitte wähle einen Anbieter aus der Liste aus.' : 'Please select a provider from the list.';
  String get credentialsRequiredError => isGerman ? 'Bitte fülle alle Pflichtfelder aus.' : 'Please fill in all required credentials.';
  String get deleteDriveConfirmTitle => isGerman ? 'Cloud-Laufwerk trennen' : 'Disconnect Cloud Remote';
  String get deleteDriveRule6Notice => isGerman
      ? 'Bereits hochgeladene Dateien bleiben in der Cloud erhalten.'
      : 'Already uploaded files will remain stored in the cloud.';
  String deleteDrivePrompt(String name) => isGerman
      ? 'Möchtest du die Verbindung zu "$name" wirklich trennen?'
      : 'Do you really want to disconnect from "$name"?';
  String get oauthInfoNotice => isGerman
      ? 'Dieser Anbieter nutzt sichere Web-Authentifizierung (OAuth 2.0). Kein Passwort nötig — du wirst zur Anmeldung im Browser weitergeleitet.'
      : 'This provider uses secure OAuth 2.0. No password needed — you will be redirected to your browser to authenticate.';
  String get oauthGenericTooltip => isGerman
      ? 'OAuth 2.0 ermöglicht eine sichere Anmeldung direkt beim Anbieter ohne Speicherung deines Passworts.'
      : 'OAuth 2.0 enables secure login directly with the provider without storing your password.';
  String get authorizeInBrowser => isGerman ? 'In Browser autorisieren' : 'Authorize in Browser';
  String get authorizedSuccess => isGerman ? 'Autorisierung erfolgreich verifiziert' : 'Authorization verified successfully';
  String get testingConnection => isGerman ? 'Verbindung wird getestet...' : 'Testing connection...';
  String get addingRemote => isGerman ? 'Laufwerk wird eingerichtet...' : 'Configuring remote...';
  String get deletingRemote => isGerman ? 'Laufwerk wird getrennt...' : 'Disconnecting remote...';
  String driveAddedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk "$name" wurde erfolgreich hinzugefügt.'
      : 'Cloud drive "$name" added successfully.';
  String driveDeletedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk "$name" wurde getrennt.'
      : 'Cloud drive "$name" disconnected.';
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
  String get sourceCategoryLabel => isGerman ? 'Kategorie (Medien)' : 'Media Category';
  String get catchUpNotice => isGerman
      ? 'Verpasste Backups werden automatisch beim nächsten Systemstart nachgeholt.'
      : 'Missed scheduled backups are caught up automatically on next system startup.';
  String get deleteTaskConfirmTitle => isGerman ? 'Backup-Aufgabe löschen' : 'Delete Backup Task';
  String get deleteTaskRule6Notice => isGerman
      ? 'Die bereits hochgeladenen Dateien in der Cloud bleiben erhalten.'
      : 'Already uploaded files in the cloud will remain intact.';
  String deleteTaskPrompt(String name) => isGerman
      ? 'Möchtest du die Aufgabe "$name" wirklich löschen?'
      : 'Do you really want to delete the task "$name"?';
  String get taskNameRequiredError => isGerman ? 'Bitte gib einen Namen für die Aufgabe ein.' : 'Please enter a task name.';
  String get sourcePathRequiredError => isGerman ? 'Bitte wähle einen Quellpfad aus.' : 'Please select a source path.';
  String get noTasksConfigured => isGerman ? 'Keine Backup-Aufgaben vorhanden' : 'No Backup Tasks Configured';
  String get noTasksDescription => isGerman
      ? 'Erstelle deine erste Backup-Aufgabe, um Dateien automatisch zu sichern.'
      : 'Create your first backup task to start automating your cloud backups.';
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

  // --- Sync Modes (Incremental vs Echo / Mirror with Two-Way Sync) ---
  String get syncModeLabel => isGerman ? 'Synchronisations-Modus' : 'Sync Mode';
  String get syncModeIncremental => isGerman ? 'Inkrementell' : 'Incremental';
  String get syncModeIncrementalDescription => isGerman
      ? 'Nur neue und geänderte Dateien hochladen. In der Cloud vorhandene Dateien bleiben immer erhalten (sicher).'
      : 'Upload only new and modified files. Remote cloud files are always preserved (safe).';
  String get syncModeMirror => isGerman ? 'Echo-Modus (2-Wege-Spiegelung)' : 'Mirror Mode (2-Way Echo)';
  String get syncModeMirrorDescription => isGerman
      ? 'Exakte 2-Wege-Spiegelung: Neue Dateien aus der Cloud werden auch lokal heruntergeladen. Dateien, die du lokal löschst, werden auch in der Cloud gelöscht!'
      : 'Exact 2-way mirror: New files from cloud are downloaded locally. Files deleted locally will also be deleted in the cloud!';
  String get syncModeBadgeIncremental => isGerman ? 'Inkrementell' : 'Incremental';
  String get syncModeBadgeMirror => isGerman ? 'Echo (2-Wege)' : 'Echo (2-Way)';
  String get syncModeTooltipIncremental => isGerman
      ? 'Modus Inkrementell: Neue Dateien hochladen, gelöschte Dateien in der Cloud behalten'
      : 'Incremental mode: Uploads new files, preserves deleted files in cloud';
  String get syncModeTooltipMirror => isGerman
      ? 'Echo-Modus (2-Wege): Vollständiger Abgleich zwischen lokalem Ordner und Cloud inkl. Download neuer Cloud-Dateien und Löschabgleich'
      : 'Echo mode (2-Way): Full synchronization between local and cloud including cloud downloads and delete mirroring';

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
  String get deleteFile => isGerman ? 'Datei löschen' : 'Delete File';
  String get deleteFileConfirmTitle => isGerman ? 'Datei in der Cloud löschen' : 'Delete Cloud File';
  String deleteFileRule6Notice(String name) => isGerman
      ? 'Dateien, die du in der Cloud löschst, werden nicht wiederhergestellt. Zudem wird eine Ausschlussregel erstellt, damit die lokale Datei beim nächsten Sync nicht erneut hochgeladen wird.'
      : 'Files deleted in the cloud cannot be restored. An exclusion rule will be created so local files will not be re-uploaded on the next sync.';
  String deleteFilePrompt(String name) => isGerman
      ? 'Möchtest du "$name" wirklich aus dem Cloud-Speicher löschen?'
      : 'Do you really want to delete "$name" from cloud storage?';
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
  String get preferences => isGerman ? 'Einstellungen' : 'Preferences';
  String get appConfiguration => isGerman ? 'Anwendungskonfiguration' : 'Application Configuration';
  String get drivesSection => isGerman ? 'Cloud-Verbindungen' : 'Cloud Connections';
  String get manageDrivesSubtitle => isGerman ? 'Remotes verbinden, bearbeiten und trennen' : 'Connect, edit, and disconnect cloud remotes';
  String get aboutSection => isGerman ? 'Über Fibu' : 'About Fibu';
  String get tooltipLanguage => isGerman ? 'Wähle die Sprache der Benutzeroberfläche.' : 'Choose the interface language.';
  String get tooltipThemeMode => isGerman
      ? 'Wähle zwischen automatischem System-Modus oder manuellem Dunkel-/Hellmodus.'
      : 'Choose between automatic system mode or manual dark/light mode.';
  String get tooltipWadaPalette => isGerman
      ? 'Wähle eine traditionelle japanische Sanzo Wada Farbpalette für ein harmonisches Design.'
      : 'Choose a traditional Japanese Sanzo Wada color palette for balanced styling.';

  // --- Onboarding ---
  String get onboardingWelcomeTitle => isGerman ? 'Willkommen bei Fibu' : 'Welcome to Fibu';
  String get onboardingWelcomeSubtitle => isGerman ? 'Deine persönliche Multi-Cloud Backup-Zentrale' : 'Your Personal Multi-Cloud Backup Hub';
  String get onboardingFeature1Title => isGerman ? 'Multi-Cloud Backup' : 'Multi-Cloud Backup';
  String get onboardingFeature1Desc => isGerman
      ? 'Verbinde beliebige Cloud-Speicher (Google Drive, OneDrive, S3, Mega, WebDAV etc.) und sichere deine Dateien flexibel.'
      : 'Connect any cloud storage (Google Drive, OneDrive, S3, Mega, WebDAV etc.) and backup files with full flexibility.';
  String get onboardingFeature2Title => isGerman ? 'Automatische Synchronisation' : 'Automated Synchronization';
  String get onboardingFeature2Desc => isGerman
      ? 'Automatische Zeitpläne, intelligentes Splitting und 2-Wege Echo-Spiegelung.'
      : 'Automated schedules, smart storage balancing, and 2-way mirror synchronization.';
  String get onboardingFeature3Title => isGerman ? 'Volle Kontrolle & Datenschutz' : 'Full Control & Privacy';
  String get onboardingFeature3Desc => isGerman
      ? 'Keine Cloud-Abhängigkeit. Alle Daten und Konfigurationen gehören dir.'
      : 'No vendor lock-in. Your files and configs stay entirely in your control.';
  String get onboardingStep1ConnectTitle => isGerman ? 'Schritt 1: Cloud-Speicher verbinden' : 'Step 1: Connect Cloud Storage';
  String get onboardingStep1ConnectDesc => isGerman
      ? 'Verbinde dein erstes Cloud-Laufwerk, um deine Backups sicher in der Cloud zu speichern.'
      : 'Connect your first cloud account to start storing backups securely in the cloud.';
  String get onboardingConnectDriveButton => isGerman ? 'Cloud-Laufwerk hinzufügen' : 'Add Cloud Drive';
  String get onboardingStep2TaskTitle => isGerman ? 'Schritt 2: Erste Backup-Aufgabe' : 'Step 2: First Backup Task';
  String get onboardingStep2TaskDesc => isGerman
      ? 'Wähle einen lokalen Ordner auf deinem Computer und starte dein erstes Backup.'
      : 'Choose a local folder on your computer to automate your first backup.';
  String get onboardingCreateTaskButton => isGerman ? 'Erste Aufgabe erstellen' : 'Create First Task';
  String get onboardingSkip => isGerman ? 'Später einrichten' : 'Set Up Later';
  String get onboardingGetStarted => isGerman ? 'Jetzt loslegen' : 'Get Started';
  String get onboardingDoneTitle => isGerman ? 'Du bist startklar!' : 'You are all set!';
  String get onboardingDoneSubtitle => isGerman
      ? 'Fibu ist eingerichtet und bereit für deine Backups.'
      : 'Fibu is configured and ready for your backups.';

  // --- Task 3-Step Wizard ---
  String get taskWizardStep1Title => isGerman ? 'Schritt 1: Grundlagen' : 'Step 1: Basics';
  String get taskWizardStep1Subtitle => isGerman ? 'Aufgabenname & Quellverzeichnis' : 'Task name & source directory';
  String get taskWizardStep2Title => isGerman ? 'Schritt 2: Cloud-Ziel' : 'Step 2: Cloud Destination';
  String get taskWizardStep2Subtitle => isGerman ? 'Ziel-Laufwerke & Cloud-Ordner' : 'Destination drives & remote folder';
  String get taskWizardStep3Title => isGerman ? 'Schritt 3: Zeitplan & Modus' : 'Step 3: Schedule & Mode';
  String get taskWizardStep3Subtitle => isGerman ? 'Synchronisationsart & Wiederholung' : 'Sync type & recurrence';
  String get stepIndicator => isGerman ? 'Schritt' : 'Step';

  // --- Config Detection & Sync Logs ---
  String get existingConfigDetectedTitle => isGerman ? 'Bestehende Fibu-Konfiguration gefunden' : 'Existing Fibu Configuration Found';
  String existingConfigDetectedMessage(String remoteName) => isGerman
      ? 'Auf dem Cloud-Laufwerk "$remoteName" wurde eine bestehende Fibu-Konfiguration (.fibu/config.json) gefunden.\n\nMöchtest du diese Konfiguration importieren und eine lokale Kopie samt Spiegel-Task anlegen?'
      : 'An existing Fibu configuration (.fibu/config.json) was found on cloud remote "$remoteName".\n\nWould you like to import this configuration and create a local mirror sync task?';
  String get importConfigAndSync => isGerman ? 'Importieren & Spiegeln' : 'Import & Mirror';
  String get skipConfigImport => isGerman ? 'Überspringen' : 'Skip';
  String get configImportSuccess => isGerman ? 'Konfiguration erfolgreich importiert!' : 'Configuration imported successfully!';
  String get localLog => isGerman ? 'Lokales Protokoll' : 'Local Log';
  String get remoteLog => isGerman ? 'Remote-Protokoll' : 'Remote Log';
  String get defaultBackupFolder => isGerman ? 'fibu-backup' : 'fibu-backup';

  // --- Mobile Onboarding & Tasks ---
  String get onboardingMediaBackupTitle => isGerman ? 'Medien-Backup (Fotos & Videos)' : 'Media Backup (Photos & Videos)';
  String get onboardingMediaBackupDesc => isGerman
      ? 'Sichert automatisch alle Fotos und Videos aus deiner Galerie / Fotos-App in die Cloud.'
      : 'Automatically backs up all photos and videos from your gallery / Photos app to the cloud.';
  String get onboardingDocsBackupTitle => isGerman ? 'Dokumente & lokale Dateien' : 'Documents & Local Files';
  String get onboardingDocsBackupDesc => isGerman
      ? 'Sichert zusätzlich alle Dokumente und lokalen Dateien aus deiner Dateien-App.'
      : 'Optionally backs up all local documents and files from your Files app.';
  String get onboardingSelectBackupsHeader => isGerman ? 'Vorgeschlagene Backup-Aufgaben' : 'Recommended Backup Tasks';
  String get onboardingSelectBackupsSubtitle => isGerman
      ? 'Wähle aus, was automatisch für dich gesichert werden soll:'
      : 'Select what should be automatically backed up for you:';

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
  String get advancedSettings => isGerman ? 'Erweiterte Einstellungen' : 'Advanced Settings';
  String get noMediaPermissionError => isGerman
      ? 'Zugriff auf Mediathek verweigert. Bitte erlaube den Foto-Zugriff in den iOS-Einstellungen.'
      : 'Photo library access denied. Please grant photo permission in iOS Settings.';
  String get networkUnavailableError => isGerman
      ? 'Keine aktive Internetverbindung vorhanden.'
      : 'No active internet connection available.';
  String get cellularSyncBlockedNotice => isGerman
      ? 'Synchronisierung pausiert: Verbindung über Mobilfunk nicht erlaubt (WLAN erforderlich).'
      : 'Sync paused: Cellular data connection blocked (Wi-Fi required).';
}

/// Riverpod provider delivering active AppStrings based on current AppLocale.
final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return AppStrings(locale);
});

/// Context extension for fast, clean strings lookup in widgets.
extension StringsExtension on BuildContext {
  AppStrings get strings {
    final container = ProviderScope.containerOf(this, listen: false);
    return container.read(stringsProvider);
  }
}
