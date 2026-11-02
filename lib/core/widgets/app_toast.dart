import 'package:flutter/material.dart';

/// The look of a toast: its icon and accent colour.
enum ToastKind { success, error, warning, info }

/// The app's toast messages.
///
/// Every toast:
///  * disappears after [AppToast.duration] (3 seconds);
///  * disappears even when it has an action button (Flutter would otherwise
///    keep a snack bar with an action on screen until it is tapped);
///  * replaces the previous toast instead of queueing behind it, so quick
///    repeated actions never leave a pile of messages waiting to be shown.
///
/// Use [AppToast.success] / [error] / [warning] / [info], or
/// `ScaffoldMessenger.of(context).showAppToast(SnackBar(...))` for a
/// hand-built [SnackBar], which is restyled to match.
class AppToast {
  AppToast._();

  /// How long every toast stays on screen.
  static const duration = Duration(seconds: 3);

  static const _background = Color(0xFF1E293B);
  static const _wideWidth = 440.0;
  static const _wideBreakpoint = 520.0;

  static const _colors = {
    ToastKind.success: Color(0xFF22C55E),
    ToastKind.error: Color(0xFFEF4444),
    ToastKind.warning: Color(0xFFF59E0B),
    ToastKind.info: Color(0xFF3B82F6),
  };

  static const _icons = {
    ToastKind.success: Icons.check_circle_rounded,
    ToastKind.error: Icons.error_rounded,
    ToastKind.warning: Icons.warning_amber_rounded,
    ToastKind.info: Icons.info_rounded,
  };

  static Color colorOf(ToastKind kind) => _colors[kind]!;

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context,
    String message, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
  }) => show(
    context,
    message,
    kind: ToastKind.success,
    detail: detail,
    actionLabel: actionLabel,
    onAction: onAction,
    key: key,
  );

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context,
    String message, {
    String? detail,
    Key? key,
  }) => show(context, message, kind: ToastKind.error, detail: detail, key: key);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context,
    String message, {
    String? detail,
    Key? key,
  }) =>
      show(context, message, kind: ToastKind.warning, detail: detail, key: key);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context,
    String message, {
    String? detail,
    Key? key,
  }) => show(context, message, kind: ToastKind.info, detail: detail, key: key);

  /// Shows a toast, replacing any toast that is on screen.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final toast = _build(
      context,
      kind: kind,
      content: _ToastBody(
        kind: kind,
        message: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        detail: detail == null ? null : Text(detail),
      ),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
      key: key,
    );
    messenger.clearSnackBars();
    return messenger.showSnackBar(toast);
  }

  /// A hand-built [SnackBar] in the toast style, with the 3-second,
  /// non-persistent behaviour. Used for every `showSnackBar` call in the app
  /// through [AppToastMessenger.showAppToast].
  static SnackBar normalize(BuildContext context, SnackBar original) {
    if (original.content is _ToastBody) return original;
    final kind = _kindFromColor(original.backgroundColor);
    final isPlainText = original.content is Text;
    return _build(
      context,
      kind: kind,
      content: isPlainText
          ? _ToastBody(kind: kind, message: original.content)
          : original.content,
      action: original.action,
      key: original.key,
      onVisible: original.onVisible,
    );
  }

  static SnackBar _build(
    BuildContext context, {
    required ToastKind kind,
    required Widget content,
    SnackBarAction? action,
    Key? key,
    VoidCallback? onVisible,
  }) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final accent = colorOf(kind);
    return SnackBar(
      key: key,
      content: content,
      duration: duration,
      // Without this, a snack bar that has an action never goes away.
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: _background,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      width: wide ? _wideWidth : null,
      margin: wide ? null : const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      showCloseIcon: true,
      closeIconColor: Colors.white60,
      dismissDirection: DismissDirection.horizontal,
      onVisible: onVisible,
      action: action == null
          ? null
          : SnackBarAction(
              label: action.label,
              textColor: accent,
              onPressed: action.onPressed,
            ),
    );
  }

  /// A rough guess at the meaning of a hand-built snack bar from its colour,
  /// so older call sites that used red / green / orange keep that meaning.
  static ToastKind _kindFromColor(Color? color) {
    if (color == null) return ToastKind.info;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.25) return ToastKind.info;
    final hue = hsl.hue;
    if (hue < 20 || hue >= 330) return ToastKind.error;
    if (hue >= 20 && hue < 65) return ToastKind.warning;
    if (hue >= 65 && hue < 175) return ToastKind.success;
    return ToastKind.info;
  }
}

/// `showAppToast` for any [ScaffoldMessengerState]: the one way the app shows
/// a [SnackBar]. The previous toast is cleared first so toasts never queue.
extension AppToastMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
    SnackBar snackBar,
  ) {
    clearSnackBars();
    return showSnackBar(AppToast.normalize(context, snackBar));
  }
}

/// The inside of a toast: a tinted icon badge, the message and an optional
/// second line.
class _ToastBody extends StatelessWidget {
  final ToastKind kind;
  final Widget message;
  final Widget? detail;

  const _ToastBody({required this.kind, required this.message, this.detail});

  @override
  Widget build(BuildContext context) {
    final accent = AppToast.colorOf(kind);
    return Row(
      key: Key('toast-${kind.name}'),
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(AppToast._icons[kind], color: accent, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                child: message,
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  child: detail!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
