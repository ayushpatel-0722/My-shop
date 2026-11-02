import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myshop/core/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n/app_localizations.dart';
import '../services/service_locator.dart';

/// The digits of [phone] (keeping a leading +) for a `tel:` link.
String dialableNumber(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// Starts a phone call to [phone]. Where calling is not possible (a desktop
/// browser, a device without a phone app) the number is copied instead, with a
/// message, so the shopper can still use it.
Future<void> callShop(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final copied = AppLocalizations.of(context).shopPhoneCopied;
  var launched = false;
  try {
    launched = await launchUrl(Uri(scheme: 'tel', path: dialableNumber(phone)));
  } catch (_) {
    launched = false;
  }
  if (launched) return;
  await Clipboard.setData(ClipboardData(text: phone.trim()));
  messenger.showAppToast(
    SnackBar(content: Text(copied), behavior: SnackBarBehavior.floating),
  );
}

/// A shop's phone number with a "Call shop" button.
class ShopPhoneTile extends StatelessWidget {
  final String phone;
  const ShopPhoneTile({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('shop-phone-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.phone_outlined),
      title: SelectableText(phone, key: const Key('shop-phone-number')),
      trailing: TextButton.icon(
        key: const Key('shop-call-button'),
        onPressed: () => callShop(context, phone),
        icon: const Icon(Icons.call, size: 18),
        label: Text(l10n.shopCallShop),
      ),
    );
  }
}

/// "Contact the shop" card for shopper screens. It reads the phone number the
/// shop admin entered in Shop Settings; [fallbackPhone] (for example the one
/// saved on a pickup order) is used if the shop has none. Shows nothing when
/// there is no number.
class ShopContactCard extends StatefulWidget {
  final String companyId;
  final String fallbackPhone;
  const ShopContactCard({
    super.key,
    required this.companyId,
    this.fallbackPhone = '',
  });

  @override
  State<ShopContactCard> createState() => _ShopContactCardState();
}

class _ShopContactCardState extends State<ShopContactCard> {
  late final Future<String> _phone = _load();

  Future<String> _load() async {
    try {
      final company = widget.companyId.isEmpty
          ? null
          : await repo.company(widget.companyId);
      final fromShop = company?.phone.trim() ?? '';
      return fromShop.isNotEmpty ? fromShop : widget.fallbackPhone.trim();
    } catch (_) {
      return widget.fallbackPhone.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _phone,
      builder: (context, snap) {
        final phone = snap.data ?? '';
        if (phone.isEmpty) return const SizedBox.shrink();
        return Card(
          key: const Key('shop-contact-card'),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppLocalizations.of(context).shopContactTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ShopPhoneTile(phone: phone),
              ],
            ),
          ),
        );
      },
    );
  }
}
