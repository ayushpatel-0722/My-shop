import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Static access to the active [AppLocalizations] for context-free layers
/// (domain helpers, models, repositories, services).
///
/// The current locale is kept in sync by `LocaleCubit`; widgets should keep
/// using `AppLocalizations.of(context)`.
class L10n {
  L10n._();

  /// The translations of the currently selected language.
  static AppLocalizations current = lookupAppLocalizations(const Locale('en'));

  /// Switches [current] to the translations of [code] ('en', 'hi', 'gu').
  static void setLocale(String code) {
    current = lookupAppLocalizations(Locale(code));
  }
}
