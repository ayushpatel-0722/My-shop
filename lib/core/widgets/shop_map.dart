import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myshop/core/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n/app_localizations.dart';
import '../models/company.dart';

/// Where "Directions" should go for [company]: the Google Maps link the shop
/// admin saved in Shop Settings, or — when there is none — a Google Maps
/// search for the shop's address. Null when the shop has neither.
String? shopMapUrl(Company company) {
  final link = company.location.trim();
  if (link.startsWith('http://') || link.startsWith('https://')) return link;
  final address = company.address.trim();
  if (address.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': address,
  }).toString();
}

/// Opens the shop's map. Where no map app or browser can be opened, the link
/// is copied instead, with a message, so the shopper can still use it.
Future<void> openShopMap(BuildContext context, Company company) async {
  final url = shopMapUrl(company);
  if (url == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final copied = AppLocalizations.of(context).shopMapCopied;
  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    launched = false;
  }
  if (launched) return;
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showAppToast(
    SnackBar(content: Text(copied), behavior: SnackBarBehavior.floating),
  );
}
