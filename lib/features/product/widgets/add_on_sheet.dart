import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/domain/addon_rules.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/product.dart';
import '../../../core/models/product_addon.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_product_image.dart';

/// What the shopper confirmed in the add-on sheet.
class AddOnChoice {
  final List<AddOnSnapshot> addOns;
  final int qty;
  const AddOnChoice({this.addOns = const [], this.qty = 1});
}

/// What the confirm button does: the caller decides, the sheet only labels it.
enum AddOnAction { addToCart, buyNow }

/// Bottom sheet shown when a product with add-ons is added or bought:
/// product summary, the add-ons to tick, a price summary and the action.
///
/// Products without available add-ons never see it: [pick] returns the plain
/// choice straight away, so the existing flow is untouched.
class AddOnSheet extends StatefulWidget {
  final Product product;
  final ProductVariant? variant;
  final int initialQty;
  final String symbol;
  final AddOnAction action;

  const AddOnSheet({
    super.key,
    required this.product,
    this.variant,
    this.initialQty = 1,
    this.symbol = '₹',
    this.action = AddOnAction.addToCart,
  });

  /// Asks the shopper for add-ons when [product] has any available.
  ///
  /// Returns null when the shopper dismissed the sheet (nothing should
  /// happen), otherwise the confirmed add-ons and quantity.
  static Future<AddOnChoice?> pick(
    BuildContext context, {
    required Product product,
    ProductVariant? variant,
    int qty = 1,
    String symbol = '₹',
    AddOnAction action = AddOnAction.addToCart,
  }) async {
    if (!AddOnRules.hasAvailable(product)) {
      return AddOnChoice(qty: qty < 1 ? 1 : qty);
    }
    return showModalBottomSheet<AddOnChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => AddOnSheet(
        product: product,
        variant: variant,
        initialQty: qty,
        symbol: symbol,
        action: action,
      ),
    );
  }

  @override
  State<AddOnSheet> createState() => _AddOnSheetState();
}

class _AddOnSheetState extends State<AddOnSheet> {
  List<String> _selected = [];
  late int _qty = widget.initialQty < 1 ? 1 : widget.initialQty;
  bool _busy = false;
  String? _error;

  Product get _product => widget.product;

  /// The line as it would be added right now: the single source of the
  /// numbers shown, so the summary can never disagree with the cart.
  CartItem get _preview {
    final picked = [
      for (final a in AddOnRules.available(_product))
        if (_selected.contains(a.id)) AddOnSnapshot.from(a),
    ];
    return CartItem.fromSelection(
      companyId: _product.companyId,
      companyName: '',
      product: _product,
      selectedVariant: widget.variant,
      qty: _qty,
      addOns: picked,
    );
  }

  String _money(double v) => formatCurrency(v, symbol: widget.symbol);

  void _toggle(String id) {
    setState(() {
      _error = null;
      _selected = AddOnRules.toggle(_product, _selected, id);
    });
  }

  void _confirm() {
    if (_busy) return; // a double tap must not add twice
    final l10n = AppLocalizations.of(context);
    try {
      final addOns = AddOnRules.resolve(_product, _selected);
      setState(() => _busy = true);
      Navigator.of(context).pop(AddOnChoice(addOns: addOns, qty: _qty));
    } on AddOnSelectionException {
      setState(() => _error = l10n.addOnsPriceUpdatedNotice(_product.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = _preview;
    final addOns = AddOnRules.available(_product);
    final radio = AddOnRules.isRadio(_product);
    final baseLine = fromPaise(toPaise(item.effectivePrice) * item.qty);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        key: const Key('addon-sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                _summary(theme, item),
                const Divider(height: 28),
                Text(
                  l10n.addOnsHeading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  radio ? l10n.addOnsPickOne : l10n.addOnsPickAny,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in addOns) _option(theme, a, radio),
                const Divider(height: 28),
                _priceRow(l10n.addOnsProductPrice, _money(baseLine)),
                if (item.addOns.isNotEmpty)
                  _priceRow(
                    l10n.addOnsTotalLabel,
                    '+${_money(item.addOnLineTotal)}',
                    key: const Key('addon-total-row'),
                  ),
                _priceRow(
                  l10n.addOnsFinalTotal,
                  _money(item.lineTotal),
                  bold: true,
                  key: const Key('addon-final-total'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      key: const Key('addon-error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('addon-confirm'),
                  onPressed: _busy ? null : _confirm,
                  child: Text(
                    widget.action == AddOnAction.buyNow
                        ? l10n.addOnsContinueToBuy
                        : l10n.addToCart,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(ThemeData theme, CartItem item) {
    final label = item.variantLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppProductImage.product(
          product: _product,
          width: 64,
          height: 64,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (label.isNotEmpty)
                Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                _money(item.effectivePrice),
                key: const Key('addon-product-price'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _qtyStepper(),
      ],
    );
  }

  Widget _qtyStepper() {
    final maxQty = _preview.maxQty;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('addon-qty-minus'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
          ),
          Text('$_qty', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            key: const Key('addon-qty-plus'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: _qty < maxQty ? () => setState(() => _qty++) : null,
          ),
        ],
      ),
    );
  }

  Widget _option(ThemeData theme, ProductAddOn a, bool radio) {
    final l10n = AppLocalizations.of(context);
    final on = _selected.contains(a.id);
    final icon = radio
        ? (on ? Icons.radio_button_checked : Icons.radio_button_unchecked)
        : (on ? Icons.check_box : Icons.check_box_outline_blank);
    return Semantics(
      checked: on,
      inMutuallyExclusiveGroup: radio,
      label: a.title,
      child: InkWell(
        key: Key('addon-option-${a.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggle(a.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: on
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              if (a.hasImage) ...[
                AppProductImage(
                  url: a.imageUrl,
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.description.trim().isNotEmpty)
                      Text(
                        a.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    a.price > 0 ? '+${_money(a.price)}' : l10n.addOnFree,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (a.isDiscounted)
                    Text(
                      _money(a.mrp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false, Key? key}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
