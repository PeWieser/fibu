import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/file_viewer_service.dart';
import '../../../core/services/rclone_provider.dart';
import '../../../core/services/rclone_service.dart';
import '../../../core/services/remote_registry_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ios_haptics.dart';
import '../../../theme/theme.dart';

/// Wurzelordner der Sicherung im Laufwerk.
const String kFibuBackupRoot = 'fibu-backup';

/// Unterordner, in dem die Mediathek gespiegelt wird:
/// `fibu-backup/Photos/<Album>/<Datei>`.
const String kFibuPhotosRoot = '$kFibuBackupRoot/Photos';

/// Ein Album = ein Ordner unter [kFibuPhotosRoot].
class _Album {
  final String name;
  final String path;
  int count;
  int bytes;
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
      await _loadAlbums();
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

  Future<void> _openPhoto(_Photo photo) async {
    final remote = _remote;
    if (remote == null) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) IosHaptics.light();
    setState(() => _openingPath = photo.path);
    final ok = await ref.read(fileViewerServiceProvider).openInDefaultApp(
          remoteName: remote,
          remotePath: photo.path,
          fileName: photo.name,
        );
    if (!mounted) return;
    setState(() => _openingPath = null);
    if (!ok) {
      setState(() => _error = ref.read(stringsProvider).previewLoadFailed);
    }
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

    return ListView.builder(
      padding: EdgeInsets.only(bottom: theme.xl),
      itemCount: keys.length,
      itemBuilder: (context, gi) {
        final key = keys[gi];
        final items = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: gi == 0 ? 0 : theme.lg, bottom: theme.sm),
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
                crossAxisCount: 3,
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
  }

  Widget _photoTile(_Photo photo, AppThemeData theme, AppStrings strings) {
    final isOpening = _openingPath == photo.path;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isOpening ? null : () => _openPhoto(photo),
        child: Container(
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
        ),
      ),
    );
  }
}
