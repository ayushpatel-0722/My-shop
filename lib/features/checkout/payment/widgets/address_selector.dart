import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/models/customer.dart';
import 'package:myshop/features/account/widgets/add_edit_address_dialog.dart';

/// "Delivery Address" section: the user's saved addresses (max 3) as
/// selectable radio cards with inline edit, plus an "Add New Address" button
/// while fewer than [AddressEntry.maxAddresses] are saved.
class AddressSelector extends StatelessWidget {
  final List<AddressEntry> addresses;
  final String? selectedAddressId;
  final ValueChanged<AddressEntry> onSelected;
  final ValueChanged<AddressEntry> onEdit;
  final VoidCallback onAddNew;

  const AddressSelector({
    super.key,
    required this.addresses,
    required this.selectedAddressId,
    required this.onSelected,
    required this.onEdit,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).deliveryAddress,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (addresses.isNotEmpty)
              Text(
                '${addresses.length}/${AddressEntry.maxAddresses}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (addresses.isEmpty)
          _EmptyAddress(onAddNew: onAddNew)
        else ...[
          for (final address in addresses) ...[
            _AddressCard(
              address: address,
              selected: address.id == selectedAddressId,
              onTap: () => onSelected(address),
              onEdit: () => onEdit(address),
            ),
            const SizedBox(height: 8),
          ],
          if (addresses.length < AddressEntry.maxAddresses)
            OutlinedButton.icon(
              key: const Key('add-new-address'),
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context).addNewAddress),
            ),
        ],
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressEntry address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.07)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('address-card-${address.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            address.label.isEmpty
                                ? AppLocalizations.of(context).home
                                : address.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocalizations.of(context).default2,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${address.name} · ${address.phone}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.formattedAddress,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: Key('edit-address-${address.id}'),
                onPressed: onEdit,
                child: Text(AppLocalizations.of(context).edit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAddress extends StatelessWidget {
  final VoidCallback onAddNew;

  const _EmptyAddress({required this.onAddNew});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('empty-address-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).noSavedAddressesYet,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('add-address-empty'),
            onPressed: onAddNew,
            icon: const Icon(Icons.add, size: 18),
            label: Text(AppLocalizations.of(context).addAddress),
          ),
        ],
      ),
    );
  }
}

/// Opens the shared address form (pre-filled for [initial]) and returns the
/// saved entry, or null when cancelled.
Future<AddressEntry?> showAddressForm(
  BuildContext context, {
  AddressEntry? initial,
}) => AddEditAddressSheet.show(context, initialAddress: initial);
