import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/order.dart';
import '../../../../core/services/auth_session.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/order_status_badge.dart';

/// Modal dialog for store administrators to verify payment for an order.
///
/// Workflow:
///  1. Admin opens an unpaid order and taps "Confirm Payment Received".
///  2. Dialog presents the order amount, reference, customer name, and current status.
///  3. Admin selects the actual payment method (Cash or UPI).
///  4. Admin confirms physical collection or UPI receipt.
///  5. Admin taps "Confirm Payment Received" to atomically commit the payment status
///     and selected payment method to the repository.
class PaymentVerificationDialog extends StatefulWidget {
  final Order order;

  const PaymentVerificationDialog({super.key, required this.order});

  /// Displays the payment verification dialog and returns `true` if payment was
  /// confirmed and saved.
  static Future<bool?> show(BuildContext context, Order order) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentVerificationDialog(order: order),
    );
  }

  @override
  State<PaymentVerificationDialog> createState() =>
      _PaymentVerificationDialogState();
}

class _PaymentVerificationDialogState extends State<PaymentVerificationDialog> {
  late final TextEditingController _transactionRefCtrl;
  String? _selectedMethod;
  bool _confirmedReceipt = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Order get order => widget.order;

  @override
  void initState() {
    super.initState();
    _transactionRefCtrl = TextEditingController(
      text: order.transactionRef ?? '',
    );
    // If the order already had a valid recorded payment method, pre-select it
    if (PaymentMethod.isValid(order.paymentMethod)) {
      _selectedMethod = order.paymentMethod.toLowerCase();
    }
  }

  @override
  void dispose() {
    _transactionRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_selectedMethod == null || !PaymentMethod.isValid(_selectedMethod!)) {
      setState(() {
        _errorMessage = 'Please select a payment method (Cash or UPI).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final currentAdmin = AuthSession.currentUser;
    final verifiedBy = currentAdmin?.name.isNotEmpty == true
        ? '${currentAdmin!.name} (${currentAdmin.email})'
        : (currentAdmin?.email.isNotEmpty == true
              ? currentAdmin!.email
              : (currentAdmin?.id ?? 'Store Admin'));

    final verifiedRef = _transactionRefCtrl.text.trim();
    final isUpi = _selectedMethod == PaymentMethod.upi;

    try {
      await repo.verifyPayment(
        orderId: order.id,
        companyId: order.companyId,
        paymentStatus: PaymentStatus.done,
        paymentMethod: _selectedMethod!,
        verifiedBy: verifiedBy,
        transactionRef: isUpi && verifiedRef.isNotEmpty ? verifiedRef : null,
        amountPaid: order.totalAmount,
        note: isUpi
            ? 'UPI payment of ${formatCurrency(order.totalAmount)} verified${verifiedRef.isNotEmpty ? " (UTR: $verifiedRef)" : ""} by $verifiedBy'
            : 'Cash payment of ${formatCurrency(order.totalAmount)} collected & verified by $verifiedBy',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isUpi
                      ? 'UPI payment confirmed for order ${order.reference}'
                      : 'Cash payment confirmed for order ${order.reference}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!)
        : '';

    final isUpi = _selectedMethod == PaymentMethod.upi;
    final isCash = _selectedMethod == PaymentMethod.cash;
    final canSubmit =
        _selectedMethod != null &&
        PaymentMethod.isValid(_selectedMethod!) &&
        !_isSubmitting;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payments_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm Payment Received',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order ${order.reference} · ${order.customerName.isNotEmpty ? order.customerName : "Customer"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Order Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Payable Amount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          formatCurrency(order.totalAmount),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Payment Status:',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: order.isPaid
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.paymentStatusDisplay.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: order.isPaid
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Date:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Status:',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                        OrderStatusBadge(status: order.orderStatus),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Method selection heading
              Row(
                children: [
                  Text(
                    'Select Payment Method',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Selection cards: Cash and UPI
              Row(
                children: [
                  // Cash Option
                  Expanded(
                    child: InkWell(
                      key: const Key('payment-method-cash-option'),
                      onTap: _isSubmitting
                          ? null
                          : () => setState(
                              () => _selectedMethod = PaymentMethod.cash,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCash ? Colors.green.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCash
                                ? Colors.green.shade700
                                : Colors.grey.shade300,
                            width: isCash ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                if (isCash)
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green.shade700,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Cash',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Collected in cash',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // UPI Option
                  Expanded(
                    child: InkWell(
                      key: const Key('payment-method-upi-option'),
                      onTap: _isSubmitting
                          ? null
                          : () => setState(
                              () => _selectedMethod = PaymentMethod.upi,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUpi ? Colors.indigo.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUpi
                                ? Colors.indigo.shade700
                                : Colors.grey.shade300,
                            width: isUpi ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 18,
                                    color: Colors.indigo.shade800,
                                  ),
                                ),
                                if (isUpi)
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.indigo.shade700,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'UPI',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Received via UPI / QR',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // UPI Reference / UTR input if UPI is selected
              if (isUpi) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('dialog-upi-ref-field'),
                  controller: _transactionRefCtrl,
                  decoration: InputDecoration(
                    labelText: 'UPI Reference / UTR Number (Optional)',
                    hintText: 'e.g. 12-digit bank reference number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.tag, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],

              const SizedBox(height: 16),

              // Confirmation check / message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: const Key('confirm-receipt-checkbox'),
                      value: _confirmedReceipt,
                      onChanged: _isSubmitting
                          ? null
                          : (v) =>
                                setState(() => _confirmedReceipt = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () => setState(
                                () => _confirmedReceipt = !_confirmedReceipt,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'I confirm that I have received the full payment of ${formatCurrency(order.totalAmount)} for this order using ${_selectedMethod != null ? PaymentMethod.displayName(_selectedMethod!) : "the selected payment method"}.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.blue.shade900,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error banner if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    key: const Key('confirm-payment-action-btn'),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'Confirm Payment Received',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: canSubmit ? _handleConfirm : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
