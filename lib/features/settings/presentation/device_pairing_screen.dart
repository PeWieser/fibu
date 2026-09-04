import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/services/device_pairing_service.dart';
import '../../../core/utils/app_paths.dart';
import '../../../theme/theme.dart';

/// Gerät-zu-Gerät-Übertragung der Konfiguration.
///
/// Auf dem Desktop: zeigt einen QR-Code und nimmt die Konfiguration eines
/// Mobilgeräts entgegen. Auf Mobil: nimmt die Adresse entgegen und sendet die
/// eigene Konfiguration.
///
/// **Bewusste Grenze: kein Kamera-Scanner.** Die Adresse wird abgetippt oder
/// eingefügt. Ein Scanner bräuchte ein natives Kamera-Plugin, und das würde
/// eine Kamera-Berechtigung plus einen Eintrag im Privacy Manifest aufmachen
/// (docs/RECHTS_AUDIT.md, L-13). Die Funktion ist dieselbe, nur die Eingabe
/// ist eine Zeile Text statt eines Kamera-Bilds.
class DevicePairingScreen extends ConsumerStatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  ConsumerState<DevicePairingScreen> createState() =>
      _DevicePairingScreenState();
}

enum _PairingPhase { idle, waiting, received, failed }

class _DevicePairingScreenState extends ConsumerState<DevicePairingScreen> {
  _PairingPhase _phase = _PairingPhase.idle;
  PairingSession? _session;
  PairingBundle? _received;
  String? _error;
  bool _sending = false;

  /// Anzahl Aufgaben, deren Spiegelungs-Modus beim Import heruntergestuft
  /// wurde — wird in der Erfolgsmeldung genannt, nicht still verschwiegen.
  int _downgradedMirror = 0;

  /// Spiegelung mit Zustand, Tombstones und Bremse gibt es nur auf
  /// iOS/Android. Empfängt ein Desktop, wird der Modus herabgestuft;
  /// empfängt ein Mobilgerät, bleibt er erhalten.
  static bool get _platformHasTwoWayMirror {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  final TextEditingController _urlCtrl = TextEditingController();

  /// Wer empfängt, ist eine **Wahl**, keine Plattform-Eigenschaft.
  ///
  /// Vorher war der Desktop immer Empfänger und Mobil immer Sender — damit
  /// war „Windows zuerst einrichten, dann aufs iPhone übertragen" schlicht
  /// nicht möglich (docs/TESTMATRIX_IOS_WINDOWS.md, A6). Jetzt kann jedes
  /// Gerät beide Rollen; der Startwert folgt nur der wahrscheinlicheren
  /// Richtung.
  late bool _isReceiver = _defaultRoleIsReceiver;

  static bool get _defaultRoleIsReceiver {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  void _setRole(bool receive) {
    if (_isReceiver == receive) return;
    // Rollenwechsel beendet eine laufende Empfangs-Sitzung, sonst bliebe der
    // Port belegt und der QR-Code würde weiter etwas versprechen.
    DevicePairingService.stopReceiver();
    setState(() {
      _isReceiver = receive;
      _phase = _PairingPhase.idle;
      _session = null;
      _received = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    // Sitzung immer abbauen, sonst bleibt der Port belegt.
    DevicePairingService.stopReceiver();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _startReceiving() async {
    setState(() {
      _phase = _PairingPhase.waiting;
      _error = null;
    });
    final session = await DevicePairingService.startReceiver();
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _phase = _PairingPhase.failed;
        _error = ref.read(stringsProvider).pairingNoNetwork;
      });
      return;
    }
    setState(() => _session = session);

    try {
      final bundle = await DevicePairingService.waitForBundle();
      if (!mounted) return;
      if (bundle == null) {
        setState(() => _phase = _PairingPhase.failed);
        return;
      }
      await _importBundle(bundle);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _PairingPhase.failed;
        _error = ref.read(stringsProvider).pairingTimeout;
      });
    }
  }

  /// Empfangene Konfiguration in die eigenen Dateien schreiben.
  ///
  /// Überschreibt `rclone.conf` und `remotes.json` vollständig — die
  /// Laufwerke kommen ja gerade deshalb vom anderen Gerät. Aufgaben werden
  /// übernommen, aber ihre Quelle geleert, wenn sie auf die Mediathek des
  /// anderen Geräts zeigt (dieselbe Regel wie beim Import aus der Cloud).
  Future<void> _importBundle(PairingBundle bundle) async {
    var downgradedMirror = 0;
    try {
      final conf = await privateAppFile('rclone.conf');
      await conf.writeAsString(bundle.rcloneConf);

      final remotes = await privateAppFile('remotes.json');
      await remotes.writeAsString(_encode(bundle.remotes));

      final mobileSource = RegExp(r'^(photos:|videos:|all:|all\$|photos\$|videos\$)');
      final adapted = bundle.tasks.map((t) {
        final src = (t['sourcePath'] as String? ?? '');
        final next = Map<String, dynamic>.from(t);

        // Quelle eines anderen Geräts: geleert, muss hier gewählt werden.
        if (mobileSource.hasMatch(src)) {
          next['sourcePath'] = '';
          next['selectedAlbums'] = const <String>[];
        }

        // „Spiegelung" vom Mobilgerät ist ein echter 2-Wege-Algorithmus mit
        // Zustand, Tombstones und Sicherheitsbremse. Der Desktop hat nichts
        // davon — dort ist es `rclone sync`, also 1-Weg mit Löschrecht. Auf
        // einem geteilten Zielordner würde das die Dateien des anderen Geräts
        // löschen (docs/TESTMATRIX_IOS_WINDOWS.md, B9). Deshalb wird der Modus
        // beim Import auf den Desktop heruntergestuft.
        if (next['syncMode'] == 'mirror' && !_platformHasTwoWayMirror) {
          next['syncMode'] = 'incremental';
          downgradedMirror++;
        }
        return next;
      }).toList();
      final tasks = await privateAppFile('tasks.json');
      await tasks.writeAsString(_encode(adapted));

      if (!mounted) return;
      _downgradedMirror = downgradedMirror;
      setState(() {
        _received = bundle;
        _phase = _PairingPhase.received;
      });
      await DevicePairingService.stopReceiver();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PairingPhase.failed;
        _error = '$e';
      });
    }
  }

  String _encode(Object value) => const JsonEncoder.withIndent('  ').convert(value);

  Future<void> _send() async {
    final strings = ref.read(stringsProvider);
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = strings.pairingUrlMissing);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final bundle = await DevicePairingService.collectBundle(
        defaultTargetPlatform.name);
    final ok = await DevicePairingService.send(url: url, bundle: bundle);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _phase = ok ? _PairingPhase.received : _PairingPhase.failed;
      if (!ok) _error = strings.pairingSendFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appThemeProvider);
    final theme = context.theme;
    final strings = ref.watch(stringsProvider);
    final platform = defaultTargetPlatform;

    final body = SingleChildScrollView(
      padding: EdgeInsets.all(theme.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _roleSwitch(theme, strings),
              SizedBox(height: theme.xl),
              _isReceiver
                  ? _receiverBody(theme, strings)
                  : _senderBody(theme, strings),
            ],
          ),
        ),
      ),
    );

    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoPageScaffold(
        backgroundColor: theme.canvas,
        navigationBar: cupertino.CupertinoNavigationBar(
          middle: Text(strings.pairingTitle),
          previousPageTitle: strings.back,
          backgroundColor: theme.surface,
        ),
        child: SafeArea(child: body),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: fluent.Text(strings.pairingTitle),
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
        content: body,
      );
    }
    return material.Scaffold(
      backgroundColor: theme.canvas,
      appBar: material.AppBar(title: Text(strings.pairingTitle)),
      body: body,
    );
  }

  /// Umschalter Senden/Empfangen — auf jeder Plattform verfügbar.
  Widget _roleSwitch(AppThemeData theme, AppStrings strings) {
    final options = <bool, String>{
      true: strings.pairingRoleReceive,
      false: strings.pairingRoleSend,
    };
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoSlidingSegmentedControl<bool>(
        groupValue: _isReceiver,
        children: {
          for (final entry in options.entries)
            entry.key: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.md),
              child: Text(entry.value, style: const TextStyle(fontSize: 13)),
            ),
        },
        onValueChanged: (v) {
          if (v != null) _setRole(v);
        },
      );
    }
    if (platform == TargetPlatform.windows) {
      return Row(
        children: [
          for (final entry in options.entries)
            Padding(
              padding: EdgeInsets.only(right: theme.lg),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setRole(entry.key),
                  child: ConstrainedBox(
                    // 44 px Trefferfläche: Der sichtbare Punkt ist 16 px, das
                    // Ziel muss trotzdem groß sein (WCAG 2.5.8).
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Icon(
                          _isReceiver == entry.key
                              ? fluent.FluentIcons.radio_bullet
                              : fluent.FluentIcons.radio_btn_off,
                          size: 16,
                          color: _isReceiver == entry.key
                              ? theme.accent
                              : theme.textSecondary,
                        ),
                        SizedBox(width: theme.sm),
                        Text(entry.value),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (final entry in options.entries)
          Expanded(
            child: material.ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _isReceiver == entry.key
                    ? material.Icons.radio_button_checked
                    : material.Icons.radio_button_unchecked,
                color: _isReceiver == entry.key
                    ? theme.accent
                    : theme.textSecondary,
              ),
              title: Text(entry.value),
              onTap: () => _setRole(entry.key),
            ),
          ),
      ],
    );
  }

  // --- Empfänger (Desktop) --------------------------------------------------

  Widget _receiverBody(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.pairingReceiverIntro,
            style: TextStyle(
                color: theme.textPrimary, fontSize: 14, height: 1.5)),
        SizedBox(height: theme.lg),
        if (_phase == _PairingPhase.idle || _phase == _PairingPhase.failed)
          _primaryButton(strings.pairingStart, _startReceiving, theme),
        if (_phase == _PairingPhase.waiting && _session != null) ...[
          Center(
            child: Container(
              padding: EdgeInsets.all(theme.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(theme.radiusLg),
              ),
              child: QrImageView(
                data: _session!.uri.toString(),
                size: 240,
                backgroundColor: const Color(0xFFFFFFFF),
              ),
            ),
          ),
          SizedBox(height: theme.md),
          Center(
            child: Text(
              strings.pairingOrEnterCode(_session!.uri.toString()),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          SizedBox(height: theme.lg),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: material.CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: theme.sm),
                Text(strings.pairingWaiting,
                    style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
        if (_phase == _PairingPhase.received && _received != null)
          _resultBox(
            theme,
            '${strings.pairingReceived(
              _received!.deviceName,
              _received!.remotes.length,
              _received!.tasks.length,
            )}${_downgradedMirror > 0
                ? '\n\n${strings.pairingMirrorDowngraded(_downgradedMirror)}'
                : ''}',
            isError: false,
          ),
        if (_error != null) ...[
          SizedBox(height: theme.md),
          _resultBox(theme, _error!, isError: true),
        ],
      ],
    );
  }

  // --- Sender (Mobil) -------------------------------------------------------

  Widget _senderBody(AppThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.pairingSenderIntro,
            style: TextStyle(
                color: theme.textPrimary, fontSize: 14, height: 1.5)),
        SizedBox(height: theme.lg),
        material.TextField(
          controller: _urlCtrl,
          decoration: material.InputDecoration(
            labelText: strings.pairingUrlLabel,
            hintText: 'http://192.168.1.20:53124/#…',
            border: const material.OutlineInputBorder(),
          ),
          autocorrect: false,
        ),
        SizedBox(height: theme.lg),
        _primaryButton(
            _sending ? strings.pairingSending : strings.pairingSend,
            _sending ? null : _send,
            theme),
        if (_phase == _PairingPhase.received)
          _resultBox(theme, strings.pairingSent, isError: false),
        if (_error != null) ...[
          SizedBox(height: theme.md),
          _resultBox(theme, _error!, isError: true),
        ],
      ],
    );
  }

  // --- Bausteine -----------------------------------------------------------

  Widget _primaryButton(String label, VoidCallback? onPressed, AppThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: material.FilledButton(
        onPressed: onPressed,
        style: material.FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: theme.accentText,
          disabledBackgroundColor: theme.offline.withValues(alpha: 0.35),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _resultBox(AppThemeData theme, String text, {required bool isError}) {
    final color = isError ? theme.error : theme.success;
    return Container(
      padding: EdgeInsets.all(theme.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 13, height: 1.4)),
    );
  }
}
