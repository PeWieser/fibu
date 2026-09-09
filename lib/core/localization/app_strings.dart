import 'package:flutter/foundation.dart';
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
  String get error => isGerman ? 'Fehler' : 'Error';
  String get success => isGerman ? 'Erfolgreich' : 'Success';
  String get retry => isGerman ? 'Wiederholen' : 'Retry';
  String get name => isGerman ? 'Name' : 'Name';
  String get drivesRefreshed => isGerman ? 'Cloud-Laufwerke & Speicherplatz wurden aktualisiert.' : 'Cloud drives and quota refreshed.';

  // --- Dashboard ---
  String get allFilesSynced => isGerman ? 'Alle Dateien synchronisiert' : 'All Files Synced';
  String get syncActive => isGerman ? 'Synchronisierung läuft...' : 'Syncing Active...';
  String get syncCancelled => isGerman ? 'Synchronisierung abgebrochen' : 'Sync Cancelled';
  String get syncFailed => isGerman ? 'Synchronisierung fehlgeschlagen' : 'Sync Failed';
  String get syncAll => isGerman ? 'Alle synchronisieren' : 'Sync All Files';
  /// Öffnet den Fotos-Manager des Laufwerks (früher: Dateiexplorer).
  String get exploreRemoteFiles =>
      isGerman ? 'Fotos in der Cloud ansehen' : 'View Photos in the Cloud';
  String get cloudBackupStorage => isGerman ? 'Cloud-Speicherplatz' : 'Cloud Backup Storage';
  String get noDrivesConfigured => isGerman ? 'Keine Backup-Laufwerke eingerichtet. Füge eines in den Einstellungen hinzu.' : 'No backup drives configured. Add one in Settings.';
  String get currentFile => isGerman ? 'Aktuelle Datei:' : 'Current File:';
  String get preparing => isGerman ? 'Wird vorbereitet...' : 'Preparing...';
  String get tooltipStorageCard => isGerman ? 'Klicke hier für die detaillierte Speicherbelegung nach Dateitypen.' : 'Click here for detailed storage breakdown by file type.';



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
  String get authorizeInBrowser => isGerman ? 'Beim Anbieter anmelden' : 'Sign in with provider';
  String get authorizedSuccess => isGerman ? 'Autorisierung erfolgreich verifiziert' : 'Authorization verified successfully';
  String driveAddedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk „$name“ wurde erfolgreich hinzugefügt.'
      : 'Cloud drive “$name” added successfully.';
  String driveDeletedSuccess(String name) => isGerman
      ? 'Cloud-Laufwerk „$name“ wurde getrennt.'
      : 'Cloud drive “$name” disconnected.';
  String get noMatchingProviders => isGerman ? 'Keine passenden Anbieter gefunden.' : 'No matching providers found.';
  String get showPassword => isGerman ? 'Passwort anzeigen' : 'Show password';
  String get hidePassword => isGerman ? 'Passwort verbergen' : 'Hide password';

  // --- Provider-Specific Strings & Tooltips ---
  
  
  

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
  String get noAlbumsFound => isGerman
      ? 'Keine Alben gefunden. Erteile Fotos-Zugriff, um deine Alben zu sehen.'
      : 'No albums found. Grant photo access to see your albums.';
  String get noFoldersFound => isGerman
      ? 'Keine lokalen Ordner gefunden.'
      : 'No local folders found.';
  String get targetFolderExistingLabel => isGerman ? 'Vorhandener Ordner (in der Cloud)' : 'Existing Folder (in cloud)';
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
  String get hourLabel => isGerman ? 'Stunde' : 'Hour';
  String get minuteLabel => isGerman ? 'Minute' : 'Minute';
  String get allMedia => isGerman ? 'Alles' : 'All';
  String get allPhotos => isGerman ? 'Alle Fotos' : 'All Photos';
  String get allVideos => isGerman ? 'Alle Videos' : 'All Videos';
  String get specificFolders => isGerman ? 'Nur bestimmte Ordner' : 'Specific Folders Only';
  String get specificFoldersHint => isGerman ? 'z.B. WhatsApp Images' : 'e.g. WhatsApp Images';

  // --- Multi-Remote Distribution Strategy ---

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
  /// „Spiegelung" bedeutet auf den Plattformen nicht dasselbe — und die
  /// Beschriftung muss das sagen. Vorher stand auf allen Plattformen derselbe
  /// 2-Wege-Text; auf Windows wäre das eine falsche Versprechung gewesen.
  bool get _hasTwoWayMirror =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  String get syncModeMirror => isGerman
      ? (_hasTwoWayMirror
          ? 'Spiegelung (2-Wege Mirror-Sync)'
          : 'Spiegelung (1-Weg, löscht in der Cloud)')
      : (_hasTwoWayMirror
          ? 'Mirror Sync (two-way)'
          : 'Mirror (one-way, deletes in cloud)');

  String get syncModeMirrorDescription => _hasTwoWayMirror
      ? (isGerman
          ? 'Exakte 2-Wege-Spiegelung: Neue Dateien aus der Cloud werden auch '
              'lokal heruntergeladen. Dateien, die du lokal löschst, werden '
              'auch in der Cloud gelöscht!'
          : 'Exact 2-way mirror: New files from cloud are downloaded locally. '
              'Files deleted locally will also be deleted in the cloud!')
      : (isGerman
          ? 'Ein-Weg-Spiegelung: Dein Ordner wird in die Cloud gespiegelt. '
              'Alles, was dort liegt und nicht in deinem Ordner ist, wird '
              'gelöscht — auch Dateien, die ein anderes Gerät hochgeladen hat. '
              'Es wird nichts heruntergeladen. Für einen geteilten Zielordner '
              'nicht geeignet; nimm dafür „Inkrementell".'
          : 'One-way mirror: your folder is mirrored into the cloud. Anything '
              'there that is not in your folder gets deleted — including files '
              'another device uploaded. Nothing is downloaded. Not suitable for '
              'a shared target folder; use “Incremental” for that.');
  String get syncModeBadgeIncremental => isGerman ? 'Inkrementell' : 'Incremental';
  String get syncModeBadgeMirror => isGerman ? 'Spiegelung' : 'Mirror Sync';
  String get syncModeTooltipIncremental => isGerman
      ? 'Modus Inkrementell: Neue Dateien hochladen, gelöschte Dateien in der Cloud behalten'
      : 'Incremental mode: Uploads new files, preserves deleted files in cloud';
  String get syncModeTooltipMirror => isGerman
      ? 'Spiegelung (2-Wege): Vollständiger Abgleich zwischen lokalem Ordner und Cloud inkl. Download neuer Cloud-Dateien und Löschabgleich'
      : 'Mirror mode (two-way): Full synchronization between local and cloud including cloud downloads and delete mirroring';

  String get dayDaily => isGerman ? 'Täglich' : 'Daily';
  String get dayMonday => isGerman ? 'Montag' : 'Monday';
  String get dayTuesday => isGerman ? 'Dienstag' : 'Tuesday';
  String get dayWednesday => isGerman ? 'Mittwoch' : 'Wednesday';
  String get dayThursday => isGerman ? 'Donnerstag' : 'Thursday';
  String get dayFriday => isGerman ? 'Freitag' : 'Friday';
  String get daySaturday => isGerman ? 'Samstag' : 'Saturday';
  String get daySunday => isGerman ? 'Sonntag' : 'Sunday';
  String get dayManual => isGerman ? 'Manuell' : 'Manual';
  String get tooltipDestinationRemote => isGerman ? 'Ziel-Cloud-Laufwerke und Remote-Ordner.' : 'Destination cloud drives and target folder.';
  String get tooltipCatchUp => isGerman ? 'Wenn dein PC zur geplanten Zeit aus war, wird das Backup beim nächsten Systemstart automatisch nachgeholt.' : 'If PC was offline during scheduled time, backup runs on next startup.';
  String get tooltipSchedule => isGerman ? 'Intervall und Uhrzeit für die automatische Ausführung des Backups.' : 'Interval and time for automatic backup execution.';

  // --- Cloud Explorer & File Details ---

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

  /// Monats-Trenner im Raster („September 2026").
  String cloudPhotosMonthLabel(DateTime day) {
    const monthsDe = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final months = isGerman ? monthsDe : monthsEn;
    return '${months[day.month - 1]} ${day.year}';
  }
  String get fileName => isGerman ? 'Dateiname:' : 'File Name:';
  String get fileSize => isGerman ? 'Dateigröße:' : 'File Size:';
  String get downloadFile => isGerman ? 'Herunterladen' : 'Download';
  String get deleteFile => isGerman ? 'Datei löschen' : 'Delete File';
  String get openInDefaultApp => isGerman ? 'In Standard-App öffnen' : 'Open in Default App';
  String get copyPath => isGerman ? 'Pfad kopieren' : 'Copy Path';
  String get pathCopied => isGerman ? 'Pfad in die Zwischenablage kopiert' : 'Path copied to clipboard';
  String get copy => isGerman ? 'Kopieren' : 'Copy';
  String get zoomIn => isGerman ? 'Vergrößern' : 'Zoom In';
  String get zoomOut => isGerman ? 'Verkleinern' : 'Zoom Out';
  String get resetZoom => isGerman ? 'Originalgröße' : 'Reset Zoom';
  String get linesLabel => isGerman ? 'Zeilen' : 'Lines';
  String get charactersLabel => isGerman ? 'Zeichen' : 'Characters';

  // --- File Metadata Inspector Attributes ---

  // --- Settings ---
  String get settingsTitle => isGerman ? 'Einstellungen' : 'Settings';
  String get appearanceSection => isGerman ? 'Erscheinungsbild' : 'Appearance';
  /// Hinweis unter „Erscheinungsbild": Hell/Dunkel ist keine Einstellung.
  String get appearanceAutoHint => isGerman
      ? 'Hell und Dunkel folgen dem System. Die gewählte Palette gilt für beides.'
      : 'Light and dark follow the system. The palette you choose applies to both.';

  /// Name des neutralen Standard-Farbschemas im Farbwähler.
  String get paletteStandard => isGerman ? 'Standard' : 'Standard';
  String get cloudStorage => isGerman ? 'Cloud-Speicher' : 'Cloud Storage';
  String get manageCloudDrives => isGerman ? 'Cloud-Laufwerke verwalten' : 'Manage Cloud Drives';
  String get languageSection => isGerman ? 'Sprache' : 'Language';
  String get tooltipNetwork => isGerman
      ? 'Lege fest, ob Backups auch über mobile Daten laufen dürfen.'
      : 'Choose whether backups may also run over cellular data.';


  String get tooltipLanguage => isGerman ? 'Wähle die Sprache der Benutzeroberfläche.' : 'Choose the interface language.';
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

  // --- iOS Background Sync Notice & WiFi-Only Sync ---
  String get iosBackgroundScheduleNotice => isGerman
      ? 'Hinweis: Unter iOS steuert das Betriebssystem Hintergrund-Backups (BGProcessingTask) eigenständig nach Kriterien wie Ladezustand, Inaktivität und WLAN-Verbindung. Eine feste Uhrzeit ist nicht erforderlich.'
      : 'Notice: On iOS, background backups (BGProcessingTask) are managed dynamically by the system when charging, idle, and connected to Wi-Fi. An exact minute schedule is not required.';
  String get wifiOnlySyncLabel => isGerman ? 'Nur über WLAN synchronisieren' : 'Sync on Wi-Fi Only';
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

  // --- 70+ Provider Categories & Progressive Disclosure ---
  String get advancedSettings => isGerman ? 'Erweiterte Einstellungen anzeigen' : 'Show Advanced Settings';
  String get hideAdvancedSettings => isGerman ? 'Erweiterte Einstellungen ausblenden' : 'Hide Advanced Settings';
  String get networkUnavailableError => isGerman
      ? 'Keine aktive Internetverbindung vorhanden.'
      : 'No active internet connection available.';
  String get cellularSyncBlockedNotice => isGerman
      ? 'Synchronisierung pausiert: Verbindung über Mobilfunk nicht erlaubt (WLAN erforderlich).'
      : 'Sync paused: Cellular data connection blocked (Wi-Fi required).';

  // --- Offline-Banner & Netzwerk-Hinweise ---

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
  String get selectAtLeastOneAlbum => isGerman
      ? 'Bitte wähle mindestens ein Album aus.'
      : 'Please select at least one album.';

  // --- Eine Cloud, eine Sicherung (Einstellungen) ---
  String get cloudSection => isGerman ? 'Cloud' : 'Cloud';
  String get cloudConnect => isGerman ? 'Cloud verbinden' : 'Connect a cloud';
  String get cloudNone =>
      isGerman ? 'Noch keine Cloud verbunden' : 'No cloud connected yet';
  String get cloudManageHint => isGerman
      ? 'Umbenennen, ersetzen oder trennen'
      : 'Rename, replace or disconnect';
  String cloudMembersCount(int n) => isGerman
      ? '$n Laufwerke gebündelt'
      : '$n drives bundled';

  String get backupSection => isGerman ? 'Sicherung' : 'Backup';
  String get backupCreate =>
      isGerman ? 'Sicherung einrichten' : 'Set up the backup';
  String get backupCreateHint => isGerman
      ? 'Ordner wählen — Ziel ist die verbundene Cloud.'
      : 'Pick folders — the target is the connected cloud.';
  String get backupNeedsCloud => isGerman
      ? 'Zuerst eine Cloud verbinden.'
      : 'Connect a cloud first.';
  String get backupAddFolder =>
      isGerman ? 'Ordner hinzufügen' : 'Add folder';
  String get backupNoFolder => isGerman
      ? 'Noch kein Ordner gewählt — die Sicherung läuft erst mit einem.'
      : 'No folder selected yet — the backup needs one.';
  String get backupSyncMode => isGerman ? 'Abgleich' : 'Sync mode';
  String get backupCloudFolder =>
      isGerman ? 'Ordner in der Cloud' : 'Folder in the cloud';
  String get backupActiveLabel =>
      isGerman ? 'Sicherung aktiv' : 'Backup active';
  String get backupActiveHint => isGerman
      ? 'Nur eine aktive Sicherung läuft zum Zeitplan.'
      : 'Only an active backup runs on schedule.';

  String get systemSection => isGerman ? 'System' : 'System';

  // --- Vorschaubilder (Cloud-Explorer) ---
  String get cannotDisplayFormat => isGerman
      ? 'Dieses Format kann Flutter nicht anzeigen. Öffne es in der Standard-App.'
      : 'Flutter cannot display this format. Open it in the default app.';
  String thumbsMissing(int count) => isGerman
      ? 'Für $count ${count == 1 ? 'Aufnahme fehlt' : 'Aufnahmen fehlen'} die Vorschau.'
      : 'Missing previews for $count ${count == 1 ? 'item' : 'items'}.';
  String get thumbsCreate =>
      isGerman ? 'Jetzt erzeugen' : 'Create now';
  String get thumbsLater => isGerman ? 'Später' : 'Later';
  String get thumbsCreating =>
      isGerman ? 'Vorschauen werden erzeugt …' : 'Creating previews …';

  /// Bestandteil-Auswahl im Assistenten: weitere Cloud im selben Durchgang
  /// anlegen, statt den Assistenten zu verlassen.
  String get wizardAddMemberCloud => isGerman
      ? 'Weitere Cloud hinzufügen'
      : 'Add another cloud';
  String get wizardMembersHint => isGerman
      ? 'Die ausgewählten Laufwerke werden zu einer Cloud gebündelt. Auf sie wird gesichert.'
      : 'The selected drives are bundled into one cloud. That is the backup target.';

  // --- Speicherplatz-Anzeige der Cloud-Laufwerke ---
  String quotaSummaryUsedOf(String used, String total) =>
      isGerman ? '$used von $total belegt' : '$used of $total used';
  String get quotaSummaryUnavailable =>
      isGerman ? 'Speicherplatz n. v.' : 'Storage n/a';
  String quotaSummaryFree(String free) =>
      isGerman ? '$free frei' : '$free free';
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
  String get appVersionLabel => isGerman ? 'Version' : 'Version';
  String get appVersionValue => '1.0.0 (Build 1)';
  String get developerLabel => isGerman ? 'Entwickler' : 'Developer';
  String get developerValue => 'Fibu Open Source Team';
  String get cloudEngineLabel => isGerman ? 'Cloud-Engine' : 'Cloud Engine';
  String get cloudEngineValue => isGerman ? 'rclone (70+ Anbieter)' : 'rclone (70+ providers)';
  String get licenseLabel => isGerman ? 'Lizenz' : 'License';
  String get licenseValue => 'MIT License';

  // --- Task Details & Actions ---
  String get statusActive => isGerman ? 'Aktiv' : 'Active';
  String get statusInactive => isGerman ? 'Inaktiv' : 'Inactive';
  String get syncTaskNow => isGerman ? 'Jetzt synchronisieren' : 'Sync Now';
  String get syncTriggeredSuccess => isGerman ? 'Synchronisierung wurde gestartet' : 'Sync started successfully';
  String get generalSection => isGerman ? 'Allgemein' : 'General';
  String get sourceAndTargetSection => isGerman ? 'Quelle & Ziel' : 'Source & Destination';
  String get syncSettingsSection => isGerman ? 'Synchronisation' : 'Synchronization';
  String get scheduleAndNetworkSection => isGerman ? 'Zeitplan & Netzwerk' : 'Schedule & Network';
  String get targetFolderLabel => isGerman ? 'Zielordner' : 'Destination Folder';
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
  // --- Gerät-zu-Gerät-Kopplung ---
  String get pairingTitle =>
      isGerman ? 'Konfiguration übertragen' : 'Transfer Configuration';
  String get pairingReceiverIntro => isGerman
      ? 'Dieses Gerät wartet auf die Konfiguration eines anderen Geräts. Es ist im lokalen Netz auffindbar, solange es wartet — übertragen wird direkt von Gerät zu Gerät, ohne Server dazwischen.'
      : 'This device is waiting for the configuration of another device. It stays discoverable on the local network while it waits — the transfer goes directly device to device, with no server in between.';
  String get pairingSenderIntro => isGerman
      ? 'Auf dem anderen Gerät „Empfangen" starten — es erscheint dann hier mit seinem Namen. Ein Tipp überträgt Laufwerke mit Zugangsdaten, Aufgaben und Einstellungen: verschlüsselt, direkt von Gerät zu Gerät.'
      : 'Start “Receive” on the other device — it then shows up here with its name. One tap transfers drives with credentials, tasks and settings: encrypted, directly device to device.';
  String get pairingStart =>
      isGerman ? 'Empfangen starten' : 'Start receiving';
  String get pairingWaiting =>
      isGerman ? 'Warte auf das andere Gerät …' : 'Waiting for the other device …';

  // --- Bestätigung vor dem Überschreiben ---
  String pairingConfirmRequest(String device, int remotes, int tasks) => isGerman
      ? '„$device" hat eine Konfiguration gesendet: $remotes ${remotes == 1 ? 'Laufwerk' : 'Laufwerke'}, $tasks ${tasks == 1 ? 'Aufgabe' : 'Aufgaben'}.'
      : '“$device” sent a configuration: $remotes ${remotes == 1 ? 'drive' : 'drives'}, $tasks ${tasks == 1 ? 'task' : 'tasks'}.';
  String get pairingConfirmOverwrite => isGerman
      ? 'Übernehmen ersetzt die Laufwerke, Zugangsdaten und Aufgaben auf diesem Gerät. Aufgaben mit einer Mediathek-Quelle brauchen danach noch einen Ordner.'
      : 'Applying replaces the drives, credentials and tasks on this device. Tasks with a library source still need a folder afterwards.';
  String get pairingAccept => isGerman ? 'Übernehmen' : 'Apply';
  String get pairingReject => isGerman ? 'Ablehnen' : 'Reject';
  String get pairingRejected => isGerman
      ? 'Abgelehnt — es wurde nichts geändert.'
      : 'Rejected — nothing was changed.';
  String pairingReceived(String device, int remotes, int tasks) => isGerman
      ? 'Konfiguration von „$device" übernommen: $remotes Laufwerke, $tasks Aufgaben. Aufgaben mit Mediathek-Quelle brauchen noch einen Ordner.'
      : 'Configuration from “$device” applied: $remotes drives, $tasks tasks. Tasks with a library source still need a folder.';
  String get pairingSubtitle => isGerman
      ? 'Konfiguration direkt von Gerät zu Gerät übertragen'
      : 'Transfer configuration directly between devices';

  // --- Automatische Erkennung im lokalen Netz ---
  String get pairingSearching => isGerman
      ? 'Suche nach einem Gerät, das auf eine Konfiguration wartet …'
      : 'Looking for a device waiting for a configuration …';
  String get pairingNoneFound => isGerman
      ? 'Kein wartendes Gerät gefunden. Auf dem anderen Gerät „Empfangen" starten und erneut suchen.'
      : 'No waiting device found. Start “Receive” on the other device and search again.';
  String get pairingSearchAgain => isGerman ? 'Erneut suchen' : 'Search again';
  String get pairingFoundSubtitle => isGerman
      ? 'Bereit — tippen zum Übertragen'
      : 'Ready — tap to transfer';
  String get pairingListeningHint => isGerman
      ? 'Andere Geräte im selben Netz finden dieses Gerät automatisch.'
      : 'Other devices on the same network find this device automatically.';

  String get pairingRoleReceive =>
      isGerman ? 'Empfangen' : 'Receive';
  String get pairingRoleSend => isGerman ? 'Senden' : 'Send';

  String pairingMirrorDowngraded(int n) => isGerman
      ? '$n ${n == 1 ? 'Aufgabe wurde' : 'Aufgaben wurden'} von „Spiegelung" auf „Inkrementell" umgestellt: Der Desktop spiegelt nur in eine Richtung und würde sonst Dateien löschen, die dieses Gerät hochgeladen hat.'
      : '$n ${n == 1 ? 'task was' : 'tasks were'} switched from “Mirror” to “Incremental”: the desktop only mirrors one way and would otherwise delete files this device uploaded.';

  String get pairingTimeout => isGerman
      ? 'Zeit abgelaufen — es ist kein Gerät verbunden worden.'
      : 'Timed out — no device connected.';
  String get pairingNoNetwork => isGerman
      ? 'Keine lokale Netzadresse gefunden. Ist das Gerät mit einem Netzwerk verbunden?'
      : 'No local network address found. Is this device connected to a network?';
  String get pairingSent => isGerman
      ? 'Konfiguration übertragen.' : 'Configuration transferred.';
  String get pairingSendFailed => isGerman
      ? 'Übertragung fehlgeschlagen. Läuft auf dem anderen Gerät noch die Kopplung, und seid ihr im selben Netz?'
      : 'Transfer failed. Is the other device still pairing, and are you on the same network?';

  // --- Autostart (Windows) ---
  String get autostartLabel =>
      isGerman ? 'Mit Windows starten' : 'Start with Windows';
  String get autostartDescription => isGerman
      ? 'Fibu startet im Hintergrund, sobald du dich anmeldest, und führt den Zeitplan auch aus, wenn du die App nicht geöffnet hast. Verpasste Läufe werden beim nächsten Start nachgeholt.'
      : 'Fibu starts in the background when you sign in and runs the schedule even if you never open the app. Missed runs are caught up on the next start.';

  /// Ein anderes Gerät hält die geräteübergreifende Sperre für diesen
  /// Zielordner. Der Lauf wird übersprungen, nicht abgebrochen.
  String syncLockedByOtherDevice(String device) => isGerman
      ? 'Übersprungen — „$device" synchronisiert gerade in denselben Ordner'
      : 'Skipped — “$device” is currently syncing to the same folder';

  String get syncSourceMissing => isGerman
      ? 'Keine Quelle gewählt — bitte in der Aufgabe einen Ordner auswählen'
      : 'No source selected — please choose a folder in the task';

  String get syncStatusChecking =>
      isGerman ? 'Auf Änderungen überprüfen' : 'Checking for changes';
  /// Beide Geräte haben dieselbe Datei geändert. Keine Fassung wird
  /// überschrieben — die lokale landet unter einem Konflikt-Namen.
  String syncStatusConflict(String file) => file.isEmpty
      ? (isGerman
          ? 'Konflikt — beide Geräte haben dieselbe Datei geändert'
          : 'Conflict — both devices changed the same file')
      : (isGerman
          ? 'Konflikt bei „$file" — beide Fassungen bleiben erhalten'
          : 'Conflict on “$file” — both versions are kept');

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

  // --- Zeitplan-Beschreibung (lokalisiert UND plattformabhängig) ---
  //
  // Wer den Zeitpunkt bestimmt, unterscheidet sich je Plattform — und die
  // Beschreibung muss das sagen, sonst verspricht die App etwas Falsches:
  //  * iOS:      BGProcessingTask. Das System entscheidet, wann es passt
  //              (Laden, Ruhezustand, WLAN). Eine Uhrzeit zu nennen wäre
  //              eine Lüge, deshalb steht dort keine.
  //  * Desktop:  Der eingebaute Planer prüft alle 5 Minuten im laufenden
  //              Prozess. Die Uhrzeit wird tatsächlich eingehalten — voraus-
  //              gesetzt die App läuft, also Autostart an ist.
  //
  // Vorher stand hier unabhängig von der Plattform „von iOS gesteuert".
  bool get _scheduleIsSystemDriven =>
      defaultTargetPlatform == TargetPlatform.iOS;

  String scheduleDescriptionFor(String scheduleDay, String scheduleTime) {
    if (scheduleDay == 'iOS System' || scheduleDay == 'System') {
      return isGerman ? 'Automatisch (iOS-System)' : 'Automatic (iOS system)';
    }
    if (scheduleDay == 'Manual') {
      return isGerman ? 'Manuell' : 'Manual';
    }
    if (scheduleDay == 'Daily') {
      if (_scheduleIsSystemDriven) {
        return isGerman
            ? 'Täglich (Hintergrundtask, von iOS gesteuert)'
            : 'Daily (background task, scheduled by iOS)';
      }
      return isGerman
          ? 'Täglich um $scheduleTime'
          : 'Daily at $scheduleTime';
    }
    final day = _weekdayLabel(scheduleDay);
    if (_scheduleIsSystemDriven) {
      return isGerman
          ? 'Wöchentlich am $day (Hintergrundtask, von iOS gesteuert)'
          : 'Weekly on $day (background task, scheduled by iOS)';
    }
    return isGerman
        ? 'Wöchentlich am $day um $scheduleTime'
        : 'Weekly on $day at $scheduleTime';
  }

  /// Hinweis unter dem Zeitplan: Auf Desktop ist die Uhrzeit nur so gut wie
  //  der Autostart. Das zu verschweigen wäre dasselbe Problem in grün.
  String get schedulePlatformNote {
    if (_scheduleIsSystemDriven) {
      return isGerman
          ? 'iOS entscheidet selbst, wann der Hintergrundtask läuft — bei '
              'Ladebetrieb, Ruhezustand und WLAN.'
          : 'iOS decides when the background task runs — while charging, idle '
              'and on Wi-Fi.';
    }
    return isGerman
        ? 'Der Zeitplan läuft, solange Fibu geöffnet ist. Mit „Mit Windows '
            'starten" in den Einstellungen läuft er auch nach dem Anmelden '
            'weiter. Verpasste Läufe werden beim nächsten Start nachgeholt.'
        : 'The schedule runs while Fibu is open. Enable “Start with Windows” '
            'in Settings to keep it running after sign-in. Missed runs are '
            'caught up on the next start.';
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

  String get legendPhotos => isGerman ? 'Fotos & Bilder' : 'Photos & Images';
  String get legendVideos => isGerman ? 'Videos' : 'Videos';
  String get legendOtherDocs => isGerman ? 'Andere Dokumente' : 'Other Documents';
  String get legendFreeSpace => isGerman ? 'Freier Speicher' : 'Free Space';
  String get legendTotalCapacity => isGerman ? 'Gesamtkapazität' : 'Total Capacity';

  // --- Sync-Bedarfs-Prüfung (Aktualisieren-Button & Status-Banner) ---
  String get syncNeededBanner => isGerman
      ? 'Änderungen gefunden — Sync fällig'
      : 'Changes found — sync needed';
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


  // --- Letztes Backup (Dashboard) ---
  String get lastBackupNever => isGerman ? 'Noch kein Backup' : 'No backup yet';
  String lastBackupAt(String when) =>
      isGerman ? 'Letztes Backup: $when' : 'Last backup: $when';

  /// Kompakte, lokalisierte Datums-/Zeitformatierung (ohne intl-Paket).
  String formatDateTime(DateTime dt) {
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
