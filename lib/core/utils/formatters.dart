import 'package:intl/intl.dart';

/// Currency & date formatting helpers (respect company currency symbol).
String formatCurrency(double amount, {String symbol = '₹'}) {
  final f = NumberFormat('#,##0.##', 'en_US');
  return '$symbol${f.format(amount)}';
}

String formatDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

/// Generate a deep link per spec (Section 15).
String productDeepLink(String id) => 'ecommerce://product/$id';
String categoryDeepLink(String id) => 'ecommerce://category/$id';
String companyDeepLink(String slug) => 'ecommerce://company/$slug';
String orderDeepLink(String id) => 'ecommerce://order/$id';
