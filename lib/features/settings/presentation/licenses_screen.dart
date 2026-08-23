import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../theme/theme.dart';

/// Alle Open-Source-Lizenzen als EIN ruhiges, durchscrollbares Dokument —
/// statt der verwirrenden Paket-Master-Detail-Liste der Standard-LicensePage.
/// Oben eine freundliche Einordnung, darunter die vollständigen Texte.
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

  @override
  void initState() {
    super.initState();
    _collect();
  }

  Future<void> _collect() async {
    // LicenseRegistry liefert einen Stream einzelner Einträge; wir gruppieren
    // nach Paketname zu einem einzigen Dokument.
    final byPackage = <String, StringBuffer>{};
    await for (final entry in LicenseRegistry.licenses) {
      final key = entry.packages.join(', ');
      final buffer = byPackage.putIfAbsent(key, StringBuffer.new);
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(entry.paragraphs.map((p) => p.text).join('\n'));
    }

    // Die eigenen Kern-Komponenten zuerst, danach alphabetisch.
    const pinned = ['rclone / librclone', 'golang.org/x/mobile (gomobile)'];
    final keys = byPackage.keys.toList()
      ..sort((a, b) {
        final pa = pinned.indexOf(a);
        final pb = pinned.indexOf(b);
        if (pa >= 0 || pb >= 0) {
          return (pa >= 0 ? pa : pinned.length)
              .compareTo(pb >= 0 ? pb : pinned.length);
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

  @override
  Widget build(BuildContext context) {
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
        : _document(theme, strings);

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.openSourceLicenses),
          previousPageTitle: strings.back,
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
      appBar: material.AppBar(title: Text(strings.openSourceLicenses)),
      body: body,
    );
  }

  /// EIN Dokument: Intro, dann Abschnitt je Komponente (Name + Lizenztext).
  Widget _document(AppThemeData theme, AppStrings strings) {
    final sections = _sections!;
    // Breite auf iPad/Desktop begrenzen — lange Zeilen lesen sich schlecht.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.builder(
          padding: EdgeInsets.all(theme.lg),
          // +1 für die Einleitung ganz oben.
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: theme.xl),
                child: Text(
                  strings.licensesIntro,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              );
            }
            final section = sections[index - 1];
            return Padding(
              padding: EdgeInsets.only(bottom: theme.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: theme.xs),
                  Text(
                    section.body,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
