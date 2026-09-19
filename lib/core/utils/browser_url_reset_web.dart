// This file is web-only via conditional exports. Suppress analyzer warnings
// about importing web libraries and deprecations here.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Clears the browser URL path, keeping only the origin.
/// This file is only imported on web via conditional exports, so importing
/// `dart:html` here is safe and avoids depending on an external package.
void clearBrowserPath() {
  try {
    html.window.history.replaceState(null, '', '/');
  } catch (_) {}
}
