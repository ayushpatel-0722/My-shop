import 'package:flutter/material.dart';

import '../../../app/l10n/l10n_service.dart';

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

/// Localized label for a [FaqCategory] filter chip.
String faqCategoryLabel(FaqCategory category) {
  switch (category) {
    case FaqCategory.all:
      return L10n.current.all3;
    case FaqCategory.orders:
      return L10n.current.ordersTracking;
    case FaqCategory.delivery:
      return L10n.current.deliveryShipping;
    case FaqCategory.payments:
      return L10n.current.paymentsRefunds;
    case FaqCategory.returns:
      return L10n.current.returnsExchanges;
    case FaqCategory.account:
      return L10n.current.accountSecurity;
    case FaqCategory.vouchers:
      return L10n.current.discountsOffers;
  }
}

class FaqItem {
  final String id;
  final String question;
  final String answer;
  final FaqCategory category;

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });
}

/// Comprehensive pre-populated FAQs
/// The built-in FAQ content, evaluated per call so it follows the
/// current language (see `LocaleCubit`).
List<FaqItem> get defaultFaqs => [
  FaqItem(
    id: 'faq_1',
    category: FaqCategory.orders,
    question: L10n.current.howDoITrackMyOrderStatusInRealTime,
    answer:
        L10n
            .current
            .youCanTrackYourLiveOrderProgressByNavigatingToAccountMyOrdersAndSelectingYourActiveOrder +
        L10n
            .current
            .youWillSeeStepByStepUpdatesFromOrderPlacedConfirmedPackedOutForDeliveryToDeliveredWithLiveStatusTimelines,
  ),
  FaqItem(
    id: 'faq_2',
    category: FaqCategory.orders,
    question: L10n.current.canICancelOrModifyAnOrderAfterPlacingIt,
    answer:
        L10n
            .current
            .youCanCancelYourOrderFromTheOrderDetailsScreenBeforeItEntersThePackedOrOutForDeliveryState +
        L10n
            .current
            .onceAnOrderIsPackedOrDispatchedByTheMerchantCancellationRequestsMustBeHandledByContactingCustomerSupport,
  ),
  FaqItem(
    id: 'faq_3',
    category: FaqCategory.delivery,
    question: L10n.current.howIsTheDeliveryChargeCalculatedForMyLocation,
    answer:
        L10n
            .current
            .deliveryChargesAreComputedDynamicallyBasedOnTheMerchantSDeliveryZoneRatesForYourPinCodeOrDistance +
        L10n
            .current
            .whenYouSelectOrEnterYourDeliveryAddressAtCheckoutAnyApplicableDeliveryFeeIsTransparentlyShownInTheBillSummary,
  ),
  FaqItem(
    id: 'faq_4',
    category: FaqCategory.delivery,
    question: L10n.current.whatAreTheEstimatedDeliveryTimelines,
    answer:
        L10n
            .current
            .standardLocalDeliveriesTypicallyArriveWithinTheMerchantSDesignatedDeliveryWindowUsually3090MinutesForQuickCommerceItemsOr12BusinessDaysForStandardItems +
        L10n
            .current
            .estimatedDeliveryTimesAreDisplayedOnTheProductPageAndCheckoutScreen,
  ),
  FaqItem(
    id: 'faq_5',
    category: FaqCategory.payments,
    question: L10n.current.whatPaymentMethodsAreSupported,
    answer:
        L10n
            .current
            .weSupportManualCashOnDeliveryCodAndPhysicalPaymentUponDelivery +
        L10n
            .current
            .theDeliveryPartnerOrMerchantUpdatesThePaymentStatusDirectlyOnceThePaymentIsCompleted,
  ),
  FaqItem(
    id: 'faq_6',
    category: FaqCategory.payments,
    question: L10n.current.howDoRefundsWorkForCancelledOrders,
    answer:
        L10n
            .current
            .ifAnOrderWasPrepaidOrCancelledBeforeFulfillmentYourRefundIsInitiatedImmediatelyByTheMerchant +
        L10n
            .current
            .refundsTypicallyReflectInYourOriginalPaymentSourceWithin35BusinessDays,
  ),
  FaqItem(
    id: 'faq_7',
    category: FaqCategory.returns,
    question: L10n.current.whatIsTheReturnAndReplacementPolicy,
    answer:
        L10n
            .current
            .eligibleItemsCanBeReturnedOrReplacedWithin7DaysOfDeliveryIfTheyAreDamagedDefectiveOrDifferentFromDescribed +
        L10n
            .current
            .toRequestAReturnGoToYourOrderDetailsOrSubmitAQueryUsingTheContactSupportFormWithPhotosOfTheDamagedItem,
  ),
  FaqItem(
    id: 'faq_8',
    category: FaqCategory.account,
    question: L10n.current.howDoIAddOrManageMultipleDeliveryAddresses,
    answer:
        L10n
            .current
            .goToAccountSavedAddressesToAddUpTo3SavedDeliveryLocationsHomeWorkOther +
        L10n
            .current
            .youCanAlsoSelectOrSwitchYourActiveDeliveryAddressDirectlyFromTheTopBarOnTheHomeScreen,
  ),
  FaqItem(
    id: 'faq_9',
    category: FaqCategory.vouchers,
    question: L10n.current.howDoIApplyADiscountVoucherOrCouponCode,
    answer:
        L10n.current.duringCheckoutTapTheApplyVoucherSectionUnderOrderSummary +
        L10n
            .current
            .selectAnAvailablePromoCodeOrTypeYourVoucherCodeToInstantlyReceiveADiscountOnEligibleCartItems,
  ),
  FaqItem(
    id: 'faq_10',
    category: FaqCategory.account,
    question: L10n.current.howIsMyPersonalDataAndAccountInformationSecured,
    answer: L10n
        .current
        .weEmployIndustryStandardEncryptionProtocolsAndSecureAuthenticationTokensToProtectYourPersonalInformationDeliveryAddressesAndOrderHistory,
  ),
];
