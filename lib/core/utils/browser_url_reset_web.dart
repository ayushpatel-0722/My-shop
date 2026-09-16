import 'dart:html' as html;

/// Clears the browser URL path, keeping only the origin.
/// This is a no-op on non-web platforms via conditional exports.
void clearBrowserPath() {
  try {
    html.window.history.replaceState(null, '', '/');
  } catch (_) {}
}
