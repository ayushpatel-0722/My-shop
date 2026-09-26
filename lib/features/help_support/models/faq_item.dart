import 'package:flutter/material.dart';

enum FaqCategory {
  all('All', Icons.grid_view_rounded),
  orders('Orders & Tracking', Icons.local_shipping_outlined),
  delivery('Delivery & Shipping', Icons.electric_moped_outlined),
  payments('Payments & Refunds', Icons.payment_outlined),
  returns('Returns & Exchanges', Icons.assignment_return_outlined),
  account('Account & Security', Icons.person_outline),
  vouchers('Discounts & Offers', Icons.local_offer_outlined);

  final String label;
  final IconData icon;
  const FaqCategory(this.label, this.icon);
}

class FaqItem {
  final String id;
  final String question;
  final String answer;
  final FaqCategory category;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });
}

/// Comprehensive pre-populated FAQs
final List<FaqItem> defaultFaqs = [
  const FaqItem(
    id: 'faq_1',
    category: FaqCategory.orders,
    question: 'How do I track my order status in real time?',
    answer:
        'You can track your live order progress by navigating to "Account > My Orders" and selecting your active order. '
        'You will see step-by-step updates from Order Placed, Confirmed, Packed, Out for Delivery, to Delivered with live status timelines.',
  ),
  const FaqItem(
    id: 'faq_2',
    category: FaqCategory.orders,
    question: 'Can I cancel or modify an order after placing it?',
    answer:
        'You can cancel your order from the Order Details screen before it enters the "Packed" or "Out for Delivery" state. '
        'Once an order is packed or dispatched by the merchant, cancellation requests must be handled by contacting customer support.',
  ),
  const FaqItem(
    id: 'faq_3',
    category: FaqCategory.delivery,
    question: 'How is the delivery charge calculated for my location?',
    answer:
        'Delivery charges are computed dynamically based on the merchant\'s delivery zone rates for your PIN code or distance. '
        'When you select or enter your delivery address at checkout, any applicable delivery fee is transparently shown in the bill summary.',
  ),
  const FaqItem(
    id: 'faq_4',
    category: FaqCategory.delivery,
    question: 'What are the estimated delivery timelines?',
    answer:
        'Standard local deliveries typically arrive within the merchant\'s designated delivery window (usually 30–90 minutes for quick-commerce items or 1–2 business days for standard items). '
        'Estimated delivery times are displayed on the product page and checkout screen.',
  ),
  const FaqItem(
    id: 'faq_5',
    category: FaqCategory.payments,
    question: 'What payment methods are supported?',
    answer:
        'We support Manual / Cash on Delivery (COD) and physical payment upon delivery. '
        'The delivery partner or merchant updates the payment status directly once the payment is completed.',
  ),
  const FaqItem(
    id: 'faq_6',
    category: FaqCategory.payments,
    question: 'How do refunds work for cancelled orders?',
    answer:
        'If an order was prepaid or cancelled before fulfillment, your refund is initiated immediately by the merchant. '
        'Refunds typically reflect in your original payment source within 3–5 business days.',
  ),
  const FaqItem(
    id: 'faq_7',
    category: FaqCategory.returns,
    question: 'What is the return and replacement policy?',
    answer:
        'Eligible items can be returned or replaced within 7 days of delivery if they are damaged, defective, or different from described. '
        'To request a return, go to your order details or submit a query using the Contact Support form with photos of the damaged item.',
  ),
  const FaqItem(
    id: 'faq_8',
    category: FaqCategory.account,
    question: 'How do I add or manage multiple delivery addresses?',
    answer:
        'Go to "Account > Saved Addresses" to add up to 3 saved delivery locations (Home, Work, Other). '
        'You can also select or switch your active delivery address directly from the top bar on the Home Screen.',
  ),
  const FaqItem(
    id: 'faq_9',
    category: FaqCategory.vouchers,
    question: 'How do I apply a discount voucher or coupon code?',
    answer:
        'During checkout, tap the "Apply Voucher" section under Order Summary. '
        'Select an available promo code or type your voucher code to instantly receive a discount on eligible cart items.',
  ),
  const FaqItem(
    id: 'faq_10',
    category: FaqCategory.account,
    question: 'How is my personal data and account information secured?',
    answer:
        'We employ industry-standard encryption protocols and secure authentication tokens to protect your personal information, delivery addresses, and order history.',
  ),
];
