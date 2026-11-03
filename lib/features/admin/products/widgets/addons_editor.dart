import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/domain/addon_rules.dart';
import '../../../../core/models/product_addon.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/modern_card.dart';

/// The "Add-ons" block of the product form: how shoppers choose (checkbox or
/// radio) and the list of add-ons with add / edit / enable / remove.
///
/// Stateless on purpose: the form owns the list and saves it with the product.
class AddOnsEditor extends StatelessWidget {
  final List<ProductAddOn> addOns;
  final String selectionType;
  final ValueChanged<List<ProductAddOn>> onChanged;
  final ValueChanged<String> onSelectionChanged;

  const AddOnsEditor({
    super.key,
    required this.addOns,
    required this.selectionType,
    required this.onChanged,
    required this.onSelectionChanged,
  });

  static String messageFor(AppLocalizations l10n, AddOnFormIssue issue) =>
      switch (issue) {
        AddOnFormIssue.titleRequired => l10n.addOnTitleRequired,
        AddOnFormIssue.invalidPrice => l10n.addOnPriceInvalid,
        AddOnFormIssue.invalidDiscount => l10n.addOnDiscountInvalid,
        AddOnFormIssue.invalidImage => l10n.addOnImageInvalid,
        AddOnFormIssue.duplicateTitle => l10n.addOnDuplicateTitle,
      };

  Future<void> _openDialog(BuildContext context, {int? index}) async {
    final result = await showDialog<ProductAddOn>(
      context: context,
      builder: (_) => _AddOnDialog(
        initial: index == null ? null : addOns[index],
        existingTitles: [
          for (var i = 0; i < addOns.length; i++)
            if (i != index) addOns[i].title.trim().toLowerCase(),
        ],
      ),
    );
    if (result == null) return;
    final next = [...addOns];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ModernCard(
      key: const Key('addons-editor'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_task_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.addOnsSectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('addon-add-button'),
                onPressed: () => _openDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  l10n.addAddOn,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addOnsSectionHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(l10n.addOnSelectionTypeLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            key: const Key('addon-selection-type'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AddOnSelectionType.checkbox,
                icon: const Icon(Icons.check_box_outlined, size: 18),
                label: Text(l10n.addOnCheckboxOption),
              ),
              ButtonSegment(
                value: AddOnSelectionType.radio,
                icon: const Icon(Icons.radio_button_checked, size: 18),
                label: Text(l10n.addOnRadioOption),
              ),
            ],
            selected: {selectionType},
            onSelectionChanged: (s) => onSelectionChanged(s.first),
          ),
          const SizedBox(height: 12),
          if (addOns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noAddOnsYet,
                key: const Key('addons-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < addOns.length; i++) _tile(context, i),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = addOns[i];
    return Container(
      key: Key('addon-tile-${a.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: a.isActive ? 1 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!a.isActive) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(l10n.addOnDisabledChip),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    a.price > 0 ? formatCurrency(a.price) : l10n.addOnFree,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (a.isDiscounted)
                    Text(
                      formatCurrency(a.mrp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Switch(
            key: Key('addon-active-${a.id}'),
            value: a.isActive,
            onChanged: (v) {
              final next = [...addOns];
              next[i] = a.copyWith(isActive: v);
              onChanged(next);
            },
          ),
          IconButton(
            key: Key('addon-edit-${a.id}'),
            tooltip: l10n.editAddOn,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _openDialog(context, index: i),
          ),
          IconButton(
            key: Key('addon-remove-${a.id}'),
            tooltip: l10n.remove,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {
              final next = [...addOns]..removeAt(i);
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _AddOnDialog extends StatefulWidget {
  final ProductAddOn? initial;
  final List<String> existingTitles;
  const _AddOnDialog({this.initial, this.existingTitles = const []});

  @override
  State<_AddOnDialog> createState() => _AddOnDialogState();
}

class _AddOnDialogState extends State<_AddOnDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _desc = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _image = TextEditingController(
    text: widget.initial?.imageUrl ?? '',
  );
  late final _price = TextEditingController(text: _num(widget.initial?.amount));
  late final _discount = TextEditingController(
    text: (widget.initial?.discountAmt ?? 0) > 0
        ? _num(widget.initial!.discountAmt)
        : '',
  );
  late bool _active = widget.initial?.isActive ?? true;

  static String _num(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _image.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  /// Error text for one field, judged on its own so every bad field shows
  /// its message at once (not one after another).
  String? _check(AddOnFormIssue field) {
    final l10n = AppLocalizations.of(context);
    final issue = switch (field) {
      AddOnFormIssue.invalidImage => AddOnRules.validateFields(
        title: 'x',
        price: '0',
        imageUrl: _image.text,
      ),
      AddOnFormIssue.invalidPrice => AddOnRules.validateFields(
        title: 'x',
        price: _price.text,
      ),
      _ => AddOnRules.validateFields(
        title: 'x',
        price: _price.text,
        discount: _discount.text,
      ),
    };
    return issue == field ? AddOnsEditor.messageFor(l10n, issue!) : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_price.text.trim());
    final disc = double.tryParse(_discount.text.trim()) ?? 0;
    Navigator.of(context).pop(
      (widget.initial ??
              ProductAddOn(id: AddOnRules.newId(), title: '', amount: 0))
          .copyWith(
            title: _title.text.trim(),
            description: _desc.text.trim(),
            imageUrl: _image.text.trim(),
            amount: amount,
            discountAmt: disc,
            isActive: _active,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addAddOn : l10n.editAddOn),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('addon-title-field'),
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.addOnTitleLabel),
                  validator: (v) {
                    final issue = AddOnRules.validateFields(
                      title: v ?? '',
                      price: '0',
                    );
                    if (issue == AddOnFormIssue.titleRequired) {
                      return l10n.addOnTitleRequired;
                    }
                    if (widget.existingTitles.contains(
                      (v ?? '').trim().toLowerCase(),
                    )) {
                      return l10n.addOnDuplicateTitle;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('addon-description-field'),
                  controller: _desc,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.addOnDescriptionLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('addon-image-field'),
                  controller: _image,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.addOnImageUrlLabel,
                  ),
                  validator: (_) => _check(AddOnFormIssue.invalidImage),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('addon-price-field'),
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.addOnPriceLabel,
                          prefixText: '₹ ',
                        ),
                        validator: (_) => _check(AddOnFormIssue.invalidPrice),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        key: const Key('addon-discount-field'),
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.addOnDiscountLabel,
                          prefixText: '₹ ',
                        ),
                        validator: (_) =>
                            _check(AddOnFormIssue.invalidDiscount),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  key: const Key('addon-enabled-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.addOnEnabledLabel),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('addon-save-button'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
