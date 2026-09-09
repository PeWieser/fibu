import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/services/thumbnail_creator.dart';
import '../../../core/services/thumbnail_pipeline.dart';
import '../../../core/services/thumbnail_service.dart';
import '../../../core/utils/app_paths.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/theme.dart';
import 'cloud_photo_viewer.dart';
import 'widgets/thumb_image.dart';

/// Wurzelordner der Sicherung im Laufwerk.
const String kFibuBackupRoot = 'fibu-backup';

/// Unterordner, in dem die Mediathek gespiegelt wird:
/// `fibu-backup/Photos/<Album>/<Datei>`.
const String kFibuPhotosRoot = '$kFibuBackupRoot/Photos';

/// Ein Album = ein Ordner unter [kFibuPhotosRoot].
class _Album {
  final String name;
  final String path;

  // Feldinitialisierung statt Konstruktorparameter: Die Werte werden erst
  // nach der Auflistung des Albums gesetzt.
  int count = 0;
  int bytes = 0;
  DateTime? newest;

  _Album({required this.name, required this.path});
}

/// Eine Datei in der Cloud.
class _Photo {
  final String name;
  final String path;
  final int size;
  final DateTime? modified;

  const _Photo({
    required this.name,
    required this.path,
    required this.size,
    this.modified,
  });
}

/// Cloud-Fotos — ein schlanker Fotos-Manager statt eines Dateiexplorers.
///
/// Zeigt die gesicherte Mediathek so, wie sie der Nutzer kennt: als Alben und
/// als nach Datum sortierte Aufnahmen. Die Ordnerstruktur der Sicherung
/// (`fibu-backup/Photos/<Album>/…`) ist dabei nur die Datenquelle, nicht die
/// Darstellung.
///
/// **Bewusste Grenze: keine Vorschaubilder.** Ein Miniaturbild müsste pro
/// Datei aus der Cloud geladen werden — bei einer Mediathek mit mehreren
/// tausend Aufnahmen wäre das ein Datenvolumen, das niemand erwarten würde,
/// und generische Backends (WebDAV, S3, SFTP) liefern keine serverseitigen
/// Thumbnails. Die Kachel zeigt deshalb Name und Größe; Antippen lädt die
/// Datei und öffnet sie mit dem Systembetrachter (Quick Look auf iOS).
class CloudPhotosScreen extends ConsumerStatefulWidget {
  final String? initialRemote;

  const CloudPhotosScreen({super.key, this.initialRemote});

  @override
  ConsumerState<CloudPhotosScreen> createState() => _CloudPhotosScreenState();
}

enum _PhotosView { albums, recent }

class _CloudPhotosScreenState extends ConsumerState<CloudPhotosScreen> {
  String? _remote;
  _PhotosView _view = _PhotosView.albums;

  bool _loading = false;
  String? _error;
  List<_Album> _albums = [];

  /// Geöffnetes Album; null = Übersicht.
  String? _openAlbumPath;
  List<_Photo> _albumPhotos = [];

  /// „Zuletzt"-Ansicht: alle Aufnahmen über alle Alben, nach Datum.
  List<_Photo> _recent = [];
  bool _loadingRecent = false;

  /// Datei, die gerade geladen/geöffnet wird — für den Kachel-Spinner.
  String? _openingPath;

  /// Spiegel-Pfad → Asset-ID bzw. absoluter Pfad (Windows). Einmal geladen,
  /// damit die Kacheln nicht jede für sich die Spiegel-Zustände lesen.
  Map<String, String> _assetIds = const {};

  /// Aufnahmen ohne Vorschaubild in der Cloud — für den Hinweis.
  List<String> _missingThumbs = const [];
  bool _thumbsDismissed = false;
  bool _creatingThumbs = false;
  int _thumbsDone = 0;
  int _thumbsTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remote = widget.initialRemote;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      final remotes = await ref.read(remotesProvider.future);
      if (!mounted) return;
      if (remotes.isEmpty) {
        setState(() => _error = ref.read(stringsProvider).noDrivesConfigured);
        return;
      }
      setState(() => _remote ??= remotes.first);
      _assetIds = await LocalMediaResolver.loadAssetIds();
      await _loadAlbums();
      await _refreshMissingThumbs();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _loadAlbums() async {
    final remote = _remote;
    if (remote == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _openAlbumPath = null;
    });
    try {
      final service = ref.read(rcloneServiceProvider);
      final entries = await service.listFiles(remote, kFibuPhotosRoot);
      final dirs = entries.where((e) => e.isDir).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Zählung je Album parallel — bei Dutzenden Alben sonst spürbar zäh.
      final albums = <_Album>[];
      await Future.wait(dirs.map((d) async {
        final path = '$kFibuPhotosRoot/${d.name}';
        final album = _Album(name: d.name, path: path);
        try {
          final files = _photosOf(await service.listFiles(remote, path), path);
          album.count = files.length;
          album.bytes = files.fold<int>(0, (s, p) => s + p.size);
          for (final p in files) {
            if (p.modified != null &&
                (album.newest == null || p.modified!.isAfter(album.newest!))) {
              album.newest = p.modified;
            }
          }
        } catch (_) {
          // Ein nicht lesbares Album blendet die Übersicht nicht aus.
        }
        albums.add(album);
      }));
      albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _albums = albums;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Spiegel-Pfad aus dem Cloud-Pfad: `fibu-backup/Photos/A/x.jpg` →
  /// `Photos/A/x.jpg`. Daraus wird der Name des Vorschaubilds, und das ist
  /// der Schlüssel in `mirror_state.json`.
  String _relOf(String cloudPath) {
    const prefix = '$kFibuBackupRoot/';
    return cloudPath.startsWith(prefix)
        ? cloudPath.substring(prefix.length)
        : cloudPath;
  }

  /// Zählt, für welche Aufnahmen das Vorschaubild in der Cloud fehlt.
  ///
  /// Lokal vorhandene Aufnahmen zählen mit — ihr Vorschaubild entsteht aus
  /// der lokalen Datei und muss für die anderen Geräte trotzdem hoch.
  Future<void> _refreshMissingThumbs() async {
    final remote = _remote;
    if (remote == null) return;
    try {
      final service = ref.read(rcloneServiceProvider);
      final cloudThumbs =
          await ThumbnailPipeline.listCloudThumbs(service, remote);
      final rels = <String>[];
      await _collectRels(remote, kFibuPhotosRoot, rels);
      final missing = await ThumbnailService.backfillList(
        rels: rels,
        cloudFileNames: cloudThumbs,
        // Bewusst immer false: Auch lokal vorhandene Aufnahmen brauchen ihr
        // Vorschaubild in der Cloud — für die anderen Geräte.
        existsLocally: (rel) => false,
      );
      if (!mounted) return;
      setState(() => _missingThumbs = missing.map((e) => e.rel).toList());
    } catch (e) {
      AppLog.warn('thumbs', 'Vorschaubild-Bestand nicht lesbar: $e');
    }
  }

  Future<void> _collectRels(
      String remote, String path, List<String> out) async {
    final entries = await ref.read(rcloneServiceProvider).listFiles(remote, path);
    for (final entry in entries) {
      if (entry.isDir) {
        await _collectRels(remote, '$path/${entry.name}', out);
      } else {
        out.add(_relOf('$path/${entry.name}'));
      }
    }
  }

  /// Vorschaubilder erzeugen und hochladen. Mit Fortschritt und Abbruch.
  Future<void> _createThumbnails() async {
    final remote = _remote;
    if (remote == null || _creatingThumbs || _missingThumbs.isEmpty) return;
    setState(() {
      _creatingThumbs = true;
      _thumbsDone = 0;
      _thumbsTotal = _missingThumbs.length;
    });
    try {
      final support = await appSupportRoot();
      final cache = ThumbnailCache(Directory('${support.path}/thumb_cache'));
      final service = ref.read(rcloneServiceProvider);
      final rels = List<String>.from(_missingThumbs);
      await ThumbnailPipeline.run(
        rclone: service,
        remoteName: remote,
        rels: rels,
        cache: cache,
        createFor: (rel) async {
          // 1) lokale Aufnahme — der billige Weg
          final assetId = _assetIds[rel];
          if (assetId != null && assetId.isNotEmpty) {
            final local = await LocalMediaResolver.create(assetId: assetId);
            if (local != null) return local;
          }
          // 2) nur in der Cloud: Original holen, Vorschaubild bauen
          final tmp = File('${support.path}/backfill_${rel.hashCode}.tmp');
          try {
            await service.downloadFile(
                remote, '$kFibuBackupRoot/$rel', tmp.path);
            return await ThumbnailCreator.fromFile(tmp);
          } catch (_) {
            return null;
          } finally {
            try {
              if (await tmp.exists()) await tmp.delete();
            } catch (_) {}
          }
        },
        onProgress: (done, total) {
          if (mounted) setState(() => _thumbsDone = done);
        },
      );
      await _refreshMissingThumbs();
    } catch (e) {
      AppLog.warn('thumbs', 'Vorschaubilder nicht erzeugt: $e');
    } finally {
      if (mounted) setState(() => _creatingThumbs = false);
    }
  }

  Future<void> _openAlbum(_Album album) async {
    final remote = _remote;
    if (remote == null) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.selection();
    setState(() {
      _openAlbumPath = album.path;
      _albumPhotos = [];
      _loading = true;
    });
    try {
      final files = _photosOf(
          await ref.read(rcloneServiceProvider).listFiles(remote, album.path),
          album.path);
      if (!mounted) return;
      setState(() {
        _albumPhotos = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadRecent() async {
    final remote = _remote;
    if (remote == null || _loadingRecent) return;
    setState(() {
      _loadingRecent = true;
      _error = null;
    });
    try {
      final service = ref.read(rcloneServiceProvider);
      final all = <_Photo>[];
      await Future.wait(_albums.map((a) async {
        try {
          all.addAll(_photosOf(
              await service.listFiles(remote, a.path), a.path));
        } catch (_) {}
      }));
      if (!mounted) return;
      setState(() {
        _recent = all;
        _loadingRecent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRecent = false;
        _error = '$e';
      });
    }
  }

  /// Macht aus einer rclone-Auflistung sortierte Aufnahmen.
  ///
  /// Sortierung: neueste zuerst. Dateien ohne lesbare Änderungszeit landen
  /// am Ende — besser sichtbar „unten" als fälschlich „ganz neu" oben.
  static List<_Photo> _photosOf(List<RcloneFileInfo> files, String basePath) {
    final out = <_Photo>[];
    for (final f in files) {
      if (f.isDir) continue;
      if (f.name.startsWith('.')) continue; // Papierkorb, Manifest, Zustände
      out.add(_Photo(
        name: f.name,
        path: basePath.isEmpty ? f.name : '$basePath/${f.name}',
        size: f.size,
        modified: DateTime.tryParse(f.modTime),
      ));
    }
    out.sort((a, b) {
      final am = a.modified;
      final bm = b.modified;
      if (am == null && bm == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (am == null) return 1;
      if (bm == null) return -1;
      return bm.compareTo(am);
    });
    return out;
  }

  /// Öffnet die Vollbild-Ansicht mit allen Aufnahmen der aktuellen Liste.
  ///
  /// Liegt die Aufnahme lokal, zeigt die Ansicht sie ohne Download
  /// (`CloudPhotoViewer`, §2.1) — „In Standard-App öffnen" bleibt dort als
  /// Aktion für Formate, die Flutter nicht darstellen kann.
  void _openPhoto(_Photo photo) {
    final remote = _remote;
    if (remote == null) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.light();

    final photos = (_openAlbumPath != null ? _albumPhotos : _recent);
    final list = photos.isEmpty ? [photo] : photos;
    final index = list.indexWhere((p) => p.path == photo.path);
    AppNav.push(
      context,
      CloudPhotoViewer(
        remote: remote,
        initialIndex: index < 0 ? 0 : index,
        assetIds: _assetIds,
        photos: [
          for (final p in list)
            ViewerPhoto(
              name: p.name,
              cloudPath: p.path,
              rel: _relOf(p.path),
              size: p.size,
              modified: p.modified,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aufbau
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;
    final remotes = ref.watch(remotesProvider).valueOrNull ?? const <String>[];

    final content = _error != null
        ? _message(strings.error, _error!, theme)
        : (_loading
            ? _spinner(theme, platform)
            : (_openAlbumPath != null
                ? _photoGrid(_albumPhotos, theme, strings, platform)
                : (_view == _PhotosView.albums
                    ? _albumsGrid(theme, strings, platform)
                    : (_loadingRecent
                        ? _spinner(theme, platform)
                        : _recentList(theme, strings, platform)))));

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (remotes.length > 1) _remotePicker(remotes, theme, strings, platform),
        if (_openAlbumPath == null)
          _segmented(theme, strings, platform)
        else
          _backRow(theme, strings, platform),
        if (_missingThumbs.isNotEmpty && !_thumbsDismissed) ...[
          SizedBox(height: theme.md),
          _thumbsBanner(theme, strings),
        ],
        SizedBox(height: theme.md),
      ],
    );

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(_titleFor(strings)),
          previousPageTitle: strings.back,
          backgroundColor: theme.surface,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, Expanded(child: content)],
            ),
          ),
        ),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(_titleFor(strings)),
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
        content: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, Expanded(child: content)],
          ),
        ),
      );
    }
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(title: Text(_titleFor(strings))),
      body: Padding(
        padding: EdgeInsets.fromLTRB(theme.lg, theme.md, theme.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, Expanded(child: content)],
        ),
      ),
    );
  }

  String _titleFor(AppStrings strings) {
    if (_openAlbumPath != null) {
      final album = _albums.firstWhere((a) => a.path == _openAlbumPath,
          orElse: () => _Album(name: '', path: ''));
      return album.name.isEmpty ? strings.cloudPhotosTitle : album.name;
    }
    return strings.cloudPhotosTitle;
  }

  Widget _message(String label, String body, AppThemeData theme) => Center(
        child: Padding(
          padding: EdgeInsets.all(theme.xl),
          child: Text(
            '$label: $body',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: 14, height: 1.4),
          ),
        ),
      );

  Widget _spinner(AppThemeData theme, TargetPlatform platform) => Center(
        child: platform == TargetPlatform.iOS
            ? const cupertino.CupertinoActivityIndicator(radius: 14)
            : (platform == TargetPlatform.windows
                ? const fluent.ProgressRing()
                : const material.CircularProgressIndicator()),
      );

  Widget _remotePicker(
      List<String> remotes, AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.md),
      child: Row(
        children: [
          for (final id in remotes)
            Padding(
              padding: EdgeInsets.only(right: theme.sm),
              child: _chip(
                label: ref.watch(remoteDisplayNameProvider(id)),
                selected: id == _remote,
                theme: theme,
                onTap: () {
                  if (id == _remote) return;
                  setState(() {
                    _remote = id;
                    _recent = [];
                  });
                  _loadAlbums();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required AppThemeData theme,
    required VoidCallback onTap,
  }) {
    final fg = selected ? theme.accentText : theme.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: EdgeInsets.symmetric(horizontal: theme.md, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? theme.accent : theme.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: Text(label,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _segmented(AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    final items = <String>[strings.cloudPhotosAlbums, strings.cloudPhotosRecent];
    final index = _view == _PhotosView.albums ? 0 : 1;
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoSlidingSegmentedControl<int>(
        groupValue: index,
        children: {
          for (var i = 0; i < items.length; i++)
            i: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.sm),
              child: Text(items[i], style: const TextStyle(fontSize: 13)),
            ),
        },
        onValueChanged: (v) {
          if (v == null) return;
          setState(() => _view = v == 0 ? _PhotosView.albums : _PhotosView.recent);
          if (_view == _PhotosView.recent && _recent.isEmpty) _loadRecent();
        },
      );
    }
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(right: theme.sm),
            child: _chip(
              label: items[i],
              selected: index == i,
              theme: theme,
              onTap: () {
                setState(() => _view = i == 0 ? _PhotosView.albums : _PhotosView.recent);
                if (_view == _PhotosView.recent && _recent.isEmpty) _loadRecent();
              },
            ),
          ),
      ],
    );
  }

  Widget _backRow(AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.selection();
            setState(() => _openAlbumPath = null);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  platform == TargetPlatform.windows
                      ? fluent.FluentIcons.chevron_left
                      : (platform == TargetPlatform.iOS
                          ? cupertino.CupertinoIcons.chevron_left
                          : material.Icons.arrow_back),
                  size: 18,
                  color: theme.accent,
                ),
                SizedBox(width: theme.xs),
                Text(strings.cloudPhotosAlbums,
                    style: TextStyle(color: theme.accent, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Alben ---------------------------------------------------------------

  Widget _albumsGrid(AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    if (_albums.isEmpty) {
      return _message(
          strings.cloudPhotosEmptyTitle, strings.cloudPhotosEmptyBody, theme);
    }
    return LayoutBuilder(builder: (context, constraints) {
      const cross = 2;
      final gap = theme.sm.toDouble();
      final tile = (constraints.maxWidth - gap * (cross - 1)) / cross;
      return GridView.builder(
        padding: EdgeInsets.only(bottom: theme.xl),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: tile > 0 ? (tile / (tile * 0.82)) : 1.0,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, i) {
          final album = _albums[i];
          return _albumTile(album, theme, strings);
        },
      );
    });
  }

  Widget _albumTile(_Album album, AppThemeData theme, AppStrings strings) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openAlbum(album),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(theme.radiusLg),
                ),
                child: Center(
                  child: Icon(
                    defaultTargetPlatform == TargetPlatform.windows
                        ? fluent.FluentIcons.photo2
                        : (defaultTargetPlatform == TargetPlatform.iOS
                            ? cupertino.CupertinoIcons.photo_on_rectangle
                            : material.Icons.photo_library_outlined),
                    size: 32,
                    color: theme.accent,
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.xs),
            Text(album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              album.count > 0
                  ? '${strings.cloudPhotosCount(album.count)} · ${formatBytes(album.bytes)}'
                  : strings.cloudPhotosEmptyShort,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // --- „Zuletzt" -----------------------------------------------------------

  Widget _recentList(AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    if (_recent.isEmpty) {
      return _message(
          strings.cloudPhotosEmptyTitle, strings.cloudPhotosEmptyBody, theme);
    }
    return _groupedByDay(_recent, theme, strings, platform);
  }

  Widget _photoGrid(
      List<_Photo> photos, AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    if (photos.isEmpty) {
      return _message(
          strings.cloudPhotosEmptyTitle, strings.cloudPhotosEmptyBody, theme);
    }
    return _groupedByDay(photos, theme, strings, platform);
  }

  /// Nach Tag gruppierte Liste, neuester Tag zuerst.
  Widget _groupedByDay(List<_Photo> photos, AppThemeData theme,
      AppStrings strings, TargetPlatform platform) {
    final groups = <DateTime, List<_Photo>>{};
    for (final p in photos) {
      final m = p.modified;
      // Ohne Änderungszeit in einen eigenen Sammel-Tag — nicht unterschlagen.
      final key = m != null ? DateTime(m.year, m.month, m.day) : DateTime(0);
      groups.putIfAbsent(key, () => []).add(p);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Spalten nach verfügbarer Breite statt nach Plattform: Drei Spalten sind
    // auf einem Telefon richtig und auf einem Fenster zu grob.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        return ListView.builder(
          padding: EdgeInsets.only(bottom: theme.xl),
          itemCount: keys.length,
          itemBuilder: (context, gi) {
            final key = keys[gi];
            final items = groups[key]!;
            // Monats-Trenner, wenn der Monat wechselt — wie in der Fotos-App.
            final previous = gi == 0 ? null : keys[gi - 1];
            final newMonth = key != DateTime(0) &&
                (previous == null ||
                    previous.year != key.year ||
                    previous.month != key.month);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (newMonth)
                  Padding(
                    padding: EdgeInsets.only(top: gi == 0 ? 0 : theme.lg, bottom: theme.xs),
                    child: Text(
                      strings.cloudPhotosMonthLabel(key),
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: newMonth ? 0 : (gi == 0 ? 0 : theme.lg), bottom: theme.sm),
                  child: Text(
                    key == DateTime(0)
                        ? strings.cloudPhotosUnknownDate
                        : strings.cloudPhotosDayLabel(key),
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: theme.xs,
                    mainAxisSpacing: theme.xs,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _photoTile(items[i], theme, strings),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hinweis, dass Vorschaubilder fehlen — mit Knopf, nicht automatisch.
  ///
  /// Der Nutzer entscheidet, wann Datenvolumen fließt. Der Hinweis steht
  /// dort, wo der Mangel sichtbar wird.
  Widget _thumbsBanner(AppThemeData theme, AppStrings strings) {
    return Container(
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _creatingThumbs
                ? '${strings.thumbsCreating} $_thumbsDone/$_thumbsTotal'
                : strings.thumbsMissing(_missingThumbs.length),
            style: TextStyle(
                color: theme.textPrimary, fontSize: 13, height: 1.35),
          ),
          SizedBox(height: theme.sm),
          Row(
            children: [
              if (_creatingThumbs)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: material.CircularProgressIndicator(strokeWidth: 2))
              else ...[
                material.TextButton(
                  onPressed: _createThumbnails,
                  child: Text(strings.thumbsCreate),
                ),
                SizedBox(width: theme.sm),
                material.TextButton(
                  onPressed: () => setState(() => _thumbsDismissed = true),
                  child: Text(strings.thumbsLater),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Spaltenzahl nach Breite — Telefon 3, Tablet 4–5, Fenster 6.
  static int _columnCount(double width) {
    if (width >= 1100) return 6;
    if (width >= 800) return 5;
    if (width >= 520) return 4;
    return 3;
  }

  Widget _photoTile(_Photo photo, AppThemeData theme, AppStrings strings) {
    final isOpening = _openingPath == photo.path;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isOpening ? null : () => _openPhoto(photo),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusSm),
          // Vorschaubild, sobald es da ist — lokal vor Cloud (§2.1). Bis
          // dahin und ohne Vorschaubild bleibt die Dateikachel.
          child: ThumbImage(
            remote: _remote ?? '',
            cloudPath: photo.path,
            rel: _relOf(photo.path),
            assetIds: _assetIds,
            fallback: _fileTile(photo, theme, strings, isOpening),
          ),
        ),
      ),
    );
  }

  /// Dateikachel: Name und Größe — der Zustand ohne Vorschaubild.
  Widget _fileTile(
      _Photo photo, AppThemeData theme, AppStrings strings, bool isOpening) {
    return Container(
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          padding: EdgeInsets.all(theme.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isOpening)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: defaultTargetPlatform == TargetPlatform.iOS
                      ? const cupertino.CupertinoActivityIndicator(radius: 9)
                      : (defaultTargetPlatform == TargetPlatform.windows
                          ? const fluent.ProgressRing(strokeWidth: 2)
                          : const material.CircularProgressIndicator(
                              strokeWidth: 2)),
                )
              else
                Icon(
                  defaultTargetPlatform == TargetPlatform.windows
                      ? fluent.FluentIcons.file_image
                      : (defaultTargetPlatform == TargetPlatform.iOS
                          ? cupertino.CupertinoIcons.photo
                          : material.Icons.photo_library_outlined),
                  size: 22,
                  color: theme.accent,
                ),
              SizedBox(height: theme.xs),
              Text(photo.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textPrimary, fontSize: 10)),
              Text(formatBytes(photo.size),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textSecondary, fontSize: 9)),
            ],
          ),
        );
  }
}
