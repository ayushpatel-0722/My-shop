import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/admin.dart';
import '../models/order.dart';
import 'service_locator.dart';

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

  /// Resolves the specific shop's verified admin email address.
  ///
  /// Priority:
  /// 1. Company admins subcollection `/companies/{companyId}/admins`
  /// 2. Company document data (adminEmail / email)
  /// 3. Default support email fallback
  static Future<String> resolveShopAdminEmail(String companyId) async {
    if (companyId.isEmpty) return supportTargetEmail;
    try {
      final adminList = await repo.admins(companyId).first.timeout(
        const Duration(seconds: 4),
        onTimeout: () => const <Admin>[],
      );
      for (final admin in adminList) {
        if (admin.email.trim().isNotEmpty) {
          return admin.email.trim();
        }
      }

      final comp = await repo.company(companyId).timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (comp != null) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final adminEmail =
              data?['adminEmail'] as String? ?? data?['email'] as String?;
          if (adminEmail != null && adminEmail.trim().isNotEmpty) {
            return adminEmail.trim();
          }
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ [EmailService] Error resolving admin email for shop $companyId: $e',
      );
    }
    return supportTargetEmail;
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

  /// Sends an order placed notification email directly to that specific shop's
  /// store admin with the full item breakdown, totals, and customer details.
  static Future<bool> sendOrderPlacedEmail({
    required Order order,
    String? recipientEmail,
  }) async {
    try {
      final targetEmail = (recipientEmail != null && recipientEmail.trim().isNotEmpty)
          ? recipientEmail.trim()
          : await resolveShopAdminEmail(order.companyId);

      final orderShortId = order.id.length > 8
          ? order.id.substring(0, 8).toUpperCase()
          : (order.id.isNotEmpty ? order.id.toUpperCase() : 'NEW');
      final emailSubject =
          'New Order Received – Order #$orderShortId – ${order.companyName}';

      final emailBody = StringBuffer();
      emailBody.writeln('NEW ORDER NOTIFICATION');
      emailBody.writeln('Shop: ${order.companyName} (ID: ${order.companyId})');
      emailBody.writeln('Order ID: #${order.id}');
      final placedAt = (order.createdAt ?? DateTime.now()).toLocal();
      emailBody.writeln('Order Date / Time: $placedAt');
      emailBody.writeln('Order Status: ${order.orderStatus.toUpperCase()}');
      emailBody.writeln(
        'Payment Status: ${order.paymentStatus.toUpperCase()} (Cash on Delivery / Manual)',
      );
      emailBody.writeln();
      emailBody.writeln('CUSTOMER & DELIVERY DETAILS:');
      emailBody.writeln('• Customer Name: ${order.customerName}');
      emailBody.writeln('• Email: ${order.customerEmail}');
      emailBody.writeln('• Mobile Number: ${order.customerPhone}');
      emailBody.writeln('• Delivery Address: ${order.address}');
      if (order.pincode.isNotEmpty) {
        emailBody.writeln('• PIN Code: ${order.pincode}');
      }
      emailBody.writeln();
      emailBody.writeln('ITEMS ORDERED:');
      for (final item in order.items) {
        final variant = item.variantTitle.isNotEmpty
            ? ' (${item.variantTitle})'
            : (item.variantLabel.isNotEmpty ? ' (${item.variantLabel})' : '');
        final itemTotal = (item.unitPrice * item.qty).toStringAsFixed(2);
        emailBody.writeln(
          '• ${item.name}$variant | Qty: ${item.qty} | Unit: ₹${item.unitPrice.toStringAsFixed(2)} | Total: ₹$itemTotal',
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
      emailBody.writeln('========================================');

      final uri = Uri(
        scheme: 'mailto',
        path: targetEmail,
        query: _encodeQueryParameters({
          'subject': emailSubject,
          'body': emailBody.toString(),
        }),
      );

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return await launchUrl(uri);
      }
      return launched;
    } catch (e) {
      debugPrint('⚠️ [EmailService] sendOrderPlacedEmail non-fatal error: $e');
      return false;
    }
  }
}

