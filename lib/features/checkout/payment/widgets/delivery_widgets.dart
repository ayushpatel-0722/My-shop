import 'package:flutter/material.dart';

import '../../../core/models/company.dart';
import '../../../core/models/order.dart';

/// "Delivery Type" selector for one shop's order block.
///
/// Home Delivery is offered only when the shop allows it
/// (`company.allowsHomeDelivery`); otherwise the option is hidden with an
/// explanatory note and Self Pickup is auto-selected.
class DeliveryTypeSelector extends StatelessWidget {
  final Company? company;
  final String value;
  final ValueChanged<String> onChanged;

  const DeliveryTypeSelector({
    super.key,
    required this.company,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowsHome = company?.allowsHomeDelivery ?? true;
    final allowsPickup = company?.allowsSelfPickup ?? true;
    final effective = value == DeliveryType.homeDelivery && !allowsHome
        ? DeliveryType.selfPickup
        : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const Key('delivery-type-selector'),
          segments: [
            if (allowsHome)
              const ButtonSegment(
                value: DeliveryType.homeDelivery,
                label: Text('Home delivery'),
                icon: Icon(Icons.local_shipping_outlined, size: 18),
              ),
            if (allowsPickup)
              const ButtonSegment(
                value: DeliveryType.selfPickup,
                label: Text('Self pickup'),
                icon: Icon(Icons.storefront_outlined, size: 18),
              ),
          ],
          selected: {effective},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
        ),
        if (!allowsHome && allowsPickup) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This shop does not offer home delivery',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Pickup From" card — shop name, address, phone and timings for
/// self-pickup orders (no delivery address needed).
class PickupShopCard extends StatelessWidget {
  final String shopName;
  final String address;
  final String phone;
  final String timings;

  const PickupShopCard({
    super.key,
    required this.shopName,
    required this.address,
    required this.phone,
    required this.timings,
  });

  /// Builds the card from a [Company] shop document.
  factory PickupShopCard.fromCompany(Company company) {
    final hours = company.weeklyHours
        .where((h) => !h.isClosed)
        .map((h) => '${h.day} ${h.openTime}–${h.closeTime}')
        .join('\n');
    return PickupShopCard(
      shopName: company.name,
      address: company.address,
      phone: company.phone,
      timings: hours,
    );
  }

  /// Snapshot stored on the order for self-pickup.
  PickupShop toSnapshot() => PickupShop(
    name: shopName,
    address: address,
    phone: phone,
    timings: timings,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('pickup-shop-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pickup From',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            shopName,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          if (address.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
          if (timings.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_outlined, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    timings,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
