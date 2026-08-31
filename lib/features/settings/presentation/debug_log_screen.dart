import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_log_service.dart';
import '../../../theme/theme.dart';

/// Diagnose-Protokoll: zeigt alle App-Aktionen (Engine, Netzwerk, Sync,
/// Medien-Staging, Remotes) mit Zeitstempel und Schweregrad.
/// Für Troubleshooting: Einträge können komplett in die Zwischenablage
/// kopiert werden.
class DebugLogScreen extends ConsumerWidget {
  const DebugLogScreen({super.key});

  Future<void> _copyAll(
      BuildContext context, WidgetRef ref, AppStrings strings) async {
    final entries = ref.read(appLogProvider);
    await Clipboard.setData(ClipboardData(text: AppLog.exportAll(entries)));
    if (!context.mounted) return;

    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 50,
          left: 20,
          right: 20,
          child: SafeArea(
            child: cupertino.CupertinoPopupSurface(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  strings.pathCopied,
                  style: cupertino.CupertinoTheme.of(context)
                      .textTheme
                      .textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2), () {
        if (entry.mounted) entry.remove();
      });
    } else {
      material.ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        material.SnackBar(
          content: Text(strings.pathCopied),
          duration: const Duration(seconds: 2),
          behavior: material.SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Fußzeile mit Pfad zur persistenten Logdatei (privater App-Support-Ordner).
  Widget _fileFooter(AppThemeData theme, AppStrings strings) {
    final path = AppLog.logFilePath;
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(theme.md, theme.xs, theme.md, theme.md),
      child: Text(
        strings.debugLogFileLocation(path),
        style: TextStyle(color: theme.textSecondary, fontSize: 11, height: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme live verfolgen, damit Dark-/Light-/Palettenwechsel sofort greift.
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final entries = ref.watch(appLogProvider);
    final platform = defaultTargetPlatform;

    Widget entryTile(AppLogEntry entry) {
      final color = switch (entry.level) {
        AppLogLevel.error => theme.error,
        AppLogLevel.warning => theme.warning,
        AppLogLevel.info => theme.textPrimary,
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          entry.format(),
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: color,
          ),
        ),
      );
    }

    final Widget body = entries.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(theme.xl),
              child: Text(
                strings.debugLogEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 14),
              ),
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.all(theme.md),
            itemCount: entries.length,
            itemBuilder: (context, index) => entryTile(entries[index]),
          );

    final Widget withFooter = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        _fileFooter(theme, strings),
      ],
    );

    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.debugLogTitle),
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
          commandBar: fluent.CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            primaryItems: [
              fluent.CommandBarButton(
                icon: const Icon(fluent.FluentIcons.copy, size: 16, semanticLabel: 'Copy'),
                label: Text(strings.copy),
                onPressed: () => _copyAll(context, ref, strings),
              ),
              fluent.CommandBarButton(
                icon: Icon(fluent.FluentIcons.delete, size: 16, semanticLabel: strings.clearLog),
                label: Text(strings.clearLog),
                onPressed: () =>
                    ref.read(appLogProvider.notifier).clear(),
              ),
            ],
          ),
        ),
        content: withFooter,
      );
    }

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          backgroundColor: theme.surface,
          middle: Text(strings.debugLogTitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              cupertino.CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(cupertino.CupertinoIcons.doc_on_clipboard,
                    semanticLabel: 'Copy all'),
                onPressed: () => _copyAll(context, ref, strings),
              ),
              SizedBox(width: theme.sm),
              cupertino.CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(cupertino.CupertinoIcons.delete,
                    semanticLabel: 'Clear log'),
                onPressed: () => ref.read(appLogProvider.notifier).clear(),
              ),
            ],
          ),
        ),
        child: SafeArea(child: withFooter),
      );
    }

    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(
        title: Text(strings.debugLogTitle),
        actions: [
          material.IconButton(
            icon: const Icon(material.Icons.copy_all),
            tooltip: strings.copy,
            onPressed: () => _copyAll(context, ref, strings),
          ),
          material.IconButton(
            icon: const Icon(material.Icons.delete_outline),
            tooltip: strings.clearLog,
            onPressed: () => ref.read(appLogProvider.notifier).clear(),
          ),
        ],
      ),
      body: withFooter,
    );
  }
}
