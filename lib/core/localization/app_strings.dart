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

  // --- Cloud Drives ---
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
  String get connectionNameHint => isGerman ? 'z.B. GoogleDrive_Backup' : 'e.g. GoogleDrive_Backup';
  String get searchProviderHint => isGerman ? 'Anbieter suchen (z.B. mega, google, onedrive)...' : 'Search provider (e.g. mega, google, onedrive)...';
  String get emailOrUserLabel => isGerman ? 'E-Mail / Benutzername' : 'Email / Username';
  String get passwordLabel => isGerman ? 'Passwort / API-Key' : 'Password / API Key';
  String get hostLabel => isGerman ? 'Host / Server-Adresse' : 'Host / Server Address';
  String get portLabel => isGerman ? 'Port' : 'Port';
  String get testConnection => isGerman ? 'Verbindung testen' : 'Test Connection';
  String get connectionSuccess => isGerman ? 'Verbindung erfolgreich hergestellt!' : 'Connection established successfully!';
  String get connectionFailed => isGerman ? 'Verbindungstest fehlgeschlagen' : 'Connection test failed';
  String get nameRequiredError => isGerman ? 'Bitte gib einen Verbindungsnamen ein.' : 'Please enter a connection name.';
  String get providerRequiredError => isGerman ? 'Bitte wähle einen Anbieter aus.' : 'Please select a provider.';
  String get credentialsRequiredError => isGerman ? 'Bitte fülle alle Pflichtfelder aus.' : 'Please fill in all required credentials.';
  String get deleteDriveConfirmTitle => isGerman ? 'Cloud-Laufwerk trennen' : 'Disconnect Cloud Remote';
  String get deleteDriveRule6Notice => isGerman
      ? 'Bereits hochgeladene Dateien bleiben in der Cloud erhalten.'
      : 'Already uploaded files will remain stored in the cloud.';
  String deleteDrivePrompt(String name) => isGerman
      ? 'Möchtest du die Verbindung zu "$name" wirklich trennen?'
      : 'Do you really want to disconnect from "$name"?';
  String get oauthInfoNotice => isGerman
      ? 'Dieser Anbieter nutzt Web-Authentifizierung (OAuth). Nach dem Hinzufügen öffnet sich bei Bedarf ein Browser-Fenster zur Autorisierung.'
      : 'This provider uses browser-based OAuth authentication. A browser window will open if authorization is needed.';
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


  // --- Tasks ---
  String get tasksTitle => isGerman ? 'Backup-Aufgaben' : 'Tasks & Backup Jobs';
  String get addTask => isGerman ? 'Aufgabe erstellen' : 'Add Task';
  String get editTask => isGerman ? 'Aufgabe bearbeiten' : 'Edit Task';
  String get deleteTask => isGerman ? 'Aufgabe löschen' : 'Delete Task';
  String get taskNameLabel => isGerman ? 'Aufgabenname' : 'Task Name';
  String get taskNameHint => isGerman ? 'z.B. Kamera-Fotos Backup' : 'e.g. Camera Photos Backup';
  String get sourcePathLabel => isGerman ? 'Quellordner (Lokal)' : 'Source Folder (Local)';
  String get sourcePathHint => isGerman ? 'z.B. C:\\Bilder' : 'e.g. C:\\Pictures';
  String get selectFolder => isGerman ? 'Ordner wählen' : 'Select Folder';
  String get destinationRemoteLabel => isGerman ? 'Ziel (Cloud-Laufwerk)' : 'Destination (Cloud Remote)';
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

  // --- Cloud Explorer ---
  String get cloudExplorerTitle => isGerman ? 'Cloud-Dateiexplorer' : 'Cloud File Explorer';
  String get remoteDriveSelectorLabel => isGerman ? 'Cloud-Laufwerk' : 'Remote Drive';
  String get emptyFolder => isGerman ? 'Dieser Ordner ist leer.' : 'This folder is empty.';
  String get noRemotesInExplorer => isGerman ? 'Keine Cloud-Laufwerke verbunden.' : 'No cloud drives connected.';
  String get addRemoteCTA => isGerman ? 'Laufwerk hinzufügen' : 'Add Cloud Drive';
  String get fileDetailsTitle => isGerman ? 'Datei-Informationen' : 'File Information';
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
  String get version => isGerman ? 'Version 1.0.0 (Fibu Desktop)' : 'Version 1.0.0 (Fibu Desktop)';
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
