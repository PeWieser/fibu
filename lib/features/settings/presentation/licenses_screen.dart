import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../theme/theme.dart';

/// Open-Source-Lizenzen als übersichtlich strukturierte Seite:
///
///  1. Eine kurze, professionelle Einordnung,
///  2. die Kernkomponenten (rclone, gomobile, Flutter) mit Beschreibung,
///  3. die Liste aller weiteren Bibliotheken.
///
/// Jede Komponente öffnet per Tap ihren vollständigen Lizenztext in einer
/// eigenen Detailansicht — statt alles in einer langen Liste zu versenken.
class LicensesScreen extends ConsumerStatefulWidget {
  const LicensesScreen({super.key});

  @override
  ConsumerState<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicenseSection {
  final String title;
  final String body;
  const _LicenseSection(this.title, this.body);
}

class _LicensesScreenState extends ConsumerState<LicensesScreen> {
  List<_LicenseSection>? _sections;

  static const _pinned = ['rclone / librclone', 'golang.org/x/mobile (gomobile)'];

  @override
  void initState() {
    super.initState();
    _collect();
  }

  Future<void> _collect() async {
    // LicenseRegistry liefert einen Stream einzelner Einträge; wir gruppieren
    // nach Paketname.
    final byPackage = <String, StringBuffer>{};
    await for (final entry in LicenseRegistry.licenses) {
      final key = entry.packages.join(', ');
      final buffer = byPackage.putIfAbsent(key, StringBuffer.new);
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(entry.paragraphs.map((p) => p.text).join('\n'));
    }

    // Die eigenen Kern-Komponenten zuerst, danach alphabetisch.
    final keys = byPackage.keys.toList()
      ..sort((a, b) {
        final pa = _pinned.indexOf(a);
        final pb = _pinned.indexOf(b);
        if (pa >= 0 || pb >= 0) {
          return (pa >= 0 ? pa : _pinned.length)
              .compareTo(pb >= 0 ? pb : _pinned.length);
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    if (!mounted) return;
    setState(() {
      _sections = [
        for (final k in keys) _LicenseSection(k, byPackage[k]!.toString()),
      ];
    });
  }

  /// Ermittelt eine kurze Lizenz-Kennung (Badge) aus dem Lizenztext.
  String _licenseBadge(String body) {
    final text = body.toLowerCase();
    if (text.contains('mit license') ||
        text.contains('permission is hereby granted, free of charge')) {
      return 'MIT';
    }
    if (text.contains('apache license')) return 'Apache 2.0';
    if (text.contains('bsd 3-clause') ||
        text.contains('redistribution and use in source and binary forms')) {
      return 'BSD';
    }
    if (text.contains('isc license')) return 'ISC';
    if (text.contains('mozilla public license')) return 'MPL';
    if (text.contains('gnu general public license')) return 'GPL';
    if (text.contains('gnu lesser general public license')) return 'LGPL';
    return isGermanUi ? 'Lizenz' : 'License';
  }

  bool get isGermanUi => ref.read(stringsProvider).isGerman;

  /// Beschreibungstext für die wichtigsten Kernkomponenten.
  String? _coreDescription(String title, AppStrings strings) {
    final lower = title.toLowerCase();
    if (lower.contains('rclone')) return strings.licensesRcloneDescription;
    if (lower.contains('gomobile') || lower.contains('golang.org/x/mobile')) {
      return strings.licensesGomobileDescription;
    }
    if (lower.contains('flutter')) return strings.licensesFlutterDescription;
    return null;
  }

  bool _isCoreComponent(String title) =>
      _coreDescription(title, ref.read(stringsProvider)) != null;

  void _openDetail(_LicenseSection section, AppStrings strings) {
    final platform = defaultTargetPlatform;
    final route = platform == TargetPlatform.windows
        ? fluent.FluentPageRoute(
            builder: (_) => _LicenseDetailScreen(section: section))
        : (platform == TargetPlatform.iOS
            ? cupertino.CupertinoPageRoute(
                builder: (_) => _LicenseDetailScreen(section: section))
            : material.MaterialPageRoute(
                builder: (_) => _LicenseDetailScreen(section: section)));
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    // Theme live verfolgen, damit Dark-/Light-/Palettenwechsel sofort greift.
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;

    final body = _sections == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (platform == TargetPlatform.iOS)
                  const cupertino.CupertinoActivityIndicator(radius: 14)
                else if (platform == TargetPlatform.windows)
                  const fluent.ProgressRing()
                else
                  const material.CircularProgressIndicator(),
                SizedBox(height: theme.md),
                Text(strings.licensesLoading,
                    style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              ],
            ),
          )
        : _document(theme, strings, platform);

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.openSourceLicenses),
          previousPageTitle: strings.back,
          backgroundColor: theme.surface,
        ),
        child: SafeArea(child: body),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(title: fluent.Text(strings.openSourceLicenses)),
        content: body,
      );
    }
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        title: Text(strings.openSourceLicenses),
        backgroundColor: theme.surface,
        elevation: 0,
      ),
      body: body,
    );
  }

  /// Strukturierte Übersicht: Einordnung, Kernkomponenten, alle Bibliotheken.
  Widget _document(AppThemeData theme, AppStrings strings, TargetPlatform platform) {
    final sections = _sections!;
    final core = sections.where((s) => _isCoreComponent(s.title)).toList();
    final rest = sections.where((s) => !_isCoreComponent(s.title)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: EdgeInsets.all(theme.lg),
          children: [
            // 1. Einordnung
            Text(
              strings.licensesIntro,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            SizedBox(height: theme.xl),

            // 2. Kernkomponenten
            _sectionHeader(strings.licensesCoreComponents, theme),
            for (final section in core)
              _componentCard(theme, strings, platform, section,
                  description: _coreDescription(section.title, strings)),
            SizedBox(height: theme.xl),

            // 3. Alle weiteren Bibliotheken
            _sectionHeader(strings.licensesAllPackages, theme),
            Padding(
              padding: EdgeInsets.only(bottom: theme.sm),
              child: Text(
                strings.licensesPackageListHint,
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
            ),
            for (final section in rest)
              _componentCard(theme, strings, platform, section),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.sm),
      child: Text(
        title,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Eine Komponenten-Zeile: Name, ggf. Beschreibung, Lizenz-Badge.
  /// Tap öffnet den vollständigen Lizenztext.
  Widget _componentCard(
    AppThemeData theme,
    AppStrings strings,
    TargetPlatform platform,
    _LicenseSection section, {
    String? description,
  }) {
    final badge = _licenseBadge(section.body);

    final badgeWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: theme.sm, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Text(
        badge,
        style: TextStyle(
          color: theme.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (description != null) ...[
                SizedBox(height: theme.xs),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: theme.md),
        badgeWidget,
      ],
    );

    final onTap = () => _openDetail(section, strings);

    if (platform == TargetPlatform.iOS) {
      return Padding(
        padding: EdgeInsets.only(bottom: theme.sm),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(theme.md),
            decoration: BoxDecoration(
              color: cupertino.CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(theme.radiusLg),
              border: Border.all(
                color: cupertino.CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: content),
                SizedBox(width: theme.sm),
                Icon(
                  cupertino.CupertinoIcons.chevron_forward,
                  size: 14,
                  color: theme.textSecondary,
                  semanticLabel: strings.licensesDetailTitle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (platform == TargetPlatform.windows) {
      return Padding(
        padding: EdgeInsets.only(bottom: theme.sm),
        child: fluent.Card(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(child: content),
                    SizedBox(width: theme.sm),
                    Icon(fluent.FluentIcons.chevron_right,
                        size: 12, color: theme.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: theme.sm),
      child: material.Card(
        elevation: 0,
        color: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radiusLg),
          side: BorderSide(
            color: theme.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: material.InkWell(
          borderRadius: BorderRadius.circular(theme.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(theme.md),
            child: Row(
              children: [
                Expanded(child: content),
                SizedBox(width: theme.sm),
                Icon(material.Icons.chevron_right,
                    size: 16, color: theme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detailansicht mit dem vollständigen Lizenztext einer Komponente.
class _LicenseDetailScreen extends ConsumerWidget {
  final _LicenseSection section;

  const _LicenseDetailScreen({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;

    final content = ListView(
      padding: EdgeInsets.all(theme.lg),
      children: [
        Text(
          section.title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        SizedBox(height: theme.lg),
        Text(
          section.body,
          style: TextStyle(
            color: theme.textSecondary,
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Courier'],
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.licensesDetailTitle),
          previousPageTitle: strings.back,
          backgroundColor: theme.surface,
        ),
        child: SafeArea(child: content),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.licensesDetailTitle),
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
        title: Text(strings.licensesDetailTitle),
        backgroundColor: theme.surface,
        elevation: 0,
      ),
      body: content,
    );
  }
}
