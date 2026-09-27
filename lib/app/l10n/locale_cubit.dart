import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_service.dart';

/// Manages the app locale (English / Gujarati / Hindi).
/// Persisted per-device via SharedPreferences (Section 3 / Section 20).
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  static const supported = [
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  static const _prefKey = 'preferred_language';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'en';
      await setByCode(code);
    } catch (_) {
      // keep default
    }
  }

  Future<void> set(Locale locale) async {
    L10n.setLocale(locale.languageCode);
    emit(locale);
    await _persist(locale.languageCode);
  }

  Future<void> setByCode(String code) async {
    final match = supported.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => const Locale('en'),
    );
    L10n.setLocale(match.languageCode);
    emit(match);
    await _persist(match.languageCode);
  }

  Future<void> _persist(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }
}
