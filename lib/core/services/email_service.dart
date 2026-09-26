import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';

class EmailService {
  static const String supportTargetEmail = 'ayush123@gmail.com';

  /// Converts a map of query parameters into an RFC-6068 compliant
  /// query string with proper percent-encoding (%20 instead of + for spaces).
  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  /// Sends a customer support query email to [supportTargetEmail]
  /// with the user's message and their attached account details.
  static Future<bool> sendSupportQueryEmail({
    required String fromEmail,
    required String customerName,
    required String mobileNumber,
    required String address,
    required String category,
    String? orderId,
    required String subject,
    required String message,
  }) async {
    final emailSubject = '[Support Query] $category: $subject';
    final emailBody = StringBuffer();

    emailBody.writeln('Subject: $subject');
    emailBody.writeln('Category: $category');
    if (orderId != null && orderId.trim().isNotEmpty) {
      emailBody.writeln('Order Reference ID: ${orderId.trim()}');
    }
    emailBody.writeln();
    emailBody.writeln('Customer Query / Message:');
    emailBody.writeln(message.trim());
    emailBody.writeln();
    emailBody.writeln('----------------------------------------');
    emailBody.writeln('Customer Account Details:');
    emailBody.writeln('• Name: ${customerName.trim()}');
    emailBody.writeln('• Email: ${fromEmail.trim()}');
    emailBody.writeln('• Mobile Number: ${mobileNumber.trim()}');
    if (address.trim().isNotEmpty) {
      emailBody.writeln('• Delivery Address: ${address.trim()}');
    }
    emailBody.writeln('• Submitted At: ${DateTime.now().toLocal()}');
    emailBody.writeln('----------------------------------------');

    final uri = Uri(
      scheme: 'mailto',
      path: supportTargetEmail,
      query: _encodeQueryParameters({
        'subject': emailSubject,
        'body': emailBody.toString(),
      }),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Fallback without externalApplication mode
        return await launchUrl(uri);
      }
      return launched;
    } catch (e) {
      debugPrint('EmailService.sendSupportQueryEmail launch error: $e');
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }

  /// Sends an order placed confirmation/notification email to [supportTargetEmail]
  /// and the store admin with the full order breakdown and customer details.
  static Future<bool> sendOrderPlacedEmail({
    required Order order,
    String recipientEmail = supportTargetEmail,
  }) async {
    final orderShortId = order.id.length > 8
        ? order.id.substring(0, 8).toUpperCase()
        : (order.id.isNotEmpty ? order.id.toUpperCase() : 'NEW');
    final emailSubject =
        '[New Order Placed] #$orderShortId - ${order.companyName}';

    final emailBody = StringBuffer();
    emailBody.writeln('NEW ORDER NOTIFICATION');
    emailBody.writeln('Order ID: #${order.id}');
    final placedAt = (order.createdAt ?? DateTime.now()).toLocal();
    emailBody.writeln('Placed At: $placedAt');
    emailBody.writeln('Store: ${order.companyName} (ID: ${order.companyId})');
    emailBody.writeln('Status: ${order.orderStatus.toUpperCase()}');
    emailBody.writeln(
      'Payment Status: ${order.paymentStatus.toUpperCase()} (Manual / Offline)',
    );
    emailBody.writeln();
    emailBody.writeln('ITEMS ORDERED:');
    for (final item in order.items) {
      final variant = item.variantTitle.isNotEmpty
          ? ' (${item.variantTitle})'
          : '';
      final itemTotal = (item.unitPrice * item.qty).toStringAsFixed(2);
      emailBody.writeln(
        '• ${item.name}$variant x${item.qty} @ ₹${item.unitPrice.toStringAsFixed(2)} = ₹$itemTotal',
      );
    }
    emailBody.writeln();
    emailBody.writeln('BILL SUMMARY:');
    emailBody.writeln('• Subtotal: ₹${order.subtotal.toStringAsFixed(2)}');
    emailBody.writeln(
      '• Delivery Charge: ₹${order.deliveryCharge.toStringAsFixed(2)}',
    );
    emailBody.writeln(
      '• Discount: ₹${order.discountAmount.toStringAsFixed(2)}',
    );
    emailBody.writeln(
      '• Total Amount: ₹${order.totalAmount.toStringAsFixed(2)}',
    );
    emailBody.writeln();
    emailBody.writeln('----------------------------------------');
    emailBody.writeln('CUSTOMER & DELIVERY DETAILS:');
    emailBody.writeln('• Customer Name: ${order.customerName}');
    emailBody.writeln('• Email: ${order.customerEmail}');
    emailBody.writeln('• Mobile Number: ${order.customerPhone}');
    emailBody.writeln('• Delivery Address: ${order.address}');
    if (order.pincode.isNotEmpty) {
      emailBody.writeln('• PIN Code: ${order.pincode}');
    }
    emailBody.writeln('========================================');

    final uri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      query: _encodeQueryParameters({
        'subject': emailSubject,
        'body': emailBody.toString(),
      }),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return await launchUrl(uri);
      }
      return launched;
    } catch (e) {
      debugPrint('EmailService.sendOrderPlacedEmail launch error: $e');
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }
}
