import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/locale_cubit.dart';

/// Compact language picker (English / Gujarati / Hindi).
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LocaleCubit>();
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        return Wrap(
          spacing: 8,
          children: [
            _lang(context, cubit, 'en', 'EN', locale),
            _lang(context, cubit, 'gu', 'ગુ', locale),
            _lang(context, cubit, 'hi', 'हि', locale),
          ],
        );
      },
    );
  }

  Widget _lang(
    BuildContext context,
    LocaleCubit cubit,
    String code,
    String label,
    Locale current,
  ) {
    final active = current.languageCode == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => cubit.setByCode(code),
    );
  }
}
