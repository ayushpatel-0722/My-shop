import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bazaar'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-tenant commerce platform'**
  String get appSubtitle;

  /// No description provided for @continueAs.
  ///
  /// In en, this message translates to:
  /// **'Continue as...'**
  String get continueAs;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to continue'**
  String get selectRole;

  /// No description provided for @iAmAdmin.
  ///
  /// In en, this message translates to:
  /// **'I\'m an Admin'**
  String get iAmAdmin;

  /// No description provided for @iAmEmployee.
  ///
  /// In en, this message translates to:
  /// **'I\'m an Employee'**
  String get iAmEmployee;

  /// No description provided for @iAmShopper.
  ///
  /// In en, this message translates to:
  /// **'I\'m a Shopper'**
  String get iAmShopper;

  /// No description provided for @createNewCompany.
  ///
  /// In en, this message translates to:
  /// **'Create a New Company'**
  String get createNewCompany;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get selectLanguage;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// No description provided for @companyPassword.
  ///
  /// In en, this message translates to:
  /// **'Company Password'**
  String get companyPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @adminLogin.
  ///
  /// In en, this message translates to:
  /// **'Admin Login'**
  String get adminLogin;

  /// No description provided for @employeeLogin.
  ///
  /// In en, this message translates to:
  /// **'Employee Login'**
  String get employeeLogin;

  /// No description provided for @userLogin.
  ///
  /// In en, this message translates to:
  /// **'Shopper Login'**
  String get userLogin;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Please try again.'**
  String get invalidCredentials;

  /// No description provided for @noAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this number.'**
  String get noAccountFound;

  /// No description provided for @createAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create an account first'**
  String get createAccountPrompt;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products, categories...'**
  String get searchHint;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get buyNow;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully'**
  String get orderPlaced;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get orderStatus;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @packing.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get packing;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get onTheWay;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentPending;

  /// No description provided for @paymentDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get paymentDone;

  /// No description provided for @applyVoucher.
  ///
  /// In en, this message translates to:
  /// **'Apply Voucher'**
  String get applyVoucher;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get invalidCode;

  /// No description provided for @voucherApplied.
  ///
  /// In en, this message translates to:
  /// **'Voucher applied'**
  String get voucherApplied;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// No description provided for @trendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get trendingNow;

  /// No description provided for @brandStores.
  ///
  /// In en, this message translates to:
  /// **'Brand Stores'**
  String get brandStores;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @leaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get leaveReview;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @deliveryNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Delivery not available in this area'**
  String get deliveryNotAvailable;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @notificationCentre.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationCentre;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalAmount;

  /// No description provided for @deliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Delivery charge'**
  String get deliveryCharge;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @aCategoryCannotHaveItselfAsItsParent.
  ///
  /// In en, this message translates to:
  /// **'A category cannot have itself as its parent.'**
  String get aCategoryCannotHaveItselfAsItsParent;

  /// No description provided for @accessPackingHubToVerifyItemsAndMarkOrdersAsPacked.
  ///
  /// In en, this message translates to:
  /// **'Access packing hub to verify items and mark orders as packed.'**
  String get accessPackingHubToVerifyItemsAndMarkOrdersAsPacked;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddress;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add All'**
  String get addAll;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @addDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Add Delivery Charge'**
  String get addDeliveryCharge;

  /// No description provided for @addHighlight.
  ///
  /// In en, this message translates to:
  /// **'Add Highlight'**
  String get addHighlight;

  /// No description provided for @addMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Add Mobile Number'**
  String get addMobileNumber;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addOption;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @addProductOption.
  ///
  /// In en, this message translates to:
  /// **'Add Product Option'**
  String get addProductOption;

  /// No description provided for @addProductVariant.
  ///
  /// In en, this message translates to:
  /// **'Add Product Variant'**
  String get addProductVariant;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add Row'**
  String get addRow;

  /// No description provided for @addSection.
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get addSection;

  /// No description provided for @addSpec.
  ///
  /// In en, this message translates to:
  /// **'Add Spec'**
  String get addSpec;

  /// No description provided for @addVariant.
  ///
  /// In en, this message translates to:
  /// **'Add Variant'**
  String get addVariant;

  /// No description provided for @addAtLeastOneCompleteTitleValueRow.
  ///
  /// In en, this message translates to:
  /// **'Add at least one complete title & value row'**
  String get addAtLeastOneCompleteTitleValueRow;

  /// No description provided for @addDynamicKeyValueSpecificationsEGFabricShelfLifeProcessorStorageOriginAndReturnDeliveryPolicies.
  ///
  /// In en, this message translates to:
  /// **'Add dynamic key-value specifications (e.g. Fabric, Shelf Life, Processor, Storage, Origin) and return/delivery policies.'**
  String
  get addDynamicKeyValueSpecificationsEGFabricShelfLifeProcessorStorageOriginAndReturnDeliveryPolicies;

  /// No description provided for @addMultipleImageUrlsTheFirstImageWillAutomaticallyActAsTheHeroMainProductImage.
  ///
  /// In en, this message translates to:
  /// **'Add multiple image URLs. The first image will automatically act as the Hero / Main product image.'**
  String
  get addMultipleImageUrlsTheFirstImageWillAutomaticallyActAsTheHeroMainProductImage;

  /// No description provided for @addPincodesToDefineDeliveryFeesFreeDeliveryRulesOrMinimumOrderLimits.
  ///
  /// In en, this message translates to:
  /// **'Add pincodes to define delivery fees, free delivery rules, or minimum order limits.'**
  String
  get addPincodesToDefineDeliveryFeesFreeDeliveryRulesOrMinimumOrderLimits;

  /// No description provided for @addProductsToYourCartAfterSigningInToContinueCheckout.
  ///
  /// In en, this message translates to:
  /// **'Add products to your cart after signing in to continue checkout.'**
  String get addProductsToYourCartAfterSigningInToContinueCheckout;

  /// No description provided for @addToCategory.
  ///
  /// In en, this message translates to:
  /// **'Add to Category'**
  String get addToCategory;

  /// No description provided for @addYourFirstProductToStartSelling.
  ///
  /// In en, this message translates to:
  /// **'Add your first product to start selling.'**
  String get addYourFirstProductToStartSelling;

  /// No description provided for @addressDetails.
  ///
  /// In en, this message translates to:
  /// **'Address Details'**
  String get addressDetails;

  /// No description provided for @addressLine1HouseFlatBlock.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1 (House / Flat / Block) *'**
  String get addressLine1HouseFlatBlock;

  /// No description provided for @addressLine2StreetArea.
  ///
  /// In en, this message translates to:
  /// **'Address Line 2 (Street / Area)'**
  String get addressLine2StreetArea;

  /// No description provided for @addressDeleted.
  ///
  /// In en, this message translates to:
  /// **'Address deleted'**
  String get addressDeleted;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminConsole.
  ///
  /// In en, this message translates to:
  /// **'Admin Console'**
  String get adminConsole;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminEmail.
  ///
  /// In en, this message translates to:
  /// **'Admin email'**
  String get adminEmail;

  /// No description provided for @adminName.
  ///
  /// In en, this message translates to:
  /// **'Admin name'**
  String get adminName;

  /// No description provided for @adminNameEmailAndPasswordAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin name, email, and password are required.'**
  String get adminNameEmailAndPasswordAreRequired;

  /// No description provided for @adminPasswordMustBeAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Admin password must be at least 6 characters.'**
  String get adminPasswordMustBeAtLeast6Characters;

  /// No description provided for @adminPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Admin passwords do not match.'**
  String get adminPasswordsDoNotMatch;

  /// No description provided for @allActiveCoupons.
  ///
  /// In en, this message translates to:
  /// **'All Active Coupons'**
  String get allActiveCoupons;

  /// No description provided for @allDetails.
  ///
  /// In en, this message translates to:
  /// **'All Details'**
  String get allDetails;

  /// No description provided for @allShopsStores.
  ///
  /// In en, this message translates to:
  /// **'All Shops & Stores'**
  String get allShopsStores;

  /// No description provided for @alreadyHaveAnAccountLogIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log In'**
  String get alreadyHaveAnAccountLogIn;

  /// No description provided for @appliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get appliesTo;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @assignAnExistingParentCategoryInTheSameCompanyForNesting.
  ///
  /// In en, this message translates to:
  /// **'Assign an existing parent category in the same company for nesting. '**
  String get assignAnExistingParentCategoryInTheSameCompanyForNesting;

  /// No description provided for @assignDeliveryRidersAndDispatchOrdersForFulfillment.
  ///
  /// In en, this message translates to:
  /// **'Assign delivery riders and dispatch orders for fulfillment.'**
  String get assignDeliveryRidersAndDispatchOrdersForFulfillment;

  /// No description provided for @assignWorkflowResponsibilitiesNoteStaffPermissionsNeverIncludeManualOrderStatusChanges.
  ///
  /// In en, this message translates to:
  /// **'Assign workflow responsibilities. Note: Staff permissions never include manual order-status changes.'**
  String
  get assignWorkflowResponsibilitiesNoteStaffPermissionsNeverIncludeManualOrderStatusChanges;

  /// No description provided for @availableInventoryUnits.
  ///
  /// In en, this message translates to:
  /// **'Available inventory units'**
  String get availableInventoryUnits;

  /// No description provided for @backfillOrderingForOldCategories.
  ///
  /// In en, this message translates to:
  /// **'Backfill ordering for old categories'**
  String get backfillOrderingForOldCategories;

  /// No description provided for @baseMeasurementType.
  ///
  /// In en, this message translates to:
  /// **'Base Measurement Type'**
  String get baseMeasurementType;

  /// No description provided for @baseSkuProductCode.
  ///
  /// In en, this message translates to:
  /// **'Base SKU / Product Code *'**
  String get baseSkuProductCode;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @bottle1Bottle2Bottles4Bottles6Bottles.
  ///
  /// In en, this message translates to:
  /// **'Bottle (1 bottle, 2 bottles, 4 bottles, 6 bottles)'**
  String get bottle1Bottle2Bottles4Bottles6Bottles;

  /// No description provided for @box1Box2Boxes5Boxes10Boxes.
  ///
  /// In en, this message translates to:
  /// **'Box (1 box, 2 boxes, 5 boxes, 10 boxes)'**
  String get box1Box2Boxes5Boxes10Boxes;

  /// No description provided for @byContinuingYouAgreeToOurTermsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms & Privacy Policy'**
  String get byContinuingYouAgreeToOurTermsPrivacyPolicy;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @cancelThisOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelThisOrder;

  /// No description provided for @categoriesShops.
  ///
  /// In en, this message translates to:
  /// **'Categories & Shops'**
  String get categoriesShops;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryIconImageUrlOrEmoji.
  ///
  /// In en, this message translates to:
  /// **'Category Icon (Image URL or Emoji)'**
  String get categoryIconImageUrlOrEmoji;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name *'**
  String get categoryName;

  /// No description provided for @categoryOrderingBackfilled.
  ///
  /// In en, this message translates to:
  /// **'Category ordering backfilled.'**
  String get categoryOrderingBackfilled;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changeClear.
  ///
  /// In en, this message translates to:
  /// **'Change & Clear'**
  String get changeClear;

  /// No description provided for @changeSectionType.
  ///
  /// In en, this message translates to:
  /// **'Change Section Type'**
  String get changeSectionType;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City *'**
  String get city;

  /// No description provided for @classificationType.
  ///
  /// In en, this message translates to:
  /// **'Classification / Type *'**
  String get classificationType;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// No description provided for @clearSearchToReorder.
  ///
  /// In en, this message translates to:
  /// **'Clear search to reorder'**
  String get clearSearchToReorder;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @clothingSizeSMLXlXxl.
  ///
  /// In en, this message translates to:
  /// **'Clothing Size (S, M, L, XL, XXL)'**
  String get clothingSizeSMLXlXxl;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code *'**
  String get code;

  /// No description provided for @codeFestive50.
  ///
  /// In en, this message translates to:
  /// **'Code: FESTIVE50'**
  String get codeFestive50;

  /// No description provided for @colorNavyCrimsonOliveGold.
  ///
  /// In en, this message translates to:
  /// **'Color (Navy, Crimson, Olive, Gold)'**
  String get colorNavyCrimsonOliveGold;

  /// No description provided for @colorOptional.
  ///
  /// In en, this message translates to:
  /// **'Color (Optional)'**
  String get colorOptional;

  /// No description provided for @colorRedBlueBlackWhiteGreen.
  ///
  /// In en, this message translates to:
  /// **'Color (Red, Blue, Black, White, Green)'**
  String get colorRedBlueBlackWhiteGreen;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @companyBannerUrl.
  ///
  /// In en, this message translates to:
  /// **'Company Banner URL'**
  String get companyBannerUrl;

  /// No description provided for @companyBrandingImages.
  ///
  /// In en, this message translates to:
  /// **'Company Branding & Images'**
  String get companyBrandingImages;

  /// No description provided for @companyLogoUrl.
  ///
  /// In en, this message translates to:
  /// **'Company Logo URL'**
  String get companyLogoUrl;

  /// No description provided for @companyStorefrontProfileImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Company Storefront / Profile Image URL'**
  String get companyStorefrontProfileImageUrl;

  /// No description provided for @companyNameAndPasswordAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Company name and password are required.'**
  String get companyNameAndPasswordAreRequired;

  /// No description provided for @compensationSalary.
  ///
  /// In en, this message translates to:
  /// **'Compensation & Salary'**
  String get compensationSalary;

  /// No description provided for @configureCustomizableOptionTypesEGSizeColorWeightStorageAndAutomaticallyGenerateCartesianCombinationsWithDistinctSkuStockAndPriceOverrides.
  ///
  /// In en, this message translates to:
  /// **'Configure customizable option types (e.g. Size, Color, Weight, Storage) and automatically generate Cartesian combinations with distinct SKU, stock, and price overrides.'**
  String
  get configureCustomizableOptionTypesEGSizeColorWeightStorageAndAutomaticallyGenerateCartesianCombinationsWithDistinctSkuStockAndPriceOverrides;

  /// No description provided for @configureHierarchyCatalogClassificationAndAssignedProducts.
  ///
  /// In en, this message translates to:
  /// **'Configure hierarchy, catalog classification, and assigned products.'**
  String get configureHierarchyCatalogClassificationAndAssignedProducts;

  /// No description provided for @configuredOptionSets.
  ///
  /// In en, this message translates to:
  /// **'Configured Option Sets:'**
  String get configuredOptionSets;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @contactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact Details'**
  String get contactDetails;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @couldNotSendOtpPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not send OTP. Please try again.'**
  String get couldNotSendOtpPleaseTryAgain;

  /// No description provided for @couldNotSendOtpPleaseVerifyYourNumberOrTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not send OTP. Please verify your number or try again.'**
  String get couldNotSendOtpPleaseVerifyYourNumberOrTryAgain;

  /// No description provided for @createOfferBanner.
  ///
  /// In en, this message translates to:
  /// **'Create Offer Banner'**
  String get createOfferBanner;

  /// No description provided for @createVoucher.
  ///
  /// In en, this message translates to:
  /// **'Create voucher'**
  String get createVoucher;

  /// No description provided for @createYourFirstCategoryAndAssignProductsToOrganizeYourStore.
  ///
  /// In en, this message translates to:
  /// **'Create your first category and assign products to organize your store.'**
  String get createYourFirstCategoryAndAssignProductsToOrganizeYourStore;

  /// No description provided for @crossSell.
  ///
  /// In en, this message translates to:
  /// **'Cross-sell'**
  String get crossSell;

  /// No description provided for @curated.
  ///
  /// In en, this message translates to:
  /// **'Curated'**
  String get curated;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @customerDetails2.
  ///
  /// In en, this message translates to:
  /// **'Customer details'**
  String get customerDetails2;

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get defaultBadge;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @default2.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default2;

  /// No description provided for @defineStaffCompensationPackageAndPaymentFrequency.
  ///
  /// In en, this message translates to:
  /// **'Define staff compensation package and payment frequency.'**
  String get defineStaffCompensationPackageAndPaymentFrequency;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAddress.
  ///
  /// In en, this message translates to:
  /// **'Delete Address'**
  String get deleteAddress;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @deleteDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Delete Delivery Charge'**
  String get deleteDeliveryCharge;

  /// No description provided for @deleteEmployee.
  ///
  /// In en, this message translates to:
  /// **'Delete Employee'**
  String get deleteEmployee;

  /// No description provided for @deleteEmployeeAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Employee Account'**
  String get deleteEmployeeAccount;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @deleteSection.
  ///
  /// In en, this message translates to:
  /// **'Delete Section'**
  String get deleteSection;

  /// No description provided for @deleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get deleteRow;

  /// No description provided for @deleteSection2.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get deleteSection2;

  /// No description provided for @deleteVoucher.
  ///
  /// In en, this message translates to:
  /// **'Delete voucher'**
  String get deleteVoucher;

  /// No description provided for @deleteVoucher2.
  ///
  /// In en, this message translates to:
  /// **'Delete voucher?'**
  String get deleteVoucher2;

  /// No description provided for @deliveryReturnPolicy.
  ///
  /// In en, this message translates to:
  /// **'Delivery & Return Policy'**
  String get deliveryReturnPolicy;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @deliveryType.
  ///
  /// In en, this message translates to:
  /// **'Delivery Type'**
  String get deliveryType;

  /// No description provided for @deliveryAddress2.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress2;

  /// No description provided for @deliveryTypes.
  ///
  /// In en, this message translates to:
  /// **'Delivery types'**
  String get deliveryTypes;

  /// No description provided for @deliveryWillAlwaysBeFree0ForAllOrdersToThisPincode.
  ///
  /// In en, this message translates to:
  /// **'Delivery will always be FREE (₹0) for all orders to this pincode.'**
  String get deliveryWillAlwaysBeFree0ForAllOrdersToThisPincode;

  /// No description provided for @descriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Description / Details'**
  String get descriptionDetails;

  /// No description provided for @descriptionShownOnTheCategoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Description shown on the category header...'**
  String get descriptionShownOnTheCategoryHeader;

  /// No description provided for @designationRole.
  ///
  /// In en, this message translates to:
  /// **'Designation / Role *'**
  String get designationRole;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// No description provided for @discountType.
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get discountType;

  /// No description provided for @dragTheHandleToSetTheOrderCustomersSee.
  ///
  /// In en, this message translates to:
  /// **'Drag the ≡ handle to set the order customers see.'**
  String get dragTheHandleToSetTheOrderCustomersSee;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @editDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Edit Delivery Charge'**
  String get editDeliveryCharge;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployee;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @editStockPriceOverride.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock & Price Override'**
  String get editStockPriceOverride;

  /// No description provided for @editVoucher.
  ///
  /// In en, this message translates to:
  /// **'Edit voucher'**
  String get editVoucher;

  /// No description provided for @emergencyContactCertificationsQualifications.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact, certifications, qualifications...'**
  String get emergencyContactCertificationsQualifications;

  /// No description provided for @employeePortal.
  ///
  /// In en, this message translates to:
  /// **'Employee Portal'**
  String get employeePortal;

  /// No description provided for @enter6DigitDeliveryPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit delivery pincode'**
  String get enter6DigitDeliveryPincode;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Mobile Number'**
  String get enterMobileNumber;

  /// No description provided for @enterAValid10DigitIndianMobileNumberEG9876543210.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number (e.g. 9876543210)'**
  String get enterAValid10DigitIndianMobileNumberEG9876543210;

  /// No description provided for @enterImageUrlOrEmojiEG.
  ///
  /// In en, this message translates to:
  /// **'Enter image URL or emoji (e.g. 🛍️)'**
  String get enterImageUrlOrEmojiEG;

  /// No description provided for @enterYourAddressForAccurateDelivery.
  ///
  /// In en, this message translates to:
  /// **'Enter your address for accurate delivery'**
  String get enterYourAddressForAccurateDelivery;

  /// No description provided for @estimatedDeliveryTimeEta.
  ///
  /// In en, this message translates to:
  /// **'Estimated Delivery Time (ETA)'**
  String get estimatedDeliveryTimeEta;

  /// No description provided for @estimatedDeliveryTimeOptional.
  ///
  /// In en, this message translates to:
  /// **'Estimated Delivery Time (Optional)'**
  String get estimatedDeliveryTimeOptional;

  /// No description provided for @excelXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (.xlsx)'**
  String get excelXlsx;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get expiryDate;

  /// No description provided for @exploreProductsAndPlaceYourFirstOrderToday.
  ///
  /// In en, this message translates to:
  /// **'Explore products and place your first order today!'**
  String get exploreProductsAndPlaceYourFirstOrderToday;

  /// No description provided for @exportCatalogSheet.
  ///
  /// In en, this message translates to:
  /// **'Export catalog sheet'**
  String get exportCatalogSheet;

  /// No description provided for @externalUrl.
  ///
  /// In en, this message translates to:
  /// **'External URL'**
  String get externalUrl;

  /// No description provided for @faqsCustomerHelplineQueryForm.
  ///
  /// In en, this message translates to:
  /// **'FAQs, customer helpline & query form'**
  String get faqsCustomerHelplineQueryForm;

  /// No description provided for @freeDelivery.
  ///
  /// In en, this message translates to:
  /// **'FREE DELIVERY'**
  String get freeDelivery;

  /// No description provided for @failedToSaveAddressPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to save address. Please try again.'**
  String get failedToSaveAddressPleaseTryAgain;

  /// No description provided for @failedToSaveAddressTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to save address. Try again.'**
  String get failedToSaveAddressTryAgain;

  /// No description provided for @failedToSaveMobileNumberTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to save mobile number. Try again.'**
  String get failedToSaveMobileNumberTryAgain;

  /// No description provided for @fallbackStrategy.
  ///
  /// In en, this message translates to:
  /// **'Fallback strategy'**
  String get fallbackStrategy;

  /// No description provided for @featuredRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Featured Recommendation'**
  String get featuredRecommendation;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @firstAdminAccount.
  ///
  /// In en, this message translates to:
  /// **'First Admin Account'**
  String get firstAdminAccount;

  /// No description provided for @firstOrderOnly.
  ///
  /// In en, this message translates to:
  /// **'First order only'**
  String get firstOrderOnly;

  /// No description provided for @fixedPaidCharge.
  ///
  /// In en, this message translates to:
  /// **'Fixed / Paid Charge'**
  String get fixedPaidCharge;

  /// No description provided for @flagThisProductToAppearInTheRecommendationsEngineCarousel.
  ///
  /// In en, this message translates to:
  /// **'Flag this product to appear in the recommendations engine carousel.'**
  String get flagThisProductToAppearInTheRecommendationsEngineCarousel;

  /// No description provided for @flat50OffFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Flat 50% Off + Free Delivery'**
  String get flat50OffFreeDelivery;

  /// No description provided for @forDeliveryTrackingOrderSmsUpdates.
  ///
  /// In en, this message translates to:
  /// **'For delivery tracking & order SMS updates'**
  String get forDeliveryTrackingOrderSmsUpdates;

  /// No description provided for @forInstantOrderUpdatesDeliverySms.
  ///
  /// In en, this message translates to:
  /// **'For instant order updates & delivery SMS'**
  String get forInstantOrderUpdatesDeliverySms;

  /// No description provided for @freeDelivery2.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery'**
  String get freeDelivery2;

  /// No description provided for @freeDeliveryForOrdersAboveOptional.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery for Orders Above (₹) (Optional)'**
  String get freeDeliveryForOrdersAboveOptional;

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get frequentlyAskedQuestions;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fullName;

  /// No description provided for @gatesLoginToScheduledWorkingHoursWhenDisabledTheEmployeeCannotLogIntoTheMobileApp.
  ///
  /// In en, this message translates to:
  /// **'Gates login to scheduled working hours. When disabled, the employee cannot log into the mobile app.'**
  String
  get gatesLoginToScheduledWorkingHoursWhenDisabledTheEmployeeCannotLogIntoTheMobileApp;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @generateMatrix.
  ///
  /// In en, this message translates to:
  /// **'Generate Matrix'**
  String get generateMatrix;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @grandFestiveMegaSale.
  ///
  /// In en, this message translates to:
  /// **'Grand Festive Mega Sale'**
  String get grandFestiveMegaSale;

  /// No description provided for @greenleafOrganics.
  ///
  /// In en, this message translates to:
  /// **'GreenLeaf Organics'**
  String get greenleafOrganics;

  /// No description provided for @haveASpecificIssue.
  ///
  /// In en, this message translates to:
  /// **'Have a specific issue?'**
  String get haveASpecificIssue;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @heroMain.
  ///
  /// In en, this message translates to:
  /// **'Hero / Main'**
  String get heroMain;

  /// No description provided for @hierarchyNesting.
  ///
  /// In en, this message translates to:
  /// **'Hierarchy & Nesting'**
  String get hierarchyNesting;

  /// No description provided for @homeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Home Delivery'**
  String get homeDelivery;

  /// No description provided for @homeDelivery2.
  ///
  /// In en, this message translates to:
  /// **'Home delivery'**
  String get homeDelivery2;

  /// No description provided for @houseFlatFloorNo.
  ///
  /// In en, this message translates to:
  /// **'House / Flat / Floor No. *'**
  String get houseFlatFloorNo;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'INVOICE'**
  String get invoice;

  /// No description provided for @iconVisuals.
  ///
  /// In en, this message translates to:
  /// **'Icon & Visuals'**
  String get iconVisuals;

  /// No description provided for @imageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// No description provided for @inStock2.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock2;

  /// No description provided for @incorrectCompanyPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect company password.'**
  String get incorrectCompanyPassword;

  /// No description provided for @initialPassword.
  ///
  /// In en, this message translates to:
  /// **'Initial Password *'**
  String get initialPassword;

  /// No description provided for @invalidOtpPleaseCheckTheCodeAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please check the code and try again.'**
  String get invalidOtpPleaseCheckTheCodeAndTryAgain;

  /// No description provided for @invalidOtpPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get invalidOtpPleaseTryAgain;

  /// No description provided for @invalidParentSelectingADescendantCategoryCreatesACycle.
  ///
  /// In en, this message translates to:
  /// **'Invalid parent: Selecting a descendant category creates a cycle.'**
  String get invalidParentSelectingADescendantCategoryCreatesACycle;

  /// No description provided for @inventoryManagementCanmanageinventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management (canManageInventory)'**
  String get inventoryManagementCanmanageinventory;

  /// No description provided for @issueCategory.
  ///
  /// In en, this message translates to:
  /// **'Issue Category *'**
  String get issueCategory;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get keepEditing;

  /// No description provided for @keepTrackOfYourActiveDeliveriesAndPastPurchases.
  ///
  /// In en, this message translates to:
  /// **'Keep track of your active deliveries and past purchases.'**
  String get keepTrackOfYourActiveDeliveriesAndPastPurchases;

  /// No description provided for @limitedTimeOffer.
  ///
  /// In en, this message translates to:
  /// **'LIMITED TIME OFFER'**
  String get limitedTimeOffer;

  /// No description provided for @landmarkOptional.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get landmarkOptional;

  /// No description provided for @latestInvoicePdf.
  ///
  /// In en, this message translates to:
  /// **'Latest invoice PDF'**
  String get latestInvoicePdf;

  /// No description provided for @loadingCategory.
  ///
  /// In en, this message translates to:
  /// **'Loading Category...'**
  String get loadingCategory;

  /// No description provided for @loadingEmployee.
  ///
  /// In en, this message translates to:
  /// **'Loading Employee...'**
  String get loadingEmployee;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Login Email *'**
  String get loginEmail;

  /// No description provided for @longDescriptionShownAsAParagraph.
  ///
  /// In en, this message translates to:
  /// **'Long description shown as a paragraph...'**
  String get longDescriptionShownAsAParagraph;

  /// No description provided for @mrpOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'MRP / Original Price (₹) *'**
  String get mrpOriginalPrice;

  /// No description provided for @makeHero.
  ///
  /// In en, this message translates to:
  /// **'Make Hero'**
  String get makeHero;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @manageDeliveryLocations03.
  ///
  /// In en, this message translates to:
  /// **'Manage delivery locations (0/3)'**
  String get manageDeliveryLocations03;

  /// No description provided for @manageProductsCategoriesOrders.
  ///
  /// In en, this message translates to:
  /// **'Manage products, categories & orders'**
  String get manageProductsCategoriesOrders;

  /// No description provided for @manageStaffAccountDesignationSalaryAndOperationalAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage staff account, designation, salary, and operational access.'**
  String get manageStaffAccountDesignationSalaryAndOperationalAccess;

  /// No description provided for @manualOfflinePayment.
  ///
  /// In en, this message translates to:
  /// **'Manual / Offline Payment'**
  String get manualOfflinePayment;

  /// No description provided for @marketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// No description provided for @maximum3AddressesAllowedPleaseEditOrRemoveAnAddress.
  ///
  /// In en, this message translates to:
  /// **'Maximum 3 addresses allowed. Please edit or remove an address.'**
  String get maximum3AddressesAllowedPleaseEditOrRemoveAnAddress;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @minimum6Characters.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get minimum6Characters;

  /// No description provided for @minimumOrderAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum order amount (₹)'**
  String get minimumOrderAmount;

  /// No description provided for @mobileNumber2.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number *'**
  String get mobileNumber2;

  /// No description provided for @mobileNumberSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Mobile number saved successfully!'**
  String get mobileNumberSavedSuccessfully;

  /// No description provided for @monthlyMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly (₹/month)'**
  String get monthlyMonth;

  /// No description provided for @monthlyOrderReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly order report'**
  String get monthlyOrderReport;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Move to Wishlist?'**
  String get moveToWishlist;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @multiTenantCommerce.
  ///
  /// In en, this message translates to:
  /// **'Multi-tenant commerce'**
  String get multiTenantCommerce;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @nameOrSku.
  ///
  /// In en, this message translates to:
  /// **'Name or SKU'**
  String get nameOrSku;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No Orders Yet'**
  String get noOrdersYet;

  /// No description provided for @noAdminsYet.
  ///
  /// In en, this message translates to:
  /// **'No admins yet'**
  String get noAdminsYet;

  /// No description provided for @noCategoriesAtThisLevel.
  ///
  /// In en, this message translates to:
  /// **'No categories at this level'**
  String get noCategoriesAtThisLevel;

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategoriesFound;

  /// No description provided for @noCategoriesFoundForThisStore.
  ///
  /// In en, this message translates to:
  /// **'No categories found for this store.'**
  String get noCategoriesFoundForThisStore;

  /// No description provided for @noCategoriesMatchThisSearch.
  ///
  /// In en, this message translates to:
  /// **'No categories match this search'**
  String get noCategoriesMatchThisSearch;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// No description provided for @noCompanyIdentifiedPleaseEnsureYouAreLoggedInToYourCompany.
  ///
  /// In en, this message translates to:
  /// **'No company identified. Please ensure you are logged in to your company.'**
  String get noCompanyIdentifiedPleaseEnsureYouAreLoggedInToYourCompany;

  /// No description provided for @noCompanyScopeFoundForCurrentAdmin.
  ///
  /// In en, this message translates to:
  /// **'No company scope found for current admin.'**
  String get noCompanyScopeFoundForCurrentAdmin;

  /// No description provided for @noDeliveryChargesMatchThisPincode.
  ///
  /// In en, this message translates to:
  /// **'No delivery charges match this pincode'**
  String get noDeliveryChargesMatchThisPincode;

  /// No description provided for @noDeliveryPincodesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No delivery pincodes configured'**
  String get noDeliveryPincodesConfigured;

  /// No description provided for @noDetailSectionsYetTapAddSection.
  ///
  /// In en, this message translates to:
  /// **'No detail sections yet — tap \"Add Section\".'**
  String get noDetailSectionsYetTapAddSection;

  /// No description provided for @noEmployeesProvisioned.
  ///
  /// In en, this message translates to:
  /// **'No employees provisioned'**
  String get noEmployeesProvisioned;

  /// No description provided for @noExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get noExpiry;

  /// No description provided for @noHighlightsYetTapAddHighlight.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet — tap \"Add Highlight\".'**
  String get noHighlightsYetTapAddHighlight;

  /// No description provided for @noMatchingFaqsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching FAQs found'**
  String get noMatchingFaqsFound;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @noOfferBanners.
  ///
  /// In en, this message translates to:
  /// **'No offer banners'**
  String get noOfferBanners;

  /// No description provided for @noOrdersToInvoiceYet.
  ///
  /// In en, this message translates to:
  /// **'No orders to invoice yet'**
  String get noOrdersToInvoiceYet;

  /// No description provided for @noOrdersWithThisStatus.
  ///
  /// In en, this message translates to:
  /// **'No orders with this status'**
  String get noOrdersWithThisStatus;

  /// No description provided for @noPackingTasksAssigned.
  ///
  /// In en, this message translates to:
  /// **'No packing tasks assigned'**
  String get noPackingTasksAssigned;

  /// No description provided for @noPinnedRecommendationsUsingBestSellers.
  ///
  /// In en, this message translates to:
  /// **'No pinned recommendations — using best-sellers'**
  String get noPinnedRecommendationsUsingBestSellers;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @noProductsFoundForThisStore.
  ///
  /// In en, this message translates to:
  /// **'No products found for this store.'**
  String get noProductsFoundForThisStore;

  /// No description provided for @noProductsMatchTheseFilters.
  ///
  /// In en, this message translates to:
  /// **'No products match these filters'**
  String get noProductsMatchTheseFilters;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @noSavedAddressesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get noSavedAddressesYet;

  /// No description provided for @noShopsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No shops available'**
  String get noShopsAvailable;

  /// No description provided for @noShopsRegisteredYet.
  ///
  /// In en, this message translates to:
  /// **'No shops registered yet'**
  String get noShopsRegisteredYet;

  /// No description provided for @noVariantsConfiguredSingleStandardSkuTapAddOptionToDefineDimensionsThenGenerateMatrix.
  ///
  /// In en, this message translates to:
  /// **'No variants configured (single standard SKU). Tap \"Add Option\" to define dimensions, then \"Generate Matrix\".'**
  String
  get noVariantsConfiguredSingleStandardSkuTapAddOptionToDefineDimensionsThenGenerateMatrix;

  /// No description provided for @noVouchersAvailableRightNow.
  ///
  /// In en, this message translates to:
  /// **'No vouchers available right now.'**
  String get noVouchersAvailableRightNow;

  /// No description provided for @noneTopLevelCategory.
  ///
  /// In en, this message translates to:
  /// **'None (Top-Level Category)'**
  String get noneTopLevelCategory;

  /// No description provided for @notesQualifications.
  ///
  /// In en, this message translates to:
  /// **'Notes & Qualifications'**
  String get notesQualifications;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get nothingHere;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @otp.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get otp;

  /// No description provided for @offersFromThisStore.
  ///
  /// In en, this message translates to:
  /// **'Offers from this store'**
  String get offersFromThisStore;

  /// No description provided for @onlyShoppersWithoutAPreviousOrder.
  ///
  /// In en, this message translates to:
  /// **'Only shoppers without a previous order'**
  String get onlyShoppersWithoutAPreviousOrder;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @operationalPermissions.
  ///
  /// In en, this message translates to:
  /// **'Operational Permissions'**
  String get operationalPermissions;

  /// No description provided for @optionName.
  ///
  /// In en, this message translates to:
  /// **'Option Name *'**
  String get optionName;

  /// No description provided for @optionValuesCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Option Values (comma separated) *'**
  String get optionValuesCommaSeparated;

  /// No description provided for @orderDispatchCandispatch.
  ///
  /// In en, this message translates to:
  /// **'Order Dispatch (canDispatch)'**
  String get orderDispatchCandispatch;

  /// No description provided for @orderPackingCanpack.
  ///
  /// In en, this message translates to:
  /// **'Order Packing (canPack)'**
  String get orderPackingCanpack;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @orderUpdatesPromoAlerts.
  ///
  /// In en, this message translates to:
  /// **'Order updates & promo alerts'**
  String get orderUpdatesPromoAlerts;

  /// No description provided for @ordersTrackingStatus.
  ///
  /// In en, this message translates to:
  /// **'Orders, tracking & status'**
  String get ordersTrackingStatus;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @outOfStockFinishedProductWillShowAsSoldOutOnTheStorefrontUntilRestocked.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock / Finished: Product will show as sold out on the storefront until restocked.'**
  String
  get outOfStockFinishedProductWillShowAsSoldOutOnTheStorefrontUntilRestocked;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @png.
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get png;

  /// No description provided for @pack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get pack;

  /// No description provided for @pack1Pack2Packs5Packs10Packs.
  ///
  /// In en, this message translates to:
  /// **'Pack (1 pack, 2 packs, 5 packs, 10 packs)'**
  String get pack1Pack2Packs5Packs10Packs;

  /// No description provided for @packingDoneNotifiedAdmin.
  ///
  /// In en, this message translates to:
  /// **'Packing done — notified Admin'**
  String get packingDoneNotifiedAdmin;

  /// No description provided for @packingOrderQueueFulfillment.
  ///
  /// In en, this message translates to:
  /// **'Packing, order queue & fulfillment'**
  String get packingOrderQueueFulfillment;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent Category'**
  String get parentCategory;

  /// No description provided for @pauseInsteadOfDeletingACampaign.
  ///
  /// In en, this message translates to:
  /// **'Pause instead of deleting a campaign'**
  String get pauseInsteadOfDeletingACampaign;

  /// No description provided for @payDirectlyCashUpiOnDeliveryOrPickupPaymentStatusWillDefaultToPendingAndCanBeMarkedAsDoneByTheAdmin.
  ///
  /// In en, this message translates to:
  /// **'Pay directly (Cash/UPI on delivery or pickup). Payment status will default to Pending and can be marked as Done by the admin.'**
  String
  get payDirectlyCashUpiOnDeliveryOrPickupPaymentStatusWillDefaultToPendingAndCanBeMarkedAsDoneByTheAdmin;

  /// No description provided for @perShopperLimit.
  ///
  /// In en, this message translates to:
  /// **'Per shopper limit'**
  String get perShopperLimit;

  /// No description provided for @pick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get pick;

  /// No description provided for @pickupFrom.
  ///
  /// In en, this message translates to:
  /// **'Pickup From'**
  String get pickupFrom;

  /// No description provided for @pinAProduct.
  ///
  /// In en, this message translates to:
  /// **'Pin a product'**
  String get pinAProduct;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode *'**
  String get pincode;

  /// No description provided for @pincodeInformation.
  ///
  /// In en, this message translates to:
  /// **'Pincode Information'**
  String get pincodeInformation;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @pleaseAddAtLeastOneOptionFirstToGenerateCombinations.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one Option first to generate combinations.'**
  String get pleaseAddAtLeastOneOptionFirstToGenerateCombinations;

  /// No description provided for @pleaseCheckAllRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please check all required fields.'**
  String get pleaseCheckAllRequiredFields;

  /// No description provided for @pleaseCompleteTheProductHighlightsAndAllDetailsSections.
  ///
  /// In en, this message translates to:
  /// **'Please complete the Product Highlights and All Details sections.'**
  String get pleaseCompleteTheProductHighlightsAndAllDetailsSections;

  /// No description provided for @pleaseCompleteYourProfileNameMobileBeforePlacingAnOrder.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile (name & mobile) before placing an order.'**
  String get pleaseCompleteYourProfileNameMobileBeforePlacingAnOrder;

  /// No description provided for @pleaseEnterAValid6DigitPincode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit pincode'**
  String get pleaseEnterAValid6DigitPincode;

  /// No description provided for @pleaseEnterAValidHttpOrHttpsImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid HTTP or HTTPS image URL'**
  String get pleaseEnterAValidHttpOrHttpsImageUrl;

  /// No description provided for @pleaseEnterAdminEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter admin email and password.'**
  String get pleaseEnterAdminEmailAndPassword;

  /// No description provided for @pleaseEnterCompanyNameAndCompanyPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter company name and company password.'**
  String get pleaseEnterCompanyNameAndCompanyPassword;

  /// No description provided for @pleaseEnterThe6DigitOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit OTP'**
  String get pleaseEnterThe6DigitOtp;

  /// No description provided for @pleaseEnterTheRequiredPrimaryProductDetailsAboveToUnlockVariantOptionsAndMatrixGeneration.
  ///
  /// In en, this message translates to:
  /// **'Please enter the required primary product details above to unlock variant options and matrix generation:'**
  String
  get pleaseEnterTheRequiredPrimaryProductDetailsAboveToUnlockVariantOptionsAndMatrixGeneration;

  /// No description provided for @pleaseEnterYourMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number'**
  String get pleaseEnterYourMobileNumber;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @pleaseSelectAtLeastOneProductForTheCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one product for the category'**
  String get pleaseSelectAtLeastOneProductForTheCategory;

  /// No description provided for @popularSearches.
  ///
  /// In en, this message translates to:
  /// **'Popular Searches'**
  String get popularSearches;

  /// No description provided for @postalPincode.
  ///
  /// In en, this message translates to:
  /// **'Postal Pincode *'**
  String get postalPincode;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price (₹) *'**
  String get price;

  /// No description provided for @pricingChargeRules.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Charge Rules'**
  String get pricingChargeRules;

  /// No description provided for @pricingMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Measurement'**
  String get pricingMeasurement;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @productAssignment.
  ///
  /// In en, this message translates to:
  /// **'Product Assignment'**
  String get productAssignment;

  /// No description provided for @productBaseColorOptional.
  ///
  /// In en, this message translates to:
  /// **'Product Base Color (Optional)'**
  String get productBaseColorOptional;

  /// No description provided for @productGallery.
  ///
  /// In en, this message translates to:
  /// **'Product Gallery'**
  String get productGallery;

  /// No description provided for @productHighlights.
  ///
  /// In en, this message translates to:
  /// **'Product Highlights'**
  String get productHighlights;

  /// No description provided for @productId.
  ///
  /// In en, this message translates to:
  /// **'Product ID'**
  String get productId;

  /// No description provided for @productSpecification.
  ///
  /// In en, this message translates to:
  /// **'Product Specification'**
  String get productSpecification;

  /// No description provided for @productTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Title *'**
  String get productTitle;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productNotFound;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @productsAssignedToThisCategoryOrItsSubCategoriesWillShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Products assigned to this category (or its sub-categories) will show up here.'**
  String get productsAssignedToThisCategoryOrItsSubCategoriesWillShowUpHere;

  /// No description provided for @promoCodeFestive50CopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Promo Code FESTIVE50 copied to clipboard!'**
  String get promoCodeFestive50CopiedToClipboard;

  /// No description provided for @provisionEmployee.
  ///
  /// In en, this message translates to:
  /// **'Provision Employee'**
  String get provisionEmployee;

  /// No description provided for @provisionStaffAccountsWithCustomDesignationsSalaryAndOperationalAccess.
  ///
  /// In en, this message translates to:
  /// **'Provision staff accounts with custom designations, salary, and operational access.'**
  String
  get provisionStaffAccountsWithCustomDesignationsSalaryAndOperationalAccess;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @querySubmittedEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Query Submitted & Email Sent!'**
  String get querySubmittedEmailSent;

  /// No description provided for @quickSelectEmoji.
  ///
  /// In en, this message translates to:
  /// **'Quick select emoji:'**
  String get quickSelectEmoji;

  /// No description provided for @readLess.
  ///
  /// In en, this message translates to:
  /// **'Read less'**
  String get readLess;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @referencePincodeProduct.
  ///
  /// In en, this message translates to:
  /// **'Reference, pincode, product…'**
  String get referencePincodeProduct;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeFromCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove from Category'**
  String get removeFromCategory;

  /// No description provided for @reportsAnalyticsCanviewreports.
  ///
  /// In en, this message translates to:
  /// **'Reports & Analytics (canViewReports)'**
  String get reportsAnalyticsCanviewreports;

  /// No description provided for @residentialAddress.
  ///
  /// In en, this message translates to:
  /// **'Residential Address'**
  String get residentialAddress;

  /// No description provided for @restoringSession.
  ///
  /// In en, this message translates to:
  /// **'Restoring session...'**
  String get restoringSession;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'SAVED ADDRESSES'**
  String get savedAddresses;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @sku2.
  ///
  /// In en, this message translates to:
  /// **'SKU *'**
  String get sku2;

  /// No description provided for @specialOffer.
  ///
  /// In en, this message translates to:
  /// **'SPECIAL OFFER'**
  String get specialOffer;

  /// No description provided for @salaryAmount.
  ///
  /// In en, this message translates to:
  /// **'Salary Amount (₹)'**
  String get salaryAmount;

  /// No description provided for @salaryFrequency.
  ///
  /// In en, this message translates to:
  /// **'Salary Frequency'**
  String get salaryFrequency;

  /// No description provided for @salaryNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Salary: Not specified'**
  String get salaryNotSpecified;

  /// No description provided for @saveAddressContinue.
  ///
  /// In en, this message translates to:
  /// **'Save Address & Continue'**
  String get saveAddressContinue;

  /// No description provided for @saveAddressAs.
  ///
  /// In en, this message translates to:
  /// **'Save Address As'**
  String get saveAddressAs;

  /// No description provided for @saveMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Save Mobile Number'**
  String get saveMobileNumber;

  /// No description provided for @saveOption.
  ///
  /// In en, this message translates to:
  /// **'Save Option'**
  String get saveOption;

  /// No description provided for @savedAddresses2.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses2;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @scanQrBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR / Barcode'**
  String get scanQrBarcode;

  /// No description provided for @searchFaqsOrdersReturnsPayments.
  ///
  /// In en, this message translates to:
  /// **'Search FAQs, orders, returns, payments...'**
  String get searchFaqsOrdersReturnsPayments;

  /// No description provided for @searchByCode.
  ///
  /// In en, this message translates to:
  /// **'Search by code'**
  String get searchByCode;

  /// No description provided for @searchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get searchCategories;

  /// No description provided for @searchCategoriesBrandsOrShops.
  ///
  /// In en, this message translates to:
  /// **'Search categories, brands, or shops...'**
  String get searchCategoriesBrandsOrShops;

  /// No description provided for @searchInThisStore.
  ///
  /// In en, this message translates to:
  /// **'Search in this store'**
  String get searchInThisStore;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search orders'**
  String get searchOrders;

  /// No description provided for @searchPincode.
  ///
  /// In en, this message translates to:
  /// **'Search pincode'**
  String get searchPincode;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// No description provided for @searchProductsByNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Search products by name or ID...'**
  String get searchProductsByNameOrId;

  /// No description provided for @searchProductsCategoriesOrStores.
  ///
  /// In en, this message translates to:
  /// **'Search products, categories, or stores...'**
  String get searchProductsCategoriesOrStores;

  /// No description provided for @sectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Section Title *'**
  String get sectionTitle;

  /// No description provided for @sectionType.
  ///
  /// In en, this message translates to:
  /// **'Section Type *'**
  String get sectionType;

  /// No description provided for @sectionsShownUnderAllDetailsOnTheProductPage.
  ///
  /// In en, this message translates to:
  /// **'Sections shown under \"All Details\" on the product page — '**
  String get sectionsShownUnderAllDetailsOnTheProductPage;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @selectDeliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Delivery Location'**
  String get selectDeliveryLocation;

  /// No description provided for @selectVariant.
  ///
  /// In en, this message translates to:
  /// **'Select Variant'**
  String get selectVariant;

  /// No description provided for @selectAnAddressToSeeProductAvailabilityAndDeliveryFees.
  ///
  /// In en, this message translates to:
  /// **'Select an address to see product availability and delivery fees'**
  String get selectAnAddressToSeeProductAvailabilityAndDeliveryFees;

  /// No description provided for @selfPickup.
  ///
  /// In en, this message translates to:
  /// **'Self pickup'**
  String get selfPickup;

  /// No description provided for @selfPickup2.
  ///
  /// In en, this message translates to:
  /// **'Self-Pickup'**
  String get selfPickup2;

  /// No description provided for @sellingDiscountedPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling / Discounted Price (₹)'**
  String get sellingDiscountedPrice;

  /// No description provided for @sendToPrinter.
  ///
  /// In en, this message translates to:
  /// **'Send to printer'**
  String get sendToPrinter;

  /// No description provided for @serviceableArea.
  ///
  /// In en, this message translates to:
  /// **'Serviceable Area'**
  String get serviceableArea;

  /// No description provided for @setAsDefaultDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Set as default delivery address'**
  String get setAsDefaultDeliveryAddress;

  /// No description provided for @shiftWorkStatus.
  ///
  /// In en, this message translates to:
  /// **'Shift & Work Status'**
  String get shiftWorkStatus;

  /// No description provided for @shiftActive.
  ///
  /// In en, this message translates to:
  /// **'Shift Active'**
  String get shiftActive;

  /// No description provided for @shopNow.
  ///
  /// In en, this message translates to:
  /// **'Shop Now'**
  String get shopNow;

  /// No description provided for @shopperApp.
  ///
  /// In en, this message translates to:
  /// **'Shopper App'**
  String get shopperApp;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @showOutOfStockItems.
  ///
  /// In en, this message translates to:
  /// **'Show out-of-stock items'**
  String get showOutOfStockItems;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInToViewCart.
  ///
  /// In en, this message translates to:
  /// **'Sign In to View Cart'**
  String get signInToViewCart;

  /// No description provided for @signInToViewOrders.
  ///
  /// In en, this message translates to:
  /// **'Sign In to View Orders'**
  String get signInToViewOrders;

  /// No description provided for @signInToPlaceOrdersSaveCartApplyVouchers.
  ///
  /// In en, this message translates to:
  /// **'Sign in to place orders, save cart & apply vouchers'**
  String get signInToPlaceOrdersSaveCartApplyVouchers;

  /// No description provided for @signInFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailedPleaseTryAgain;

  /// No description provided for @simpleText.
  ///
  /// In en, this message translates to:
  /// **'Simple Text'**
  String get simpleText;

  /// No description provided for @specKey.
  ///
  /// In en, this message translates to:
  /// **'Spec Key'**
  String get specKey;

  /// No description provided for @specValue.
  ///
  /// In en, this message translates to:
  /// **'Spec Value'**
  String get specValue;

  /// No description provided for @specificationsPolicies.
  ///
  /// In en, this message translates to:
  /// **'Specifications & Policies'**
  String get specificationsPolicies;

  /// No description provided for @standardDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Standard Delivery Charge (₹) *'**
  String get standardDeliveryCharge;

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start Shopping'**
  String get startShopping;

  /// No description provided for @stockAvailabilityInventoryMode.
  ///
  /// In en, this message translates to:
  /// **'Stock Availability & Inventory Mode'**
  String get stockAvailabilityInventoryMode;

  /// No description provided for @stockAvailability.
  ///
  /// In en, this message translates to:
  /// **'Stock Availability *'**
  String get stockAvailability;

  /// No description provided for @stockQuantity.
  ///
  /// In en, this message translates to:
  /// **'Stock Quantity *'**
  String get stockQuantity;

  /// No description provided for @storeCategory.
  ///
  /// In en, this message translates to:
  /// **'Store Category'**
  String get storeCategory;

  /// No description provided for @storeOnlySupportsSelfPickup.
  ///
  /// In en, this message translates to:
  /// **'Store only supports self-pickup'**
  String get storeOnlySupportsSelfPickup;

  /// No description provided for @storeReviews.
  ///
  /// In en, this message translates to:
  /// **'Store reviews'**
  String get storeReviews;

  /// No description provided for @strategy.
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get strategy;

  /// No description provided for @streetAreaLandmark.
  ///
  /// In en, this message translates to:
  /// **'Street / Area / Landmark *'**
  String get streetAreaLandmark;

  /// No description provided for @streetAreaCityPincode.
  ///
  /// In en, this message translates to:
  /// **'Street, area, city, pincode...'**
  String get streetAreaCityPincode;

  /// No description provided for @submitQuerySendEmail.
  ///
  /// In en, this message translates to:
  /// **'Submit Query & Send Email'**
  String get submitQuerySendEmail;

  /// No description provided for @submitASupportQueryDirectlyToOurTeam.
  ///
  /// In en, this message translates to:
  /// **'Submit a support query directly to our team.'**
  String get submitASupportQueryDirectlyToOurTeam;

  /// No description provided for @submittingThisFormTriggersAnEmailToAyush123GmailComWithYourMessageAndAccountDetailsAttached.
  ///
  /// In en, this message translates to:
  /// **'Submitting this form triggers an email to ayush123@gmail.com with your message and account details attached.'**
  String
  get submittingThisFormTriggersAnEmailToAyush123GmailComWithYourMessageAndAccountDetailsAttached;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @supportHelplineAyush123GmailCom.
  ///
  /// In en, this message translates to:
  /// **'Support Helpline: ayush123@gmail.com'**
  String get supportHelplineAyush123GmailCom;

  /// No description provided for @swipeRightOrTapOnAvailableProductsToAssignSwipeLeftOr.
  ///
  /// In en, this message translates to:
  /// **'Swipe right or tap + on available products to assign. Swipe left or '**
  String get swipeRightOrTapOnAvailableProductsToAssignSwipeLeftOr;

  /// No description provided for @switchingTheTypeWillClearTheContentOfThisSectionContinue.
  ///
  /// In en, this message translates to:
  /// **'Switching the type will clear the content of this section. Continue?'**
  String get switchingTheTypeWillClearTheContentOfThisSectionContinue;

  /// No description provided for @tapAction.
  ///
  /// In en, this message translates to:
  /// **'Tap action'**
  String get tapAction;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text *'**
  String get text;

  /// No description provided for @theseProductsAreNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'These products are no longer available'**
  String get theseProductsAreNoLongerAvailable;

  /// No description provided for @thisCategoryIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'This category is empty.'**
  String get thisCategoryIsEmpty;

  /// No description provided for @thisOrderIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This order is no longer available.'**
  String get thisOrderIsNoLongerAvailable;

  /// No description provided for @thisShopDoesNotOfferHomeDelivery.
  ///
  /// In en, this message translates to:
  /// **'This shop does not offer home delivery'**
  String get thisShopDoesNotOfferHomeDelivery;

  /// No description provided for @thisStoreHasNoProductsYet.
  ///
  /// In en, this message translates to:
  /// **'This store has no products yet'**
  String get thisStoreHasNoProductsYet;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @titleValue.
  ///
  /// In en, this message translates to:
  /// **'Title & Value'**
  String get titleValue;

  /// No description provided for @title2.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get title2;

  /// No description provided for @titleAndValueRowsShownAsTheCompactHighlightsListOnTheProductPage.
  ///
  /// In en, this message translates to:
  /// **'Title and value rows shown as the compact highlights list on the product page.'**
  String get titleAndValueRowsShownAsTheCompactHighlightsListOnTheProductPage;

  /// No description provided for @topSellersTrendingCuratedCrossSell.
  ///
  /// In en, this message translates to:
  /// **'Top Sellers · Trending · Curated · Cross-sell'**
  String get topSellersTrendingCuratedCrossSell;

  /// No description provided for @topSellers.
  ///
  /// In en, this message translates to:
  /// **'Top sellers'**
  String get topSellers;

  /// No description provided for @totalRedemptions.
  ///
  /// In en, this message translates to:
  /// **'Total redemptions'**
  String get totalRedemptions;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get trackOrder;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @tryAdjustingYourSearchTermsOrSubmitAQueryToOurSupportStaff.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms or submit a query to our support staff.'**
  String get tryAdjustingYourSearchTermsOrSubmitAQueryToOurSupportStaff;

  /// No description provided for @tryCheckingForTyposOrSearchingForADifferentKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try checking for typos or searching for a different keyword'**
  String get tryCheckingForTyposOrSearchingForADifferentKeyword;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @unavailableItemsAreExcludedFromTheTotal.
  ///
  /// In en, this message translates to:
  /// **'Unavailable items are excluded from the total.'**
  String get unavailableItemsAreExcludedFromTheTotal;

  /// No description provided for @unitType.
  ///
  /// In en, this message translates to:
  /// **'Unit Type *'**
  String get unitType;

  /// No description provided for @unitValue.
  ///
  /// In en, this message translates to:
  /// **'Unit Value *'**
  String get unitValue;

  /// No description provided for @unlimitedInventory.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Inventory'**
  String get unlimitedInventory;

  /// No description provided for @unlimitedInventoryProductWillAlwaysAppearInStockForCustomersIdealForDigitalGoodsOrMadeToOrderItems.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Inventory: Product will always appear in stock for customers (ideal for digital goods or made-to-order items).'**
  String
  get unlimitedInventoryProductWillAlwaysAppearInStockForCustomersIdealForDigitalGoodsOrMadeToOrderItems;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value *'**
  String get value;

  /// No description provided for @variantConfigurationLocked.
  ///
  /// In en, this message translates to:
  /// **'Variant Configuration Locked'**
  String get variantConfigurationLocked;

  /// No description provided for @variantLabelNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Variant Label / Name (Optional)'**
  String get variantLabelNameOptional;

  /// No description provided for @variantMatrix.
  ///
  /// In en, this message translates to:
  /// **'Variant Matrix'**
  String get variantMatrix;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @verifiedMember.
  ///
  /// In en, this message translates to:
  /// **'Verified Member'**
  String get verifiedMember;

  /// No description provided for @verifiedLocalMerchants.
  ///
  /// In en, this message translates to:
  /// **'Verified local merchants'**
  String get verifiedLocalMerchants;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewAndUpdateStockCountsAndWarehouseAlerts.
  ///
  /// In en, this message translates to:
  /// **'View and update stock counts and warehouse alerts.'**
  String get viewAndUpdateStockCountsAndWarehouseAlerts;

  /// No description provided for @viewDailyEmployeeActivityAndOperationsLogs.
  ///
  /// In en, this message translates to:
  /// **'View daily employee activity and operations logs.'**
  String get viewDailyEmployeeActivityAndOperationsLogs;

  /// No description provided for @welcome20.
  ///
  /// In en, this message translates to:
  /// **'WELCOME20'**
  String get welcome20;

  /// No description provided for @weight100g200g500g1000g.
  ///
  /// In en, this message translates to:
  /// **'Weight (100g, 200g, 500g, 1000g)'**
  String get weight100g200g500g1000g;

  /// No description provided for @weight1kg2kg5kg10kg.
  ///
  /// In en, this message translates to:
  /// **'Weight (1kg, 2kg, 5kg, 10kg)'**
  String get weight1kg2kg5kg10kg;

  /// No description provided for @weight1lb2lb5lb10lb.
  ///
  /// In en, this message translates to:
  /// **'Weight (1lb, 2lb, 5lb, 10lb)'**
  String get weight1lb2lb5lb10lb;

  /// No description provided for @weight250g500g1kg.
  ///
  /// In en, this message translates to:
  /// **'Weight (250g, 500g, 1kg)'**
  String get weight250g500g1kg;

  /// No description provided for @weight500g1kg2kg5kg.
  ///
  /// In en, this message translates to:
  /// **'Weight (500g, 1kg, 2kg, 5kg)'**
  String get weight500g1kg2kg5kg;

  /// No description provided for @weight50g100g250g500g.
  ///
  /// In en, this message translates to:
  /// **'Weight (50g, 100g, 250g, 500g)'**
  String get weight50g100g250g500g;

  /// No description provided for @weight50mg100mg250mg500mg.
  ///
  /// In en, this message translates to:
  /// **'Weight (50mg, 100mg, 250mg, 500mg)'**
  String get weight50mg100mg250mg500mg;

  /// No description provided for @welcomeToBazaar.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Bazaar'**
  String get welcomeToBazaar;

  /// No description provided for @wordDocx.
  ///
  /// In en, this message translates to:
  /// **'Word (.docx)'**
  String get wordDocx;

  /// No description provided for @writeAShortMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a short message'**
  String get writeAShortMessage;

  /// No description provided for @writeToUs.
  ///
  /// In en, this message translates to:
  /// **'Write to Us'**
  String get writeToUs;

  /// No description provided for @yearlyCtcYear.
  ///
  /// In en, this message translates to:
  /// **'Yearly / CTC (₹/year)'**
  String get yearlyCtcYear;

  /// No description provided for @yearlyOrderReport.
  ///
  /// In en, this message translates to:
  /// **'Yearly order report'**
  String get yearlyOrderReport;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get yesCancel;

  /// No description provided for @youHaveUnsavedChangesLeaveWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Leave without saving?'**
  String get youHaveUnsavedChangesLeaveWithoutSaving;

  /// No description provided for @yourCartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get yourCartIsEmpty;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get yourFullName;

  /// No description provided for @adminCompanyIn.
  ///
  /// In en, this message translates to:
  /// **'admin@company.in'**
  String get adminCompanyIn;

  /// No description provided for @eG1Or500.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 or 500'**
  String get eG1Or500;

  /// No description provided for @eG12DaysSameDay3045Mins.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1-2 days, Same Day, 30-45 mins'**
  String get eG12DaysSameDay3045Mins;

  /// No description provided for @eG12MarketStreetAhmedabad.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12 Market Street, Ahmedabad'**
  String get eG12MarketStreetAhmedabad;

  /// No description provided for @eG1990ForNoMinimum.
  ///
  /// In en, this message translates to:
  /// **'e.g. 199 (0 for no minimum)'**
  String get eG1990ForNoMinimum;

  /// No description provided for @eG25000.
  ///
  /// In en, this message translates to:
  /// **'e.g. 25000'**
  String get eG25000;

  /// No description provided for @eG380001.
  ///
  /// In en, this message translates to:
  /// **'e.g. 380001'**
  String get eG380001;

  /// No description provided for @eG40.
  ///
  /// In en, this message translates to:
  /// **'e.g. 40'**
  String get eG40;

  /// No description provided for @eG499LeaveBlankIfNoFreeTier.
  ///
  /// In en, this message translates to:
  /// **'e.g. 499 (Leave blank if no free tier)'**
  String get eG499LeaveBlankIfNoFreeTier;

  /// No description provided for @eG500125.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500, 1, 2, 5'**
  String get eG500125;

  /// No description provided for @eG79900.
  ///
  /// In en, this message translates to:
  /// **'e.g. 799.00'**
  String get eG79900;

  /// No description provided for @eG99900.
  ///
  /// In en, this message translates to:
  /// **'e.g. 999.00'**
  String get eG99900;

  /// No description provided for @eGDescriptionGeneralDisplayFeatures.
  ///
  /// In en, this message translates to:
  /// **'e.g. Description, General, Display Features'**
  String get eGDescriptionGeneralDisplayFeatures;

  /// No description provided for @eGFabricShelfLife.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fabric / Shelf Life'**
  String get eGFabricShelfLife;

  /// No description provided for @eGFlat302BuildingA.
  ///
  /// In en, this message translates to:
  /// **'e.g. Flat 302, Building A'**
  String get eGFlat302BuildingA;

  /// No description provided for @eGFlat402BlockA.
  ///
  /// In en, this message translates to:
  /// **'e.g. Flat 402, Block A'**
  String get eGFlat402BlockA;

  /// No description provided for @eGFreeShippingOnOrdersAbove499Easy7DayHassleFreeReplacementForDefectiveProducts.
  ///
  /// In en, this message translates to:
  /// **'e.g. Free shipping on orders above ₹499. Easy 7-day hassle-free replacement for defective products.'**
  String
  get eGFreeShippingOnOrdersAbove499Easy7DayHassleFreeReplacementForDefectiveProducts;

  /// No description provided for @eGFreshOrganicVegetables.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fresh Organic Vegetables'**
  String get eGFreshOrganicVegetables;

  /// No description provided for @eGFreshOrganicGroceriesDeliveredDaily.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fresh organic groceries delivered daily'**
  String get eGFreshOrganicGroceriesDeliveredDaily;

  /// No description provided for @eGGreenValleyRoadNearCityMall.
  ///
  /// In en, this message translates to:
  /// **'e.g. Green Valley Road, Near City Mall'**
  String get eGGreenValleyRoadNearCityMall;

  /// No description provided for @eGGroceryStaplesSupermarketElectronics.
  ///
  /// In en, this message translates to:
  /// **'e.g. Grocery & Staples, Supermarket, Electronics'**
  String get eGGroceryStaplesSupermarketElectronics;

  /// No description provided for @eGGroceryElectronics.
  ///
  /// In en, this message translates to:
  /// **'e.g. Grocery, Electronics'**
  String get eGGroceryElectronics;

  /// No description provided for @eGOmMartExpress.
  ///
  /// In en, this message translates to:
  /// **'e.g. Om Mart Express'**
  String get eGOmMartExpress;

  /// No description provided for @eGOppositeCityMall.
  ///
  /// In en, this message translates to:
  /// **'e.g. Opposite City Mall'**
  String get eGOppositeCityMall;

  /// No description provided for @eGOrganicHassAvocadoChanderiSilkSaree15In1SweetsBox.
  ///
  /// In en, this message translates to:
  /// **'e.g. Organic Hass Avocado / Chanderi Silk Saree / 15-in-1 Sweets Box'**
  String get eGOrganicHassAvocadoChanderiSilkSaree15In1SweetsBox;

  /// No description provided for @eGProdHoney01.
  ///
  /// In en, this message translates to:
  /// **'e.g. PROD-HONEY-01'**
  String get eGProdHoney01;

  /// No description provided for @eGPureSilk30Days.
  ///
  /// In en, this message translates to:
  /// **'e.g. Pure Silk / 30 Days'**
  String get eGPureSilk30Days;

  /// No description provided for @eGQuantitySizeColor.
  ///
  /// In en, this message translates to:
  /// **'e.g. Quantity, Size, Color'**
  String get eGQuantitySizeColor;

  /// No description provided for @eGRameshKumar.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ramesh Kumar'**
  String get eGRameshKumar;

  /// No description provided for @eGRedMidnightBlueMatteBlack.
  ///
  /// In en, this message translates to:
  /// **'e.g. Red / Midnight Blue / Matte Black'**
  String get eGRedMidnightBlueMatteBlack;

  /// No description provided for @eGRedMidnightBlueBlack.
  ///
  /// In en, this message translates to:
  /// **'e.g. Red, Midnight Blue, Black'**
  String get eGRedMidnightBlueBlack;

  /// No description provided for @eGSku500g01.
  ///
  /// In en, this message translates to:
  /// **'e.g. SKU-500G-01'**
  String get eGSku500g01;

  /// No description provided for @eGVastrapurNearShivTemple.
  ///
  /// In en, this message translates to:
  /// **'e.g. Vastrapur, near Shiv Temple'**
  String get eGVastrapurNearShivTemple;

  /// No description provided for @eGRameshCompanyCom.
  ///
  /// In en, this message translates to:
  /// **'e.g. ramesh@company.com'**
  String get eGRameshCompanyCom;

  /// No description provided for @httpsExampleComLogoPng.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/logo.png'**
  String get httpsExampleComLogoPng;

  /// No description provided for @httpsExampleComStoreBannerJpg.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/store_banner.jpg'**
  String get httpsExampleComStoreBannerJpg;

  /// No description provided for @httpsExampleComStorefrontPhotoJpg.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/storefront_photo.jpg'**
  String get httpsExampleComStorefrontPhotoJpg;

  /// No description provided for @httpsImagesUnsplashCom.
  ///
  /// In en, this message translates to:
  /// **'https://images.unsplash.com/...'**
  String get httpsImagesUnsplashCom;

  /// No description provided for @inr.
  ///
  /// In en, this message translates to:
  /// **'₹ INR'**
  String get inr;

  /// No description provided for @assignedProduct.
  ///
  /// In en, this message translates to:
  /// **'assigned product'**
  String get assignedProduct;

  /// No description provided for @assignedProducts.
  ///
  /// In en, this message translates to:
  /// **'assigned products'**
  String get assignedProducts;

  /// No description provided for @toUncategorised.
  ///
  /// In en, this message translates to:
  /// **'to \"Uncategorised\"'**
  String get toUncategorised;

  /// No description provided for @subCategory.
  ///
  /// In en, this message translates to:
  /// **'sub-category'**
  String get subCategory;

  /// No description provided for @subCategories.
  ///
  /// In en, this message translates to:
  /// **'sub-categories'**
  String get subCategories;

  /// No description provided for @uncategorisedType.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised type'**
  String get uncategorisedType;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **' • Store'**
  String get store;

  /// No description provided for @global.
  ///
  /// In en, this message translates to:
  /// **' • Global'**
  String get global;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @basePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get basePrice;

  /// No description provided for @untitledSection.
  ///
  /// In en, this message translates to:
  /// **'Untitled section'**
  String get untitledSection;

  /// No description provided for @firstOrderOnly2.
  ///
  /// In en, this message translates to:
  /// **' · first order only'**
  String get firstOrderOnly2;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @items4.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items4;

  /// No description provided for @offer.
  ///
  /// In en, this message translates to:
  /// **'offer'**
  String get offer;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'offers'**
  String get offers;

  /// No description provided for @thisAddress.
  ///
  /// In en, this message translates to:
  /// **'this address'**
  String get thisAddress;

  /// No description provided for @thisStore.
  ///
  /// In en, this message translates to:
  /// **'this store'**
  String get thisStore;

  /// No description provided for @packed.
  ///
  /// In en, this message translates to:
  /// **' · packed'**
  String get packed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Order #{order}'**
  String order(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'Company: {order}'**
  String company2(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'Total: ₹{order}'**
  String total(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'Copy {label} ID'**
  String copyId(String label);

  ///
  ///
  /// In en, this message translates to:
  /// **'{label} ID copied to clipboard: {id}'**
  String idCopiedToClipboard(String label, String id);

  ///
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String id(String id);

  ///
  ///
  /// In en, this message translates to:
  /// **'{user}: {user2} ({user3}/3)'**
  String msg3(String user, String user2, String user3);

  ///
  ///
  /// In en, this message translates to:
  /// **'{b} · priority {b2}'**
  String priority(String b, String b2);

  ///
  ///
  /// In en, this message translates to:
  /// **'A category named \"{trimmedname}\" already exists in this company.'**
  String aCategoryNamedAlreadyExistsInThisCompany(String trimmedname);

  ///
  ///
  /// In en, this message translates to:
  /// **'Category \"{category}\" updated successfully!'**
  String categoryUpdatedSuccessfully(String category);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to save category: {e}'**
  String failedToSaveCategory(String e);

  /// No description provided for @assignAnExistingParentCategoryInTheSameCompanyForNestingSelfAndDescendantCategoriesAreAutomaticallyBlockedToPreventHierarchyCycles.
  ///
  /// In en, this message translates to:
  /// **'Assign an existing parent category in the same company for nesting. Self and descendant categories are automatically blocked to prevent hierarchy cycles.'**
  String
  get assignAnExistingParentCategoryInTheSameCompanyForNestingSelfAndDescendantCategoriesAreAutomaticallyBlockedToPreventHierarchyCycles;

  ///
  ///
  /// In en, this message translates to:
  /// **'Note: {invalidparentids} categories (this category and its descendants) are blocked from being chosen as parent.'**
  String
  noteCategoriesThisCategoryAndItsDescendantsAreBlockedFromBeingChosenAsParent(
    String invalidparentids,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not save the new order: {e}'**
  String couldNotSaveTheNewOrder(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Backfill failed: {e}'**
  String backfillFailed(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete \"{category}\"?'**
  String delete2(String category);

  ///
  ///
  /// In en, this message translates to:
  /// **'to \"{parentname}\"'**
  String to(String parentname);

  ///
  ///
  /// In en, this message translates to:
  /// **'• {plural} will move {parentname}'**
  String willMove2(String plural, String parentname);

  ///
  ///
  /// In en, this message translates to:
  /// **'• {plural} will move up one level'**
  String willMoveUpOneLevel(String plural);

  ///
  ///
  /// In en, this message translates to:
  /// **'Category \"{category}\" deleted.'**
  String categoryDeleted(String category);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to delete category: {e}'**
  String failedToDeleteCategory(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **' • {node} sub'**
  String sub(String node);

  ///
  ///
  /// In en, this message translates to:
  /// **'{node}{node2}{node3}'**
  String str(String node, String node2, String node3);

  ///
  ///
  /// In en, this message translates to:
  /// **'Under: {pathlabel}'**
  String under(String pathlabel);

  /// No description provided for @swipeRightOrTapOnAvailableProductsToAssignSwipeLeftOrTapToRemoveDragTheHandleInInThisCategoryToSetTheDisplayOrder.
  ///
  /// In en, this message translates to:
  /// **'Swipe right or tap + on available products to assign. Swipe left or tap – to remove. Drag the ≡ handle in \"In This Category\" to set the display order.'**
  String
  get swipeRightOrTapOnAvailableProductsToAssignSwipeLeftOrTapToRemoveDragTheHandleInInThisCategoryToSetTheDisplayOrder;

  ///
  ///
  /// In en, this message translates to:
  /// **'All ({filteredavailable})'**
  String all(String filteredavailable);

  ///
  ///
  /// In en, this message translates to:
  /// **'In Category ({filteredassigned})'**
  String inCategory(String filteredassigned);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} of {totalcount}'**
  String countOutOfTotal(String count, String totalcount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery charge updated for {pincode}'**
  String deliveryChargeUpdatedFor(String pincode);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to save delivery charge: {e}'**
  String failedToSaveDeliveryCharge(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Imported {charges} pincodes successfully'**
  String importedPincodesSuccessfully(String charges);

  ///
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove delivery mapping for pincode \"{charge}\"?'**
  String areYouSureYouWantToRemoveDeliveryMappingForPincode(String charge);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery charge for \"{charge}\" deleted.'**
  String deliveryChargeForDeleted(String charge);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to delete delivery charge: {e}'**
  String failedToDeleteDeliveryCharge(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Pincode: {charge}'**
  String pincode2(String charge);

  ///
  ///
  /// In en, this message translates to:
  /// **'Charge: {formatcurrency}'**
  String charge(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'• Free on > {formatcurrency}'**
  String freeOn(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'• Min order: {formatcurrency}'**
  String minOrder(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'• ETA: {charge}'**
  String eta(String charge);

  ///
  ///
  /// In en, this message translates to:
  /// **'Employee \"{emp}\" updated successfully!'**
  String employeeUpdatedSuccessfully(String emp);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to save employee: {e}'**
  String failedToSaveEmployee(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{emp}\" ({emp2}) from the company?'**
  String areYouSureYouWantToRemoveFromTheCompany(String emp, String emp2);

  ///
  ///
  /// In en, this message translates to:
  /// **'Employee \"{emp}\" deleted.'**
  String employeeDeleted(String emp);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to delete employee: {e}'**
  String failedToDeleteEmployee(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'{order} item(s) · {order2}{order3}'**
  String itemS2(String order, String order2, String order3);

  ///
  ///
  /// In en, this message translates to:
  /// **'{order}{order2}{order3}'**
  String str2(String order, String order2, String order3);

  ///
  ///
  /// In en, this message translates to:
  /// **'Mark {orderstatuslabel}'**
  String mark(String orderstatuslabel);

  ///
  ///
  /// In en, this message translates to:
  /// **'Order {order} → {orderstatuslabel}'**
  String order2(String order, String orderstatuslabel);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not update order: {e}'**
  String couldNotUpdateOrder(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Order {order} will be cancelled and the customer will see it under \"Cancelled\".'**
  String orderWillBeCancelledAndTheCustomerWillSeeItUnderCancelled(
    String order,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not cancel order: {e}'**
  String couldNotCancelOrder(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Quantity (1 {currentunit}, 2 {currentunit2}, 5 {currentunit3}, 10 {currentunit4})'**
  String quantity12510(
    String currentunit,
    String currentunit2,
    String currentunit3,
    String currentunit4,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Quantity (2 {currentunit}, 4 {currentunit2}, 6 {currentunit3})'**
  String quantity246(
    String currentunit,
    String currentunit2,
    String currentunit3,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Please complete the required product details above ({missingbasefields}) before configuring options.'**
  String pleaseCompleteTheRequiredProductDetailsAboveBeforeConfiguringOptions(
    String missingbasefields,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Unit options strictly synchronized with \"{currentunit}\"'**
  String unitOptionsStrictlySynchronizedWith(String currentunit);

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 {currentunit}, 2 {currentunit2}, 5 {currentunit3}'**
  String eG125(String currentunit, String currentunit2, String currentunit3);

  ///
  ///
  /// In en, this message translates to:
  /// **'Quick Templates (Strictly for {currentunit}):'**
  String quickTemplatesStrictlyFor(String currentunit);

  ///
  ///
  /// In en, this message translates to:
  /// **'Cannot add \"{optname}\" option. The product unit is locked to \"{currentunit}\". Please use Quantity or Size/Color.'**
  String cannotAddOptionTheProductUnitIsLockedToPleaseUseQuantityOrSizeColor(
    String optname,
    String currentunit,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Please complete the required product details above ({missingbasefields}) before generating matrix.'**
  String pleaseCompleteTheRequiredProductDetailsAboveBeforeGeneratingMatrix(
    String missingbasefields,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Generated {variants} variant combinations with locked \"{baseunittype}\" unit & auto-calculated prices!'**
  String generatedVariantCombinationsWithLockedUnitAutoCalculatedPrices(
    String variants,
    String baseunittype,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Please complete the required product details above ({missingbasefields}) before adding variants.'**
  String pleaseCompleteTheRequiredProductDetailsAboveBeforeAddingVariants(
    String missingbasefields,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Unit Type: {lockedunittype} (Locked from Base Product)'**
  String unitTypeLockedFromBaseProduct(String lockedunittype);

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. Large / 500{lockedunittype} / Pack of 2'**
  String eGLarge500PackOf2(String lockedunittype);

  ///
  ///
  /// In en, this message translates to:
  /// **'Auto: ₹{calculatedautoprice}'**
  String auto(String calculatedautoprice);

  ///
  ///
  /// In en, this message translates to:
  /// **'Blank auto-calculates to ₹{calculatedautoprice} based on base price'**
  String blankAutoCalculatesToBasedOnBasePrice(String calculatedautoprice);

  ///
  ///
  /// In en, this message translates to:
  /// **'Edit Variant ({v})'**
  String editVariant(String v);

  ///
  ///
  /// In en, this message translates to:
  /// **'Product \"{product}\" updated successfully!'**
  String productUpdatedSuccessfully(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to save product: {e}'**
  String failedToSaveProduct(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'{images} added'**
  String added(String images);

  ///
  ///
  /// In en, this message translates to:
  /// **'{discountpercent}% OFF'**
  String off(String discountpercent);

  ///
  ///
  /// In en, this message translates to:
  /// **'{variants} Variant Combinations:'**
  String variantCombinations(String variants);

  ///
  ///
  /// In en, this message translates to:
  /// **'Price: ₹{variants}'**
  String price2(String variants);

  ///
  ///
  /// In en, this message translates to:
  /// **'Unit: {variants} {variants2} • Stock: {variants3} • {variants4}{variants5}'**
  String unitStock(
    String variants,
    String variants2,
    String variants3,
    String variants4,
    String variants5,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{product}\"?'**
  String areYouSureYouWantToDelete(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Product \"{product}\" deleted.'**
  String productDeleted(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Failed to delete product: {e}'**
  String failedToDeleteProduct(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'{product} var'**
  String msgVar(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'• {product} variants'**
  String variants(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete \"{section}\"? Its content will be lost.'**
  String deleteItsContentWillBeLost(String section);

  /// No description provided for @sectionsShownUnderAllDetailsOnTheProductPageSimpleTextParagraphsOrTitleValueTables.
  ///
  /// In en, this message translates to:
  /// **'Sections shown under \"All Details\" on the product page — Simple Text paragraphs or Title & Value tables.'**
  String
  get sectionsShownUnderAllDetailsOnTheProductPageSimpleTextParagraphsOrTitleValueTables;

  ///
  ///
  /// In en, this message translates to:
  /// **'Orders: {orders}'**
  String orders2(String orders);

  ///
  ///
  /// In en, this message translates to:
  /// **'Revenue: ₹{revenue}'**
  String revenue(String revenue);

  ///
  ///
  /// In en, this message translates to:
  /// **'\"{voucher}\" will be removed. Shoppers who saved this code will no longer get the discount.'**
  String willBeRemovedShoppersWhoSavedThisCodeWillNoLongerGetTheDiscount(
    String voucher,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Voucher {voucher} deleted.'**
  String voucherDeleted(String voucher);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not delete voucher: {e}'**
  String couldNotDeleteVoucher(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Min order ₹{voucher} · {voucher2}{voucher3}{voucher4}'**
  String minOrder4(
    String voucher,
    String voucher2,
    String voucher3,
    String voucher4,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'{usage} · {voucher} per shopper{voucher2} · expires {fmt}'**
  String perShopperExpires(
    String usage,
    String voucher,
    String voucher2,
    String fmt,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Voucher {voucher} updated.'**
  String voucherUpdated(String voucher);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not save voucher: {e}'**
  String couldNotSaveVoucher(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Company \"{companyname}\" not found.'**
  String companyNotFound(String companyname);

  ///
  ///
  /// In en, this message translates to:
  /// **'Company: {widget}'**
  String company3(String widget);

  ///
  ///
  /// In en, this message translates to:
  /// **'Error creating admin: {e}'**
  String errorCreatingAdmin(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'OTP sent to {mobile}'**
  String otpSentTo(String mobile);

  ///
  ///
  /// In en, this message translates to:
  /// **'Error: {e}'**
  String error(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'OTP resent to {mobile}'**
  String otpResentTo(String mobile);

  ///
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {e}'**
  String verificationFailed(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Verification error: {e}'**
  String verificationError(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'You save {formatcurrency}'**
  String youSave(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Total: {item}'**
  String total2(String item);

  ///
  ///
  /// In en, this message translates to:
  /// **'{removed} removed from cart'**
  String removedFromCart(String removed);

  ///
  ///
  /// In en, this message translates to:
  /// **'{removed} saved to your wishlist'**
  String savedToYourWishlist(String removed);

  ///
  ///
  /// In en, this message translates to:
  /// **'Place Direct Order · {formatcurrency}'**
  String placeDirectOrder(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Order {order} will be cancelled. This cannot be undone.'**
  String orderWillBeCancelledThisCannotBeUndone(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'Order {order}'**
  String order3(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'{order} items · {formatdate}'**
  String items(String order, String formatdate);

  ///
  ///
  /// In en, this message translates to:
  /// **' on {formatdate}'**
  String msgOn(String formatdate);

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancelled{order}'**
  String cancelled2(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'+{remaining} more'**
  String more(String remaining);

  ///
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =1{1 item} other{{added} items}} added to cart · {missing} no longer available'**
  String addedToCartNoLongerAvailable(num added, String missing);

  ///
  ///
  /// In en, this message translates to:
  /// **'Minimum Order for Delivery ({currency})'**
  String minimumOrderForDelivery(String currency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Company \"{companyname}\" registered successfully!'**
  String companyRegisteredSuccessfully(String companyname);

  ///
  ///
  /// In en, this message translates to:
  /// **'{l10n} Queue'**
  String queue(String l10n);

  ///
  ///
  /// In en, this message translates to:
  /// **'{o} items · {o2}{o3}'**
  String items5(String o, String o2, String o3);

  ///
  ///
  /// In en, this message translates to:
  /// **'{l10n} Manifest'**
  String manifest(String l10n);

  ///
  ///
  /// In en, this message translates to:
  /// **'Qty: {item} · SKU scan'**
  String qtySkuScan(String item);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your ticket ID is #{ticketid}.\nAn email has been triggered to ayush123@gmail.com with your attached account details.'**
  String
  yourTicketIdIsAnEmailHasBeenTriggeredToAyush123GmailComWithYourAttachedAccountDetails(
    String ticketid,
  );

  ///
  ///
  /// In en, this message translates to:
  /// **'Ticket #{ticketid}'**
  String ticket(String ticketid);

  ///
  ///
  /// In en, this message translates to:
  /// **'{filteredlist} items'**
  String items3(String filteredlist);

  ///
  ///
  /// In en, this message translates to:
  /// **'All {widget}'**
  String all2(String widget);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String productCount(num count);

  ///
  ///
  /// In en, this message translates to:
  /// **'No {categoryname} products found'**
  String noProductsFound2(String categoryname);

  ///
  ///
  /// In en, this message translates to:
  /// **'{product} added to cart'**
  String addedToCart(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Voucher \"{code}\" copied to clipboard!'**
  String voucherCopiedToClipboard(String code);

  ///
  ///
  /// In en, this message translates to:
  /// **'in {company}'**
  String msgIn(String company);

  ///
  ///
  /// In en, this message translates to:
  /// **'All Products ({filtered})'**
  String allProducts(String filtered);

  ///
  ///
  /// In en, this message translates to:
  /// **'Scroll for more ({filtered} left)'**
  String scrollForMoreLeft(String filtered);

  ///
  ///
  /// In en, this message translates to:
  /// **' ({stats, plural, =1{1 review} other{{stats} reviews}})'**
  String reviewsCount(num stats);

  ///
  ///
  /// In en, this message translates to:
  /// **'{sub} · {vouchers, plural, =1{1 live offer} other{{vouchers} live offers}}'**
  String vouchersPlural11LiveOfferOtherLiveOffers(String sub, num vouchers);

  ///
  ///
  /// In en, this message translates to:
  /// **'Use Code: {top}'**
  String useCode(String top);

  ///
  ///
  /// In en, this message translates to:
  /// **'Min order ₹{v}'**
  String minOrder3(String v);

  ///
  ///
  /// In en, this message translates to:
  /// **'Coupon {v} copied! Apply at checkout'**
  String couponCopiedApplyAtCheckout(String v);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery location set to: {detected} ({detected2})'**
  String deliveryLocationSetTo(String detected, String detected2);

  ///
  ///
  /// In en, this message translates to:
  /// **'Pincode {cleanpin}'**
  String pincode3(String cleanpin);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery location updated to {finalcity} ({cleanpin})'**
  String deliveryLocationUpdatedTo(String finalcity, String cleanpin);

  ///
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{addr}: {addr2}\"?'**
  String areYouSureYouWantToDelete2(String addr, String addr2);

  ///
  ///
  /// In en, this message translates to:
  /// **'Save home, work or other address (saved: {addresses}/3)'**
  String saveHomeWorkOrOtherAddressSaved3(String addresses);

  ///
  ///
  /// In en, this message translates to:
  /// **'{addresses} of 3 added'**
  String of3Added(String addresses);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery available to {addr}'**
  String deliveryAvailableTo(String addr);

  ///
  ///
  /// In en, this message translates to:
  /// **'-{discountpercent}% OFF'**
  String off2(String discountpercent);

  ///
  ///
  /// In en, this message translates to:
  /// **'Save {formatcurrency}'**
  String save2(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'SKU: {skuof}'**
  String sku3(String skuof);

  ///
  ///
  /// In en, this message translates to:
  /// **'View all details ({hidden} more)'**
  String viewAllDetailsMore(String hidden);

  ///
  ///
  /// In en, this message translates to:
  /// **'{p}{variantlabel} added to cart'**
  String addedToCart2(String p, String variantlabel);

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String off3(String percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'Search in {widget}'**
  String searchIn(String widget);

  ///
  ///
  /// In en, this message translates to:
  /// **'{resultcount, plural, =1{1 item} other{{resultcount} items}}'**
  String itemCount(num resultcount);

  ///
  ///
  /// In en, this message translates to:
  /// **'No products found for \"{query}\"'**
  String noProductsFoundFor(String query);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviews2(String count);

  /// No description provided for @couldNotSignInWithProvidedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with provided credentials.'**
  String get couldNotSignInWithProvidedCredentials;

  ///
  ///
  /// In en, this message translates to:
  /// **'No admin profile found for account \"{email}\".'**
  String noAdminProfileFoundForAccount(String email);

  ///
  ///
  /// In en, this message translates to:
  /// **'Admin account is assigned to \"{registeredname}\", not \"{companyname}\".'**
  String adminAccountIsAssignedToNot(String registeredname, String companyname);

  ///
  ///
  /// In en, this message translates to:
  /// **'No employee profile found for account \"{email}\".'**
  String noEmployeeProfileFoundForAccount(String email);

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// No description provided for @relevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get relevance;

  /// No description provided for @nameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get nameAZ;

  /// No description provided for @nameZA.
  ///
  /// In en, this message translates to:
  /// **'Name (Z–A)'**
  String get nameZA;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price (low to high)'**
  String get priceLowToHigh;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price (high to low)'**
  String get priceHighToLow;

  /// No description provided for @ratingTopPicksFirst.
  ///
  /// In en, this message translates to:
  /// **'Rating (top picks first)'**
  String get ratingTopPicksFirst;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup by {fmt}'**
  String readyForPickupBy(String fmt);

  ///
  ///
  /// In en, this message translates to:
  /// **'Arriving by {fmt}'**
  String arrivingBy(String fmt);

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  ///
  ///
  /// In en, this message translates to:
  /// **'{time} today'**
  String today(String time);

  ///
  ///
  /// In en, this message translates to:
  /// **'{time} tomorrow'**
  String tomorrow(String time);

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @msgLate.
  ///
  /// In en, this message translates to:
  /// **' (late)'**
  String get msgLate;

  /// No description provided for @openNow2.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get openNow2;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open Now · Closes {close}{closesuffix}'**
  String openNowCloses(String close, String closesuffix);

  ///
  ///
  /// In en, this message translates to:
  /// **'Closed · Opens {time}{day}'**
  String closedOpens(String time, String day);

  /// No description provided for @msgNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get msgNew;

  /// No description provided for @msg1Follower.
  ///
  /// In en, this message translates to:
  /// **'1 follower'**
  String get msg1Follower;

  ///
  ///
  /// In en, this message translates to:
  /// **'{followercount} followers'**
  String followers(String followercount);

  /// No description provided for @productTitleIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Product title is required.'**
  String get productTitleIsRequired;

  /// No description provided for @useAtLeast2Characters.
  ///
  /// In en, this message translates to:
  /// **'Use at least 2 characters.'**
  String get useAtLeast2Characters;

  /// No description provided for @mrpMustBeGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'MRP must be greater than 0.'**
  String get mrpMustBeGreaterThan0;

  /// No description provided for @sellingPriceCannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Selling price cannot be negative.'**
  String get sellingPriceCannotBeNegative;

  /// No description provided for @sellingPriceMustBeLowerThanTheMrpOrLeftAt0.
  ///
  /// In en, this message translates to:
  /// **'Selling price must be lower than the MRP (or left at 0).'**
  String get sellingPriceMustBeLowerThanTheMrpOrLeftAt0;

  /// No description provided for @stockCannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Stock cannot be negative.'**
  String get stockCannotBeNegative;

  /// No description provided for @unitMustBeGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'Unit must be greater than 0.'**
  String get unitMustBeGreaterThan0;

  /// No description provided for @pickACategoryForThisProduct.
  ///
  /// In en, this message translates to:
  /// **'Pick a category for this product.'**
  String get pickACategoryForThisProduct;

  /// No description provided for @weightBasedProductsNeedAUnitKgG.
  ///
  /// In en, this message translates to:
  /// **'Weight based products need a unit (kg, g, ...).'**
  String get weightBasedProductsNeedAUnitKgG;

  /// No description provided for @categoryNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name is required.'**
  String get categoryNameIsRequired;

  /// No description provided for @aCategoryWithThisNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists.'**
  String get aCategoryWithThisNameAlreadyExists;

  /// No description provided for @aCategoryCannotBeItsOwnParent.
  ///
  /// In en, this message translates to:
  /// **'A category cannot be its own parent.'**
  String get aCategoryCannotBeItsOwnParent;

  /// No description provided for @voucherCodeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Voucher code is required.'**
  String get voucherCodeIsRequired;

  ///
  ///
  /// In en, this message translates to:
  /// **'Use at least {codeminlength} characters.'**
  String useAtLeastCharacters(String codeminlength);

  ///
  ///
  /// In en, this message translates to:
  /// **'Use at most {codemaxlength} characters.'**
  String useAtMostCharacters(String codemaxlength);

  /// No description provided for @onlyLettersAndNumbersAreAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only letters and numbers are allowed.'**
  String get onlyLettersAndNumbersAreAllowed;

  /// No description provided for @thisCodeAlreadyExistsForThisStore.
  ///
  /// In en, this message translates to:
  /// **'This code already exists for this store.'**
  String get thisCodeAlreadyExistsForThisStore;

  /// No description provided for @enterAPercentageGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage greater than 0.'**
  String get enterAPercentageGreaterThan0;

  /// No description provided for @percentageCannotExceed100.
  ///
  /// In en, this message translates to:
  /// **'Percentage cannot exceed 100.'**
  String get percentageCannotExceed100;

  /// No description provided for @enterAnAmountGreaterThan0.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0.'**
  String get enterAnAmountGreaterThan0;

  /// No description provided for @minimumOrderCannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Minimum order cannot be negative.'**
  String get minimumOrderCannotBeNegative;

  /// No description provided for @perUserLimitMustBeAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Per-user limit must be at least 1.'**
  String get perUserLimitMustBeAtLeast1;

  /// No description provided for @totalUsageLimitMustBeAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Total usage limit must be at least 1.'**
  String get totalUsageLimitMustBeAtLeast1;

  /// No description provided for @totalLimitCannotBeLowerThanThePerUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Total limit cannot be lower than the per-user limit.'**
  String get totalLimitCannotBeLowerThanThePerUserLimit;

  /// No description provided for @expiryDateMustBeInTheFuture.
  ///
  /// In en, this message translates to:
  /// **'Expiry date must be in the future.'**
  String get expiryDateMustBeInTheFuture;

  /// No description provided for @selectAtLeastOneProduct.
  ///
  /// In en, this message translates to:
  /// **'Select at least one product.'**
  String get selectAtLeastOneProduct;

  /// No description provided for @selectAtLeastOneCategory.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category.'**
  String get selectAtLeastOneCategory;

  /// No description provided for @voucherApplied2.
  ///
  /// In en, this message translates to:
  /// **'Voucher applied.'**
  String get voucherApplied2;

  /// No description provided for @thatCodeIsNotValidForThisStore.
  ///
  /// In en, this message translates to:
  /// **'That code is not valid for this store.'**
  String get thatCodeIsNotValidForThisStore;

  /// No description provided for @thisVoucherIsCurrentlyDisabled.
  ///
  /// In en, this message translates to:
  /// **'This voucher is currently disabled.'**
  String get thisVoucherIsCurrentlyDisabled;

  /// No description provided for @thisVoucherHasExpired.
  ///
  /// In en, this message translates to:
  /// **'This voucher has expired.'**
  String get thisVoucherHasExpired;

  /// No description provided for @addAFewMoreItemsToUseThisVoucher.
  ///
  /// In en, this message translates to:
  /// **'Add a few more items to use this voucher.'**
  String get addAFewMoreItemsToUseThisVoucher;

  /// No description provided for @thisVoucherDoesNotApplyToTheItemsInYourCart.
  ///
  /// In en, this message translates to:
  /// **'This voucher does not apply to the items in your cart.'**
  String get thisVoucherDoesNotApplyToTheItemsInYourCart;

  /// No description provided for @youHaveAlreadyUsedThisVoucherTheMaximumNumberOfTimes.
  ///
  /// In en, this message translates to:
  /// **'You have already used this voucher the maximum number of times.'**
  String get youHaveAlreadyUsedThisVoucherTheMaximumNumberOfTimes;

  /// No description provided for @thisVoucherHasReachedItsRedemptionLimit.
  ///
  /// In en, this message translates to:
  /// **'This voucher has reached its redemption limit.'**
  String get thisVoucherHasReachedItsRedemptionLimit;

  /// No description provided for @thisVoucherIsForFirstTimeOrdersOnly.
  ///
  /// In en, this message translates to:
  /// **'This voucher is for first-time orders only.'**
  String get thisVoucherIsForFirstTimeOrdersOnly;

  /// No description provided for @voucherCannotBeApplied.
  ///
  /// In en, this message translates to:
  /// **'Voucher cannot be applied.'**
  String get voucherCannotBeApplied;

  ///
  ///
  /// In en, this message translates to:
  /// **'Only {left} left'**
  String onlyLeft(String left);

  ///
  ///
  /// In en, this message translates to:
  /// **'Near {landmark}'**
  String near(String landmark);

  /// No description provided for @weightBased.
  ///
  /// In en, this message translates to:
  /// **'Weight based'**
  String get weightBased;

  /// No description provided for @quantityBased.
  ///
  /// In en, this message translates to:
  /// **'Quantity based'**
  String get quantityBased;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @fixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get fixedAmount;

  /// No description provided for @freeShipping.
  ///
  /// In en, this message translates to:
  /// **'Free shipping'**
  String get freeShipping;

  /// No description provided for @specificCategories.
  ///
  /// In en, this message translates to:
  /// **'Specific categories'**
  String get specificCategories;

  /// No description provided for @specificProducts.
  ///
  /// In en, this message translates to:
  /// **'Specific products'**
  String get specificProducts;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  ///
  ///
  /// In en, this message translates to:
  /// **'₹{trim} OFF'**
  String off4(String trim);

  /// No description provided for @aNewVersionIsAvailablePleaseUpdate.
  ///
  /// In en, this message translates to:
  /// **'A new version is available. Please update.'**
  String get aNewVersionIsAvailablePleaseUpdate;

  /// No description provided for @aNewVersionIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version is available.'**
  String get aNewVersionIsAvailable;

  /// No description provided for @id2.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id2;

  /// No description provided for @onTheWay2.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get onTheWay2;

  /// No description provided for @guestCustomer.
  ///
  /// In en, this message translates to:
  /// **'Guest Customer'**
  String get guestCustomer;

  /// No description provided for @signInToSyncYourCartAndOrders.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your cart and orders'**
  String get signInToSyncYourCartAndOrders;

  /// No description provided for @vouchers.
  ///
  /// In en, this message translates to:
  /// **'Vouchers'**
  String get vouchers;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @myActivity.
  ///
  /// In en, this message translates to:
  /// **'My Activity'**
  String get myActivity;

  /// No description provided for @portalsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Portals & Admin'**
  String get portalsAdmin;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get editAddress;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterName;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone'**
  String get enterPhone;

  /// No description provided for @msg10DigitsRequired.
  ///
  /// In en, this message translates to:
  /// **'10 digits required'**
  String get msg10DigitsRequired;

  /// No description provided for @enterPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter pincode'**
  String get enterPincode;

  /// No description provided for @msg6Digits.
  ///
  /// In en, this message translates to:
  /// **'6 digits'**
  String get msg6Digits;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter city'**
  String get enterCity;

  /// No description provided for @enterHouseFlatNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter house/flat number'**
  String get enterHouseFlatNumber;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @updateAddress.
  ///
  /// In en, this message translates to:
  /// **'Update Address'**
  String get updateAddress;

  /// No description provided for @saveDeliverHere.
  ///
  /// In en, this message translates to:
  /// **'Save & Deliver Here'**
  String get saveDeliverHere;

  /// No description provided for @ordersPipeline.
  ///
  /// In en, this message translates to:
  /// **'Orders Pipeline'**
  String get ordersPipeline;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @admins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @deliveryCharges.
  ///
  /// In en, this message translates to:
  /// **'Delivery Charges'**
  String get deliveryCharges;

  /// No description provided for @banners.
  ///
  /// In en, this message translates to:
  /// **'Banners'**
  String get banners;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @qrCodes.
  ///
  /// In en, this message translates to:
  /// **'QR Codes'**
  String get qrCodes;

  /// No description provided for @categoryId.
  ///
  /// In en, this message translates to:
  /// **'Category ID'**
  String get categoryId;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @grocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get grocery;

  /// No description provided for @electronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get electronics;

  /// No description provided for @fashionApparel.
  ///
  /// In en, this message translates to:
  /// **'Fashion & Apparel'**
  String get fashionApparel;

  /// No description provided for @healthBeauty.
  ///
  /// In en, this message translates to:
  /// **'Health & Beauty'**
  String get healthBeauty;

  /// No description provided for @homeKitchen.
  ///
  /// In en, this message translates to:
  /// **'Home & Kitchen'**
  String get homeKitchen;

  /// No description provided for @bakeryDairy.
  ///
  /// In en, this message translates to:
  /// **'Bakery & Dairy'**
  String get bakeryDairy;

  /// No description provided for @personalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get personalCare;

  /// No description provided for @sportsOutdoors.
  ///
  /// In en, this message translates to:
  /// **'Sports & Outdoors'**
  String get sportsOutdoors;

  /// No description provided for @toysGames.
  ///
  /// In en, this message translates to:
  /// **'Toys & Games'**
  String get toysGames;

  /// No description provided for @addNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get addNewCategory;

  /// No description provided for @categoryDetails.
  ///
  /// In en, this message translates to:
  /// **'Category Details'**
  String get categoryDetails;

  /// No description provided for @categoryNameIsRequired2.
  ///
  /// In en, this message translates to:
  /// **'Category name is required'**
  String get categoryNameIsRequired2;

  /// No description provided for @classificationTypeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Classification type is required'**
  String get classificationTypeIsRequired;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get createCategory;

  /// No description provided for @companyScope.
  ///
  /// In en, this message translates to:
  /// **'Company Scope'**
  String get companyScope;

  /// No description provided for @globalScope.
  ///
  /// In en, this message translates to:
  /// **'Global Scope'**
  String get globalScope;

  /// No description provided for @doneReordering.
  ///
  /// In en, this message translates to:
  /// **'Done reordering'**
  String get doneReordering;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @topLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get topLevel;

  /// No description provided for @assignedProducts2.
  ///
  /// In en, this message translates to:
  /// **'Assigned products'**
  String get assignedProducts2;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @reorderingTopLevel.
  ///
  /// In en, this message translates to:
  /// **'Reordering: top level'**
  String get reorderingTopLevel;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @allProducts2.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProducts2;

  /// No description provided for @inThisCategory.
  ///
  /// In en, this message translates to:
  /// **'In This Category'**
  String get inThisCategory;

  /// No description provided for @noAssignedProductsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No assigned products match search'**
  String get noAssignedProductsMatchSearch;

  /// No description provided for @noProductsAssignedYet.
  ///
  /// In en, this message translates to:
  /// **'No products assigned yet'**
  String get noProductsAssignedYet;

  /// No description provided for @noAvailableProductsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No available products match search'**
  String get noAvailableProductsMatchSearch;

  /// No description provided for @allProductsAreAssigned.
  ///
  /// In en, this message translates to:
  /// **'All products are assigned!'**
  String get allProductsAreAssigned;

  /// No description provided for @msg6DigitAreaCodeForDeliveryService.
  ///
  /// In en, this message translates to:
  /// **'6-digit area code for delivery service'**
  String get msg6DigitAreaCodeForDeliveryService;

  /// No description provided for @enterA6DigitPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit pincode'**
  String get enterA6DigitPincode;

  /// No description provided for @pincodeMustBeExactly6Digits.
  ///
  /// In en, this message translates to:
  /// **'Pincode must be exactly 6 digits'**
  String get pincodeMustBeExactly6Digits;

  /// No description provided for @ordersCanBeDeliveredToThisPincode.
  ///
  /// In en, this message translates to:
  /// **'Orders can be delivered to this pincode'**
  String get ordersCanBeDeliveredToThisPincode;

  /// No description provided for @deliveryTemporarilySuspendedToThisPincode.
  ///
  /// In en, this message translates to:
  /// **'Delivery temporarily suspended to this pincode'**
  String get deliveryTemporarilySuspendedToThisPincode;

  /// No description provided for @enterDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Enter delivery charge'**
  String get enterDeliveryCharge;

  /// No description provided for @enterAValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterAValidAmount;

  /// No description provided for @customersGet0DeliveryFeeWhenOrderSubtotalMeetsThisAmount.
  ///
  /// In en, this message translates to:
  /// **'Customers get ₹0 delivery fee when order subtotal meets this amount'**
  String get customersGet0DeliveryFeeWhenOrderSubtotalMeetsThisAmount;

  /// No description provided for @displayedToCustomersOnCheckoutProductPages.
  ///
  /// In en, this message translates to:
  /// **'Displayed to customers on checkout & product pages'**
  String get displayedToCustomersOnCheckoutProductPages;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @updateDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Update Delivery Charge'**
  String get updateDeliveryCharge;

  /// No description provided for @saveDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Save Delivery Charge'**
  String get saveDeliveryCharge;

  /// No description provided for @serviceable.
  ///
  /// In en, this message translates to:
  /// **'Serviceable'**
  String get serviceable;

  /// No description provided for @suspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspended;

  /// No description provided for @manufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @dispatcher.
  ///
  /// In en, this message translates to:
  /// **'Dispatcher'**
  String get dispatcher;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @supervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get supervisor;

  /// No description provided for @qualityInspector.
  ///
  /// In en, this message translates to:
  /// **'Quality Inspector'**
  String get qualityInspector;

  /// No description provided for @employeeProfile.
  ///
  /// In en, this message translates to:
  /// **'Employee Profile'**
  String get employeeProfile;

  /// No description provided for @staffProvisioning.
  ///
  /// In en, this message translates to:
  /// **'Staff Provisioning'**
  String get staffProvisioning;

  /// No description provided for @fullNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameIsRequired;

  /// No description provided for @emailIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailIsRequired;

  /// No description provided for @enterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterAValidEmail;

  /// No description provided for @passwordMustBeAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast6Characters;

  /// No description provided for @selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select Date of Birth'**
  String get selectDateOfBirth;

  /// No description provided for @provisionEmployeeAccount.
  ///
  /// In en, this message translates to:
  /// **'Provision Employee Account'**
  String get provisionEmployeeAccount;

  /// No description provided for @activeShift.
  ///
  /// In en, this message translates to:
  /// **'Active Shift'**
  String get activeShift;

  /// No description provided for @offShift.
  ///
  /// In en, this message translates to:
  /// **'Off Shift'**
  String get offShift;

  /// No description provided for @dispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get dispatch;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @noOrdersYet2.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet2;

  /// No description provided for @ordersFromYourStoreWillAppearHereInstantly.
  ///
  /// In en, this message translates to:
  /// **'Orders from your store will appear here instantly.'**
  String get ordersFromYourStoreWillAppearHereInstantly;

  /// No description provided for @noOrdersMatchTheseFilters.
  ///
  /// In en, this message translates to:
  /// **'No orders match these filters'**
  String get noOrdersMatchTheseFilters;

  /// No description provided for @clearTheSearchBoxOrPickAnotherStatus.
  ///
  /// In en, this message translates to:
  /// **'Clear the search box or pick another status.'**
  String get clearTheSearchBoxOrPickAnotherStatus;

  /// No description provided for @all3.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all3;

  /// No description provided for @openOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get openOrders;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All orders'**
  String get allOrders;

  /// No description provided for @revenue2.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue2;

  /// No description provided for @ddMmmHhMmA.
  ///
  /// In en, this message translates to:
  /// **'dd MMM, hh:mm a'**
  String get ddMmmHhMmA;

  /// No description provided for @paymentDoneReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment: Done (Received)'**
  String get paymentDoneReceived;

  /// No description provided for @paymentPendingManualOffline.
  ///
  /// In en, this message translates to:
  /// **'Payment: Pending (Manual / Offline)'**
  String get paymentPendingManualOffline;

  /// No description provided for @paymentConfirmedByStore.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed by store'**
  String get paymentConfirmedByStore;

  /// No description provided for @customerWillPayOfflineToggleToMarkAsDone.
  ///
  /// In en, this message translates to:
  /// **'Customer will pay offline. Toggle to mark as Done.'**
  String get customerWillPayOfflineToggleToMarkAsDone;

  /// No description provided for @payable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get payable;

  /// No description provided for @productTitle2.
  ///
  /// In en, this message translates to:
  /// **'Product Title'**
  String get productTitle2;

  /// No description provided for @baseMrpPrice.
  ///
  /// In en, this message translates to:
  /// **'Base MRP / Price'**
  String get baseMrpPrice;

  /// No description provided for @baseUnitValue.
  ///
  /// In en, this message translates to:
  /// **'Base Unit Value'**
  String get baseUnitValue;

  /// No description provided for @baseSku.
  ///
  /// In en, this message translates to:
  /// **'Base SKU'**
  String get baseSku;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @sMLXlXxl.
  ///
  /// In en, this message translates to:
  /// **'S, M, L, XL, XXL'**
  String get sMLXlXxl;

  /// No description provided for @msg1kg2kg5kg10kg.
  ///
  /// In en, this message translates to:
  /// **'1kg, 2kg, 5kg, 10kg'**
  String get msg1kg2kg5kg10kg;

  /// No description provided for @msg500g1kg2kg5kg.
  ///
  /// In en, this message translates to:
  /// **'500g, 1kg, 2kg, 5kg'**
  String get msg500g1kg2kg5kg;

  /// No description provided for @msg250g500g1kg.
  ///
  /// In en, this message translates to:
  /// **'250g, 500g, 1kg'**
  String get msg250g500g1kg;

  /// No description provided for @msg50mg100mg250mg500mg.
  ///
  /// In en, this message translates to:
  /// **'50mg, 100mg, 250mg, 500mg'**
  String get msg50mg100mg250mg500mg;

  /// No description provided for @msg1lb2lb5lb10lb.
  ///
  /// In en, this message translates to:
  /// **'1lb, 2lb, 5lb, 10lb'**
  String get msg1lb2lb5lb10lb;

  /// No description provided for @box.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get box;

  /// No description provided for @msg1Box2Boxes5Boxes10Boxes.
  ///
  /// In en, this message translates to:
  /// **'1 box, 2 boxes, 5 boxes, 10 boxes'**
  String get msg1Box2Boxes5Boxes10Boxes;

  /// No description provided for @msg1Pack2Packs5Packs10Packs.
  ///
  /// In en, this message translates to:
  /// **'1 pack, 2 packs, 5 packs, 10 packs'**
  String get msg1Pack2Packs5Packs10Packs;

  /// No description provided for @bottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get bottle;

  /// No description provided for @msg1Bottle2Bottles4Bottles6Bottles.
  ///
  /// In en, this message translates to:
  /// **'1 bottle, 2 bottles, 4 bottles, 6 bottles'**
  String get msg1Bottle2Bottles4Bottles6Bottles;

  /// No description provided for @redBlueBlackWhiteGreen.
  ///
  /// In en, this message translates to:
  /// **'Red, Blue, Black, White, Green'**
  String get redBlueBlackWhiteGreen;

  /// No description provided for @navyCrimsonOliveGold.
  ///
  /// In en, this message translates to:
  /// **'Navy, Crimson, Olive, Gold'**
  String get navyCrimsonOliveGold;

  /// No description provided for @metricTon.
  ///
  /// In en, this message translates to:
  /// **'metric ton'**
  String get metricTon;

  /// No description provided for @halfDozen.
  ///
  /// In en, this message translates to:
  /// **'half dozen'**
  String get halfDozen;

  /// No description provided for @msg1Dozen.
  ///
  /// In en, this message translates to:
  /// **'1 dozen'**
  String get msg1Dozen;

  /// No description provided for @msg1Pair.
  ///
  /// In en, this message translates to:
  /// **'1 pair'**
  String get msg1Pair;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @customPriceOverrideApplied.
  ///
  /// In en, this message translates to:
  /// **'Custom price override applied'**
  String get customPriceOverrideApplied;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @option.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get option;

  /// No description provided for @addNewProduct.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get addNewProduct;

  /// No description provided for @updateCatalogItemDetailsPricingImagesVariantsAndSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Update catalog item details, pricing, images, variants, and specifications.'**
  String get updateCatalogItemDetailsPricingImagesVariantsAndSpecifications;

  /// No description provided for @createNewCatalogItemsWithDynamicVariantsCustomOptionsGalleryAndInventoryControls.
  ///
  /// In en, this message translates to:
  /// **'Create new catalog items with dynamic variants, custom options, gallery, and inventory controls.'**
  String
  get createNewCatalogItemsWithDynamicVariantsCustomOptionsGalleryAndInventoryControls;

  /// No description provided for @productTitleIsRequired2.
  ///
  /// In en, this message translates to:
  /// **'Product title is required'**
  String get productTitleIsRequired2;

  /// No description provided for @enterPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter price'**
  String get enterPrice;

  /// No description provided for @validNumber.
  ///
  /// In en, this message translates to:
  /// **'Valid number'**
  String get validNumber;

  /// No description provided for @msgRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get msgRequired;

  /// No description provided for @enterInventoryCount.
  ///
  /// In en, this message translates to:
  /// **'Enter inventory count'**
  String get enterInventoryCount;

  /// No description provided for @validInteger.
  ///
  /// In en, this message translates to:
  /// **'Valid integer'**
  String get validInteger;

  /// No description provided for @count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get count;

  /// No description provided for @specificCount.
  ///
  /// In en, this message translates to:
  /// **'Specific Count'**
  String get specificCount;

  /// No description provided for @unlimitedStock.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Stock'**
  String get unlimitedStock;

  /// No description provided for @outOfStock2.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock2;

  /// No description provided for @finishedOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Finished / Out of Stock'**
  String get finishedOutOfStock;

  /// No description provided for @quantityBased2.
  ///
  /// In en, this message translates to:
  /// **'Quantity Based'**
  String get quantityBased2;

  /// No description provided for @weightBased2.
  ///
  /// In en, this message translates to:
  /// **'Weight Based'**
  String get weightBased2;

  /// No description provided for @updateProduct.
  ///
  /// In en, this message translates to:
  /// **'Update Product'**
  String get updateProduct;

  /// No description provided for @createProduct.
  ///
  /// In en, this message translates to:
  /// **'Create Product'**
  String get createProduct;

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// No description provided for @uncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get uncategorised;

  /// No description provided for @stockUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Stock: Unlimited'**
  String get stockUnlimited;

  /// No description provided for @sectionTitleIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Section title is required'**
  String get sectionTitleIsRequired;

  /// No description provided for @textIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Text is required'**
  String get textIsRequired;

  /// No description provided for @colored.
  ///
  /// In en, this message translates to:
  /// **'Colored'**
  String get colored;

  /// No description provided for @logo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get logo;

  /// No description provided for @noPinnedProduct.
  ///
  /// In en, this message translates to:
  /// **'(no pinned product)'**
  String get noPinnedProduct;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @noVouchersYet.
  ///
  /// In en, this message translates to:
  /// **'No vouchers yet'**
  String get noVouchersYet;

  /// No description provided for @createYourFirstCouponCodeToRunAPromotionForThisStore.
  ///
  /// In en, this message translates to:
  /// **'Create your first coupon code to run a promotion for this store.'**
  String get createYourFirstCouponCodeToRunAPromotionForThisStore;

  /// No description provided for @createVoucher2.
  ///
  /// In en, this message translates to:
  /// **'Create Voucher'**
  String get createVoucher2;

  /// No description provided for @noVouchersMatchTheseFilters.
  ///
  /// In en, this message translates to:
  /// **'No vouchers match these filters'**
  String get noVouchersMatchTheseFilters;

  /// No description provided for @tryClearingTheSearchBoxOrChoosingAll.
  ///
  /// In en, this message translates to:
  /// **'Try clearing the search box or choosing \"All\".'**
  String get tryClearingTheSearchBoxOrChoosingAll;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @live2.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live2;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get limitReached;

  /// No description provided for @acceptingRedemptions.
  ///
  /// In en, this message translates to:
  /// **'Accepting redemptions'**
  String get acceptingRedemptions;

  /// No description provided for @ddMmmYyyy.
  ///
  /// In en, this message translates to:
  /// **'dd MMM yyyy'**
  String get ddMmmYyyy;

  /// No description provided for @voucherExpiry.
  ///
  /// In en, this message translates to:
  /// **'Voucher expiry'**
  String get voucherExpiry;

  /// No description provided for @editVoucher2.
  ///
  /// In en, this message translates to:
  /// **'Edit Voucher'**
  String get editVoucher2;

  /// No description provided for @lettersAndNumbersOnly.
  ///
  /// In en, this message translates to:
  /// **'Letters and numbers only'**
  String get lettersAndNumbersOnly;

  /// No description provided for @discount3.
  ///
  /// In en, this message translates to:
  /// **'Discount % *'**
  String get discount3;

  /// No description provided for @discountAmount.
  ///
  /// In en, this message translates to:
  /// **'Discount amount (₹) *'**
  String get discountAmount;

  /// No description provided for @saveChanges2.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges2;

  /// No description provided for @accessDeniedByServerPleaseCheckYourInternetConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Access denied by server. Please check your internet connection and try again.'**
  String get accessDeniedByServerPleaseCheckYourInternetConnectionAndTryAgain;

  /// No description provided for @invalidEmailPasswordOrCompanyCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email, password, or company credentials.'**
  String get invalidEmailPasswordOrCompanyCredentials;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authenticationFailed;

  /// No description provided for @invalidAdminEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid admin email or password.'**
  String get invalidAdminEmailOrPassword;

  /// No description provided for @thisAdminAccountHasBeenDisabled.
  ///
  /// In en, this message translates to:
  /// **'This admin account has been disabled.'**
  String get thisAdminAccountHasBeenDisabled;

  /// No description provided for @tooManyAttemptsPleaseWaitAMomentAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get tooManyAttemptsPleaseWaitAMomentAndTryAgain;

  /// No description provided for @invalidEmployeeEmailPasswordOrCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Invalid employee email, password, or company name.'**
  String get invalidEmployeeEmailPasswordOrCompanyName;

  /// No description provided for @invalidEmployeeEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid employee email or password.'**
  String get invalidEmployeeEmailOrPassword;

  /// No description provided for @thisEmployeeAccountHasBeenDisabled.
  ///
  /// In en, this message translates to:
  /// **'This employee account has been disabled.'**
  String get thisEmployeeAccountHasBeenDisabled;

  /// No description provided for @shopper.
  ///
  /// In en, this message translates to:
  /// **'Shopper'**
  String get shopper;

  /// No description provided for @enter10DigitNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit number'**
  String get enter10DigitNumber;

  /// No description provided for @enterThe6DigitCodeSentViaSms.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent via SMS'**
  String get enterThe6DigitCodeSentViaSms;

  /// No description provided for @signingUp.
  ///
  /// In en, this message translates to:
  /// **'Signing up...'**
  String get signingUp;

  /// No description provided for @signUpWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogle;

  /// No description provided for @couldNotResendOtpTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not resend OTP. Try again.'**
  String get couldNotResendOtpTryAgain;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @enter10DigitIndianMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit Indian mobile number'**
  String get enter10DigitIndianMobileNumber;

  /// No description provided for @enterAValid10DigitMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get enterAValid10DigitMobileNumber;

  /// No description provided for @houseFlatNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'House / Flat number is required'**
  String get houseFlatNumberIsRequired;

  /// No description provided for @streetOrAreaIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Street or Area is required'**
  String get streetOrAreaIsRequired;

  /// No description provided for @pincodeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pincode is required'**
  String get pincodeIsRequired;

  /// No description provided for @enterAValid6DigitPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit pincode'**
  String get enterAValid6DigitPincode;

  /// No description provided for @store2.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store2;

  /// No description provided for @moveToWishlist2.
  ///
  /// In en, this message translates to:
  /// **'MOVE TO WISHLIST'**
  String get moveToWishlist2;

  /// No description provided for @enterAVoucherCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a voucher code.'**
  String get enterAVoucherCode;

  /// No description provided for @pleaseSelectADeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery address.'**
  String get pleaseSelectADeliveryAddress;

  /// No description provided for @noOrderItemsAreAvailable.
  ///
  /// In en, this message translates to:
  /// **'No order items are available.'**
  String get noOrderItemsAreAvailable;

  /// No description provided for @storeTotal.
  ///
  /// In en, this message translates to:
  /// **'Store total'**
  String get storeTotal;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @loadingOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading order details...'**
  String get loadingOrderDetails;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @paymentOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Payment on delivery'**
  String get paymentOnDelivery;

  /// No description provided for @payOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay on delivery'**
  String get payOnDelivery;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'VIEW CART'**
  String get viewCart;

  /// No description provided for @usd.
  ///
  /// In en, this message translates to:
  /// **'\$ USD'**
  String get usd;

  /// No description provided for @thisEmailIsAlreadyRegisteredButThePasswordProvidedDoesNotMatchPleaseEnterYourExistingPasswordSignInViaAdminLoginOrUseADifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered, but the password provided does not match. Please enter your existing password, sign in via Admin Login, or use a different email.'**
  String
  get thisEmailIsAlreadyRegisteredButThePasswordProvidedDoesNotMatchPleaseEnterYourExistingPasswordSignInViaAdminLoginOrUseADifferentEmail;

  /// No description provided for @failedToObtainAuthenticatedUserId.
  ///
  /// In en, this message translates to:
  /// **'Failed to obtain authenticated user ID.'**
  String get failedToObtainAuthenticatedUserId;

  /// No description provided for @authenticationErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Authentication error occurred.'**
  String get authenticationErrorOccurred;

  /// No description provided for @passwordIsTooWeakPleaseUseAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please use at least 6 characters.'**
  String get passwordIsTooWeakPleaseUseAtLeast6Characters;

  /// No description provided for @thatEmailIsAlreadyRegisteredPleaseSignInViaAdminLoginOrUseADifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered. Please sign in via Admin Login or use a different email.'**
  String
  get thatEmailIsAlreadyRegisteredPleaseSignInViaAdminLoginOrUseADifferentEmail;

  /// No description provided for @pleaseEnterAValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get pleaseEnterAValidEmailAddress;

  /// No description provided for @invalidCredentialsIfYouAlreadyHaveAnAccountEnterItsExistingPasswordOrSignInViaAdminLogin.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. If you already have an account, enter its existing password or sign in via Admin Login.'**
  String
  get invalidCredentialsIfYouAlreadyHaveAnAccountEnterItsExistingPasswordOrSignInViaAdminLogin;

  /// No description provided for @sentToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Sent to Admin'**
  String get sentToAdmin;

  /// No description provided for @packingDone.
  ///
  /// In en, this message translates to:
  /// **'Packing Done'**
  String get packingDone;

  /// No description provided for @orderIssueTracking.
  ///
  /// In en, this message translates to:
  /// **'Order Issue & Tracking'**
  String get orderIssueTracking;

  /// No description provided for @deliveryDelayScheduling.
  ///
  /// In en, this message translates to:
  /// **'Delivery Delay & Scheduling'**
  String get deliveryDelayScheduling;

  /// No description provided for @paymentRefundInquiries.
  ///
  /// In en, this message translates to:
  /// **'Payment & Refund Inquiries'**
  String get paymentRefundInquiries;

  /// No description provided for @damagedWrongItemReceived.
  ///
  /// In en, this message translates to:
  /// **'Damaged / Wrong Item Received'**
  String get damagedWrongItemReceived;

  /// No description provided for @productDetailsAvailability.
  ///
  /// In en, this message translates to:
  /// **'Product Details & Availability'**
  String get productDetailsAvailability;

  /// No description provided for @accountLoginAssistance.
  ///
  /// In en, this message translates to:
  /// **'Account & Login Assistance'**
  String get accountLoginAssistance;

  /// No description provided for @generalFeedbackSuggestions.
  ///
  /// In en, this message translates to:
  /// **'General Feedback & Suggestions'**
  String get generalFeedbackSuggestions;

  /// No description provided for @otherInquiries.
  ///
  /// In en, this message translates to:
  /// **'Other Inquiries'**
  String get otherInquiries;

  /// No description provided for @orderIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Order ID (Optional)'**
  String get orderIdOptional;

  /// No description provided for @eGOrd10294OrPasteOrderId.
  ///
  /// In en, this message translates to:
  /// **'e.g. ORD-10294 or paste order ID'**
  String get eGOrd10294OrPasteOrderId;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name *'**
  String get yourName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @msg10DigitPhone.
  ///
  /// In en, this message translates to:
  /// **'10-digit phone'**
  String get msg10DigitPhone;

  /// No description provided for @phoneIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone is required'**
  String get phoneIsRequired;

  /// No description provided for @yourEmailAddressFrom.
  ///
  /// In en, this message translates to:
  /// **'Your Email Address (From) *'**
  String get yourEmailAddressFrom;

  /// No description provided for @eGUserExampleCom.
  ///
  /// In en, this message translates to:
  /// **'e.g. user@example.com'**
  String get eGUserExampleCom;

  /// No description provided for @deliveryContactAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery / Contact Address'**
  String get deliveryContactAddress;

  /// No description provided for @enterYourAddressToAttachWithQuery.
  ///
  /// In en, this message translates to:
  /// **'Enter your address to attach with query'**
  String get enterYourAddressToAttachWithQuery;

  /// No description provided for @subjectQuerySummary.
  ///
  /// In en, this message translates to:
  /// **'Subject / Query Summary *'**
  String get subjectQuerySummary;

  /// No description provided for @briefSummaryOfTheIssue.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of the issue'**
  String get briefSummaryOfTheIssue;

  /// No description provided for @pleaseEnterASummary.
  ///
  /// In en, this message translates to:
  /// **'Please enter a summary'**
  String get pleaseEnterASummary;

  /// No description provided for @detailedQueryMessage.
  ///
  /// In en, this message translates to:
  /// **'Detailed Query / Message *'**
  String get detailedQueryMessage;

  /// No description provided for @explainYourIssueQuestionsOrFeedbackInDetailSoWeCanAssistYouQuickly.
  ///
  /// In en, this message translates to:
  /// **'Explain your issue, questions or feedback in detail so we can assist you quickly...'**
  String get explainYourIssueQuestionsOrFeedbackInDetailSoWeCanAssistYouQuickly;

  /// No description provided for @pleaseDescribeYourQueryInAtLeast10Characters.
  ///
  /// In en, this message translates to:
  /// **'Please describe your query in at least 10 characters'**
  String get pleaseDescribeYourQueryInAtLeast10Characters;

  /// No description provided for @ordersTracking.
  ///
  /// In en, this message translates to:
  /// **'Orders & Tracking'**
  String get ordersTracking;

  /// No description provided for @deliveryShipping.
  ///
  /// In en, this message translates to:
  /// **'Delivery & Shipping'**
  String get deliveryShipping;

  /// No description provided for @paymentsRefunds.
  ///
  /// In en, this message translates to:
  /// **'Payments & Refunds'**
  String get paymentsRefunds;

  /// No description provided for @returnsExchanges.
  ///
  /// In en, this message translates to:
  /// **'Returns & Exchanges'**
  String get returnsExchanges;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get accountSecurity;

  /// No description provided for @discountsOffers.
  ///
  /// In en, this message translates to:
  /// **'Discounts & Offers'**
  String get discountsOffers;

  /// No description provided for @howDoITrackMyOrderStatusInRealTime.
  ///
  /// In en, this message translates to:
  /// **'How do I track my order status in real time?'**
  String get howDoITrackMyOrderStatusInRealTime;

  /// No description provided for @youCanTrackYourLiveOrderProgressByNavigatingToAccountMyOrdersAndSelectingYourActiveOrder.
  ///
  /// In en, this message translates to:
  /// **'You can track your live order progress by navigating to \"Account > My Orders\" and selecting your active order. '**
  String
  get youCanTrackYourLiveOrderProgressByNavigatingToAccountMyOrdersAndSelectingYourActiveOrder;

  /// No description provided for @youWillSeeStepByStepUpdatesFromOrderPlacedConfirmedPackedOutForDeliveryToDeliveredWithLiveStatusTimelines.
  ///
  /// In en, this message translates to:
  /// **'You will see step-by-step updates from Order Placed, Confirmed, Packed, Out for Delivery, to Delivered with live status timelines.'**
  String
  get youWillSeeStepByStepUpdatesFromOrderPlacedConfirmedPackedOutForDeliveryToDeliveredWithLiveStatusTimelines;

  /// No description provided for @canICancelOrModifyAnOrderAfterPlacingIt.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel or modify an order after placing it?'**
  String get canICancelOrModifyAnOrderAfterPlacingIt;

  /// No description provided for @youCanCancelYourOrderFromTheOrderDetailsScreenBeforeItEntersThePackedOrOutForDeliveryState.
  ///
  /// In en, this message translates to:
  /// **'You can cancel your order from the Order Details screen before it enters the \"Packed\" or \"Out for Delivery\" state. '**
  String
  get youCanCancelYourOrderFromTheOrderDetailsScreenBeforeItEntersThePackedOrOutForDeliveryState;

  /// No description provided for @onceAnOrderIsPackedOrDispatchedByTheMerchantCancellationRequestsMustBeHandledByContactingCustomerSupport.
  ///
  /// In en, this message translates to:
  /// **'Once an order is packed or dispatched by the merchant, cancellation requests must be handled by contacting customer support.'**
  String
  get onceAnOrderIsPackedOrDispatchedByTheMerchantCancellationRequestsMustBeHandledByContactingCustomerSupport;

  /// No description provided for @howIsTheDeliveryChargeCalculatedForMyLocation.
  ///
  /// In en, this message translates to:
  /// **'How is the delivery charge calculated for my location?'**
  String get howIsTheDeliveryChargeCalculatedForMyLocation;

  /// No description provided for @deliveryChargesAreComputedDynamicallyBasedOnTheMerchantSDeliveryZoneRatesForYourPinCodeOrDistance.
  ///
  /// In en, this message translates to:
  /// **'Delivery charges are computed dynamically based on the merchant\'s delivery zone rates for your PIN code or distance. '**
  String
  get deliveryChargesAreComputedDynamicallyBasedOnTheMerchantSDeliveryZoneRatesForYourPinCodeOrDistance;

  /// No description provided for @whenYouSelectOrEnterYourDeliveryAddressAtCheckoutAnyApplicableDeliveryFeeIsTransparentlyShownInTheBillSummary.
  ///
  /// In en, this message translates to:
  /// **'When you select or enter your delivery address at checkout, any applicable delivery fee is transparently shown in the bill summary.'**
  String
  get whenYouSelectOrEnterYourDeliveryAddressAtCheckoutAnyApplicableDeliveryFeeIsTransparentlyShownInTheBillSummary;

  /// No description provided for @whatAreTheEstimatedDeliveryTimelines.
  ///
  /// In en, this message translates to:
  /// **'What are the estimated delivery timelines?'**
  String get whatAreTheEstimatedDeliveryTimelines;

  /// No description provided for @standardLocalDeliveriesTypicallyArriveWithinTheMerchantSDesignatedDeliveryWindowUsually3090MinutesForQuickCommerceItemsOr12BusinessDaysForStandardItems.
  ///
  /// In en, this message translates to:
  /// **'Standard local deliveries typically arrive within the merchant\'s designated delivery window (usually 30–90 minutes for quick-commerce items or 1–2 business days for standard items). '**
  String
  get standardLocalDeliveriesTypicallyArriveWithinTheMerchantSDesignatedDeliveryWindowUsually3090MinutesForQuickCommerceItemsOr12BusinessDaysForStandardItems;

  /// No description provided for @estimatedDeliveryTimesAreDisplayedOnTheProductPageAndCheckoutScreen.
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery times are displayed on the product page and checkout screen.'**
  String
  get estimatedDeliveryTimesAreDisplayedOnTheProductPageAndCheckoutScreen;

  /// No description provided for @whatPaymentMethodsAreSupported.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are supported?'**
  String get whatPaymentMethodsAreSupported;

  /// No description provided for @weSupportManualCashOnDeliveryCodAndPhysicalPaymentUponDelivery.
  ///
  /// In en, this message translates to:
  /// **'We support Manual / Cash on Delivery (COD) and physical payment upon delivery. '**
  String get weSupportManualCashOnDeliveryCodAndPhysicalPaymentUponDelivery;

  /// No description provided for @theDeliveryPartnerOrMerchantUpdatesThePaymentStatusDirectlyOnceThePaymentIsCompleted.
  ///
  /// In en, this message translates to:
  /// **'The delivery partner or merchant updates the payment status directly once the payment is completed.'**
  String
  get theDeliveryPartnerOrMerchantUpdatesThePaymentStatusDirectlyOnceThePaymentIsCompleted;

  /// No description provided for @howDoRefundsWorkForCancelledOrders.
  ///
  /// In en, this message translates to:
  /// **'How do refunds work for cancelled orders?'**
  String get howDoRefundsWorkForCancelledOrders;

  /// No description provided for @ifAnOrderWasPrepaidOrCancelledBeforeFulfillmentYourRefundIsInitiatedImmediatelyByTheMerchant.
  ///
  /// In en, this message translates to:
  /// **'If an order was prepaid or cancelled before fulfillment, your refund is initiated immediately by the merchant. '**
  String
  get ifAnOrderWasPrepaidOrCancelledBeforeFulfillmentYourRefundIsInitiatedImmediatelyByTheMerchant;

  /// No description provided for @refundsTypicallyReflectInYourOriginalPaymentSourceWithin35BusinessDays.
  ///
  /// In en, this message translates to:
  /// **'Refunds typically reflect in your original payment source within 3–5 business days.'**
  String
  get refundsTypicallyReflectInYourOriginalPaymentSourceWithin35BusinessDays;

  /// No description provided for @whatIsTheReturnAndReplacementPolicy.
  ///
  /// In en, this message translates to:
  /// **'What is the return and replacement policy?'**
  String get whatIsTheReturnAndReplacementPolicy;

  /// No description provided for @eligibleItemsCanBeReturnedOrReplacedWithin7DaysOfDeliveryIfTheyAreDamagedDefectiveOrDifferentFromDescribed.
  ///
  /// In en, this message translates to:
  /// **'Eligible items can be returned or replaced within 7 days of delivery if they are damaged, defective, or different from described. '**
  String
  get eligibleItemsCanBeReturnedOrReplacedWithin7DaysOfDeliveryIfTheyAreDamagedDefectiveOrDifferentFromDescribed;

  /// No description provided for @toRequestAReturnGoToYourOrderDetailsOrSubmitAQueryUsingTheContactSupportFormWithPhotosOfTheDamagedItem.
  ///
  /// In en, this message translates to:
  /// **'To request a return, go to your order details or submit a query using the Contact Support form with photos of the damaged item.'**
  String
  get toRequestAReturnGoToYourOrderDetailsOrSubmitAQueryUsingTheContactSupportFormWithPhotosOfTheDamagedItem;

  /// No description provided for @howDoIAddOrManageMultipleDeliveryAddresses.
  ///
  /// In en, this message translates to:
  /// **'How do I add or manage multiple delivery addresses?'**
  String get howDoIAddOrManageMultipleDeliveryAddresses;

  /// No description provided for @goToAccountSavedAddressesToAddUpTo3SavedDeliveryLocationsHomeWorkOther.
  ///
  /// In en, this message translates to:
  /// **'Go to \"Account > Saved Addresses\" to add up to 3 saved delivery locations (Home, Work, Other). '**
  String
  get goToAccountSavedAddressesToAddUpTo3SavedDeliveryLocationsHomeWorkOther;

  /// No description provided for @youCanAlsoSelectOrSwitchYourActiveDeliveryAddressDirectlyFromTheTopBarOnTheHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'You can also select or switch your active delivery address directly from the top bar on the Home Screen.'**
  String
  get youCanAlsoSelectOrSwitchYourActiveDeliveryAddressDirectlyFromTheTopBarOnTheHomeScreen;

  /// No description provided for @howDoIApplyADiscountVoucherOrCouponCode.
  ///
  /// In en, this message translates to:
  /// **'How do I apply a discount voucher or coupon code?'**
  String get howDoIApplyADiscountVoucherOrCouponCode;

  /// No description provided for @duringCheckoutTapTheApplyVoucherSectionUnderOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'During checkout, tap the \"Apply Voucher\" section under Order Summary. '**
  String get duringCheckoutTapTheApplyVoucherSectionUnderOrderSummary;

  /// No description provided for @selectAnAvailablePromoCodeOrTypeYourVoucherCodeToInstantlyReceiveADiscountOnEligibleCartItems.
  ///
  /// In en, this message translates to:
  /// **'Select an available promo code or type your voucher code to instantly receive a discount on eligible cart items.'**
  String
  get selectAnAvailablePromoCodeOrTypeYourVoucherCodeToInstantlyReceiveADiscountOnEligibleCartItems;

  /// No description provided for @howIsMyPersonalDataAndAccountInformationSecured.
  ///
  /// In en, this message translates to:
  /// **'How is my personal data and account information secured?'**
  String get howIsMyPersonalDataAndAccountInformationSecured;

  /// No description provided for @weEmployIndustryStandardEncryptionProtocolsAndSecureAuthenticationTokensToProtectYourPersonalInformationDeliveryAddressesAndOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'We employ industry-standard encryption protocols and secure authentication tokens to protect your personal information, delivery addresses, and order history.'**
  String
  get weEmployIndustryStandardEncryptionProtocolsAndSecureAuthenticationTokensToProtectYourPersonalInformationDeliveryAddressesAndOrderHistory;

  /// No description provided for @shopByCategory.
  ///
  /// In en, this message translates to:
  /// **'Shop by Category'**
  String get shopByCategory;

  /// No description provided for @exploreAllShopsStores.
  ///
  /// In en, this message translates to:
  /// **'Explore All Shops & Stores'**
  String get exploreAllShopsStores;

  /// No description provided for @deliveryPickup.
  ///
  /// In en, this message translates to:
  /// **'Delivery & pickup'**
  String get deliveryPickup;

  /// No description provided for @noProductsInThisCategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get noProductsInThisCategory;

  /// No description provided for @viewCart2.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart2;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @inStock3.
  ///
  /// In en, this message translates to:
  /// **'In-Stock'**
  String get inStock3;

  /// No description provided for @price3.
  ///
  /// In en, this message translates to:
  /// **'Price ↓'**
  String get price3;

  /// No description provided for @price4.
  ///
  /// In en, this message translates to:
  /// **'Price ↑'**
  String get price4;

  /// No description provided for @price5.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price5;

  /// No description provided for @selfPickupOnly.
  ///
  /// In en, this message translates to:
  /// **'Self-Pickup only'**
  String get selfPickupOnly;

  /// No description provided for @homeDeliveryAvailableNoMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Home Delivery available • No min order'**
  String get homeDeliveryAvailableNoMinOrder;

  /// No description provided for @storefrontService.
  ///
  /// In en, this message translates to:
  /// **'Storefront service'**
  String get storefrontService;

  /// No description provided for @freeDeliveryOnYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery on your order'**
  String get freeDeliveryOnYourOrder;

  /// No description provided for @storeExclusiveDeal.
  ///
  /// In en, this message translates to:
  /// **'Store exclusive deal'**
  String get storeExclusiveDeal;

  /// No description provided for @freeDel.
  ///
  /// In en, this message translates to:
  /// **'FREE DEL'**
  String get freeDel;

  /// No description provided for @noMinOrder.
  ///
  /// In en, this message translates to:
  /// **'No min. order'**
  String get noMinOrder;

  /// No description provided for @deliverTo2.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo2;

  /// No description provided for @specialMarketplaceOffer.
  ///
  /// In en, this message translates to:
  /// **'Special Marketplace Offer'**
  String get specialMarketplaceOffer;

  /// No description provided for @exploreCategories.
  ///
  /// In en, this message translates to:
  /// **'Explore Categories'**
  String get exploreCategories;

  /// No description provided for @storeVouchersDeals.
  ///
  /// In en, this message translates to:
  /// **'Store Vouchers & Deals'**
  String get storeVouchersDeals;

  /// No description provided for @onAllOrders.
  ///
  /// In en, this message translates to:
  /// **'On all orders'**
  String get onAllOrders;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'COPIED'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get copy;

  /// No description provided for @shopsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Shops near you'**
  String get shopsNearYou;

  /// No description provided for @trendingNow2.
  ///
  /// In en, this message translates to:
  /// **'Trending Now 🔥'**
  String get trendingNow2;

  /// No description provided for @enterYour10DigitIndianMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your 10-digit Indian mobile number'**
  String get enterYour10DigitIndianMobileNumber;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @detectingYourCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting your current location...'**
  String get detectingYourCurrentLocation;

  /// No description provided for @autoDetectViaGpsDeviceNetwork.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect via GPS / Device network'**
  String get autoDetectViaGpsDeviceNetwork;

  /// No description provided for @maximum3AddressesSaved.
  ///
  /// In en, this message translates to:
  /// **'Maximum 3 addresses saved'**
  String get maximum3AddressesSaved;

  /// No description provided for @deliveryNotAvailableToThisPincode.
  ///
  /// In en, this message translates to:
  /// **'Delivery not available to this pincode'**
  String get deliveryNotAvailableToThisPincode;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @specifications.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get specifications;

  /// No description provided for @deliveryPolicies.
  ///
  /// In en, this message translates to:
  /// **'Delivery & Policies'**
  String get deliveryPolicies;

  /// No description provided for @allStoreProducts.
  ///
  /// In en, this message translates to:
  /// **'All Store Products'**
  String get allStoreProducts;

  /// No description provided for @browseAllProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse All Products'**
  String get browseAllProducts;

  ///
  ///
  /// In en, this message translates to:
  /// **'Category \"{category}\" created successfully!'**
  String categoryCreatedSuccessfully(String category);

  ///
  ///
  /// In en, this message translates to:
  /// **'Reordering inside \"{parentname}\"'**
  String reorderingInside(String parentname);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery charge created for {pincode}'**
  String deliveryChargeCreatedFor(String pincode);

  ///
  ///
  /// In en, this message translates to:
  /// **'Free on > {formatcurrency}'**
  String freeOn2(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Min: {formatcurrency}'**
  String min(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Employee \"{emp}\" provisioned successfully!'**
  String employeeProvisionedSuccessfully(String emp);

  ///
  ///
  /// In en, this message translates to:
  /// **'Discount{order}'**
  String discount2(String order);

  ///
  ///
  /// In en, this message translates to:
  /// **'Product \"{product}\" created successfully!'**
  String productCreatedSuccessfully(String product);

  ///
  ///
  /// In en, this message translates to:
  /// **'Stock: {product} {product2}'**
  String stock(String product, String product2);

  ///
  ///
  /// In en, this message translates to:
  /// **'{period} Order Report'**
  String orderReport(String period);

  ///
  ///
  /// In en, this message translates to:
  /// **'{voucher}/{voucher2} uses'**
  String uses(String voucher, String voucher2);

  ///
  ///
  /// In en, this message translates to:
  /// **'{voucher} uses (unlimited)'**
  String usesUnlimited(String voucher);

  ///
  ///
  /// In en, this message translates to:
  /// **'Voucher {voucher} created.'**
  String voucherCreated(String voucher);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not verify company. Please try again.\n{e}'**
  String couldNotVerifyCompanyPleaseTryAgain(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'{item} is unavailable'**
  String isUnavailable(String item);

  ///
  ///
  /// In en, this message translates to:
  /// **'{item} ({item2}) is unavailable'**
  String isUnavailable2(String item, String item2);

  ///
  ///
  /// In en, this message translates to:
  /// **'{item} is out of stock'**
  String isOutOfStock(String item);

  ///
  ///
  /// In en, this message translates to:
  /// **'{item}: quantity reduced to {qty} (stock)'**
  String quantityReducedToStock(String item, String qty);

  ///
  ///
  /// In en, this message translates to:
  /// **'Price updated for {item}'**
  String priceUpdatedFor(String item);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not place the order: {e}'**
  String couldNotPlaceTheOrder(String e);

  ///
  ///
  /// In en, this message translates to:
  /// **'Confirm & Place Order · {formatcurrency}'**
  String confirmPlaceOrder(String formatcurrency);

  ///
  ///
  /// In en, this message translates to:
  /// **'Self-Pickup only • Min order {minorderformatted}'**
  String selfPickupOnlyMinOrder(String minorderformatted);

  ///
  ///
  /// In en, this message translates to:
  /// **'Home Delivery available • Min order {minorderformatted}'**
  String homeDeliveryAvailableMinOrder(String minorderformatted);

  ///
  ///
  /// In en, this message translates to:
  /// **'Flat {top}% OFF'**
  String flatOff(String top);

  ///
  ///
  /// In en, this message translates to:
  /// **'Flat ₹{top} OFF'**
  String flatOff2(String top);

  ///
  ///
  /// In en, this message translates to:
  /// **'Valid on orders over ₹{top}'**
  String validOnOrdersOver(String top);

  ///
  ///
  /// In en, this message translates to:
  /// **'Orders over ₹{voucher}'**
  String ordersOver(String voucher);

  ///
  ///
  /// In en, this message translates to:
  /// **'Deliver to {activeaddress}'**
  String deliverTo(String activeaddress);

  ///
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =1{1 item added to cart} other{{added} items added to cart}}'**
  String itemsAddedToCart(num added);

  ///
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 product selected} other{{n} products selected}}'**
  String productsSelected(num n);

  /// No description provided for @shopSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop Settings'**
  String get shopSettings;

  /// No description provided for @shopSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Description, hours & delivery'**
  String get shopSettingsSubtitle;

  /// No description provided for @shopNoShopLinked.
  ///
  /// In en, this message translates to:
  /// **'No shop is linked to this account.'**
  String get shopNoShopLinked;

  /// No description provided for @shopNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shop not found.'**
  String get shopNotFound;

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not load shop details: {error}'**
  String shopCouldNotLoad(String error);

  /// No description provided for @shopDetailsSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop details saved.'**
  String get shopDetailsSaved;

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String shopCouldNotSave(String error);

  /// No description provided for @shopFixFields.
  ///
  /// In en, this message translates to:
  /// **'Please fix the highlighted fields.'**
  String get shopFixFields;

  /// No description provided for @shopDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get shopDetailsTitle;

  /// No description provided for @shopDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What shoppers read about your shop.'**
  String get shopDetailsSubtitle;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopNameLabel;

  /// No description provided for @shopNameHelper.
  ///
  /// In en, this message translates to:
  /// **'This is also your admin login, so it can only be changed by support.'**
  String get shopNameHelper;

  /// No description provided for @shopCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Store category'**
  String get shopCategoryLabel;

  /// No description provided for @shopCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Furniture and Home Decor'**
  String get shopCategoryHint;

  /// No description provided for @shopPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get shopPhoneLabel;

  /// No description provided for @shopPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown on pickup cards'**
  String get shopPhoneHelper;

  /// No description provided for @shopDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get shopDescriptionLabel;

  /// No description provided for @shopDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a short description of your shop'**
  String get shopDescriptionRequired;

  /// No description provided for @shopAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get shopAddressLabel;

  /// No description provided for @shopAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get shopAddressRequired;

  /// No description provided for @shopMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Map link (Google Maps)'**
  String get shopMapLabel;

  /// No description provided for @shopHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get shopHoursTitle;

  /// No description provided for @shopHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shoppers see whether you are open right now.'**
  String get shopHoursSubtitle;

  /// No description provided for @shopOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get shopOpenNow;

  /// No description provided for @shopClosedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get shopClosedNow;

  /// No description provided for @shopDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get shopDayClosed;

  /// No description provided for @shopTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get shopTo;

  /// No description provided for @shopOpen24Hours.
  ///
  /// In en, this message translates to:
  /// **'Open 24 hours'**
  String get shopOpen24Hours;

  /// No description provided for @shopClosesNextDay.
  ///
  /// In en, this message translates to:
  /// **'closes next day'**
  String get shopClosesNextDay;

  ///
  ///
  /// In en, this message translates to:
  /// **'Apply {day} hours to every day'**
  String shopApplyHoursToAll(String day);

  /// No description provided for @shopDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery & orders'**
  String get shopDeliveryTitle;

  /// No description provided for @shopDeliverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How shoppers can receive their orders.'**
  String get shopDeliverySubtitle;

  /// No description provided for @shopSelfPickup.
  ///
  /// In en, this message translates to:
  /// **'Self-pickup from the shop'**
  String get shopSelfPickup;

  /// No description provided for @shopHomeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Home delivery'**
  String get shopHomeDelivery;

  /// No description provided for @shopChooseDeliveryOption.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one delivery option.'**
  String get shopChooseDeliveryOption;

  /// No description provided for @shopMinOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum order for delivery'**
  String get shopMinOrderLabel;

  /// No description provided for @shopMinOrderHelper.
  ///
  /// In en, this message translates to:
  /// **'0 means no minimum'**
  String get shopMinOrderHelper;

  /// No description provided for @shopCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get shopCurrencyLabel;

  /// No description provided for @shopCurrencyHelper.
  ///
  /// In en, this message translates to:
  /// **'Fixed once the shop is created'**
  String get shopCurrencyHelper;

  /// No description provided for @shopHandlingLabel.
  ///
  /// In en, this message translates to:
  /// **'Packing time (minutes)'**
  String get shopHandlingLabel;

  /// No description provided for @shopHandlingHelper.
  ///
  /// In en, this message translates to:
  /// **'Used for the order ETA'**
  String get shopHandlingHelper;

  /// No description provided for @shopDeliveryMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery time (minutes)'**
  String get shopDeliveryMinutesLabel;

  /// No description provided for @shopDeliveryMinutesHelper.
  ///
  /// In en, this message translates to:
  /// **'Once the parcel leaves the shop'**
  String get shopDeliveryMinutesHelper;

  /// No description provided for @shopBrandingTitle.
  ///
  /// In en, this message translates to:
  /// **'Branding images'**
  String get shopBrandingTitle;

  /// No description provided for @shopBrandingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste an image link; tap a preview to see it full screen.'**
  String get shopBrandingSubtitle;

  /// No description provided for @shopLogoLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get shopLogoLabel;

  /// No description provided for @shopBannerLabel.
  ///
  /// In en, this message translates to:
  /// **'Banner'**
  String get shopBannerLabel;

  /// No description provided for @shopStorefrontLabel.
  ///
  /// In en, this message translates to:
  /// **'Storefront image'**
  String get shopStorefrontLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'{label} (image link)'**
  String shopImageLinkLabel(String label);

  /// No description provided for @shopMapLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'The map link must start with http:// or https://'**
  String get shopMapLinkInvalid;

  ///
  ///
  /// In en, this message translates to:
  /// **'The {label} link must start with http:// or https://'**
  String shopImageLinkInvalid(String label);

  /// No description provided for @shopPhoneChars.
  ///
  /// In en, this message translates to:
  /// **'Use digits, spaces, + or - only'**
  String get shopPhoneChars;

  /// No description provided for @shopPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get shopPhoneInvalid;

  /// No description provided for @shopMoneyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 0 or a positive amount'**
  String get shopMoneyInvalid;

  /// No description provided for @shopMinutesInvalid.
  ///
  /// In en, this message translates to:
  /// **'1 - 1440 minutes'**
  String get shopMinutesInvalid;

  /// No description provided for @shopUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes'**
  String get shopUnsavedChanges;

  /// No description provided for @shopAllSaved.
  ///
  /// In en, this message translates to:
  /// **'All changes saved'**
  String get shopAllSaved;

  /// No description provided for @shopDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get shopDiscard;

  /// No description provided for @shopSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get shopSaveChanges;

  ///
  ///
  /// In en, this message translates to:
  /// **'{day}: enter valid opening and closing times.'**
  String shopHoursInvalidTime(String day);

  ///
  ///
  /// In en, this message translates to:
  /// **'{day}: opening and closing time cannot be the same.'**
  String shopHoursSameTime(String day);

  /// No description provided for @shopHoursNoOpenDay.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one day open.'**
  String get shopHoursNoOpenDay;

  /// No description provided for @shopStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shopStatusActive;

  /// No description provided for @shopStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get shopStatusSuspended;

  /// No description provided for @shopStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get shopStatusInactive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
