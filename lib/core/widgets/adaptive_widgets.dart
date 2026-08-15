import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;


Widget buildAdaptiveTextField({
  required TargetPlatform platform,
  required TextEditingController controller,
  String? placeholder,
  bool obscureText = false,
  Widget? suffix,
  Widget? prefix,
  int? maxLines = 1,
  ValueChanged<String>? onChanged,
  bool autofocus = false,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      suffix: suffix,
      prefix: prefix,
      maxLines: maxLines,
      onChanged: onChanged,
      autofocus: autofocus,
      padding: const EdgeInsets.all(12.0),
    );
  } else if (platform == TargetPlatform.windows) {
    return fluent.TextBox(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      suffix: suffix,
      prefix: prefix,
      maxLines: maxLines,
      onChanged: onChanged,
      autofocus: autofocus,
    );
  } else {
    return material.TextField(
      controller: controller,
      decoration: material.InputDecoration(
        hintText: placeholder,
        suffixIcon: suffix,
        prefixIcon: prefix,
        border: const material.OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      autofocus: autofocus,
    );
  }
}

Widget buildAdaptiveFilledButton({
  required TargetPlatform platform,
  required VoidCallback? onPressed,
  required Widget child,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoButton.filled(
      onPressed: onPressed,
      child: child,
    );
  } else if (platform == TargetPlatform.windows) {
    return fluent.FilledButton(
      onPressed: onPressed,
      child: child,
    );
  } else {
    return material.FilledButton(
      onPressed: onPressed,
      child: child,
    );
  }
}

Widget buildAdaptiveOutlinedButton({
  required TargetPlatform platform,
  required VoidCallback? onPressed,
  required Widget child,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoButton(
      onPressed: onPressed,
      child: child,
    );
  } else if (platform == TargetPlatform.windows) {
    return fluent.Button(
      onPressed: onPressed,
      child: child,
    );
  } else {
    return material.OutlinedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}

Widget buildAdaptiveProgressIndicator({
  required TargetPlatform platform,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return const CupertinoActivityIndicator();
  } else if (platform == TargetPlatform.windows) {
    return const fluent.ProgressRing();
  } else {
    return const material.CircularProgressIndicator();
  }
}

Widget buildAdaptiveDivider({
  required TargetPlatform platform,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return Container(
      height: 1,
      color: CupertinoColors.separator,
    );
  } else if (platform == TargetPlatform.windows) {
    return const fluent.Divider();
  } else {
    return const material.Divider();
  }
}

class AdaptiveInfoIcon extends StatelessWidget {
  final TargetPlatform platform;
  final String message;

  const AdaptiveInfoIcon({
    super.key,
    required this.platform,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return GestureDetector(
        onTap: () {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text("Info"),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  child: const Text("OK"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
        child: const Icon(
          CupertinoIcons.info_circle,
          color: CupertinoColors.activeBlue,
          size: 20,
        ),
      );
    } else if (platform == TargetPlatform.windows) {
      return fluent.Tooltip(
        message: message,
        child: const Icon(fluent.FluentIcons.info, size: 16),
      );
    } else {
      return material.Tooltip(
        message: message,
        child: const Icon(material.Icons.info_outline, size: 20),
      );
    }
  }
}

Widget buildAdaptiveInfoIcon({
  required TargetPlatform platform,
  required String message,
}) {
  return AdaptiveInfoIcon(platform: platform, message: message);
}

class AdaptivePasswordToggle extends StatefulWidget {
  final TargetPlatform platform;
  final TextEditingController controller;
  final String? placeholder;

  const AdaptivePasswordToggle({
    super.key,
    required this.platform,
    required this.controller,
    this.placeholder,
  });

  @override
  State<AdaptivePasswordToggle> createState() => AdaptivePasswordToggleState();
}

class AdaptivePasswordToggleState extends State<AdaptivePasswordToggle> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    Widget toggleButton;
    
    if (widget.platform == TargetPlatform.iOS || widget.platform == TargetPlatform.macOS) {
      toggleButton = CupertinoButton(
        padding: EdgeInsets.zero,
        child: Icon(
          _obscureText ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          color: CupertinoColors.systemGrey,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    } else if (widget.platform == TargetPlatform.windows) {
      toggleButton = fluent.IconButton(
        icon: Icon(
          _obscureText ? fluent.FluentIcons.red_eye : fluent.FluentIcons.hide,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    } else {
      toggleButton = material.IconButton(
        icon: Icon(
          _obscureText ? material.Icons.visibility : material.Icons.visibility_off,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    return buildAdaptiveTextField(
      platform: widget.platform,
      controller: widget.controller,
      placeholder: widget.placeholder,
      obscureText: _obscureText,
      suffix: toggleButton,
    );
  }
}

Widget buildAdaptivePasswordToggle({
  required TargetPlatform platform,
  required TextEditingController controller,
  String? placeholder,
}) {
  return AdaptivePasswordToggle(
    platform: platform,
    controller: controller,
    placeholder: placeholder,
  );
}
