import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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
}
