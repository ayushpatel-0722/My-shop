import '../models/banner.dart';
import '../models/category.dart';
import '../models/company.dart';
import '../models/delivery_charge.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../models/voucher.dart';

/// In-memory seed data. In production this comes from Firestore.
class MockData {
  // ---------- Companies ----------
  static final companies = <Company>[
    Company(
      id: 'c_organic',
      name: 'GreenLeaf Organics',
      slug: 'greenleaf-organics',
      companyPassword: 'green@123',
      details: 'Farm-fresh organic groceries delivered daily.',
      address: '12 Market Street, Ahmedabad',
      location: 'https://maps.google.com/?q=Ahmedabad',
      currency: 'INR',
      deliveryTypes: const ['self_pickup', 'home_delivery'],
      weeklyHours: Company.defaultWeek(),
    ),
    Company(
      id: 'c_techtronics',
      name: 'TechTronics Hub',
      slug: 'techtronics-hub',
      companyPassword: 'tech@123',
      details: 'Gadgets, accessories and smart electronics.',
      address: '45 Circuit Avenue, Ahmedabad',
      location: 'https://maps.google.com/?q=Ahmedabad',
      currency: 'INR',
      deliveryTypes: const ['home_delivery'],
      weeklyHours: Company.defaultWeek(),
    ),
  ];

  // ---------- Categories ----------
  static final categories = <Category>[
    const Category(id: 'cat_veg', name: 'Vegetables', type: 'Grocery',
        iconUrl: '🥦'),
    const Category(id: 'cat_fruit', name: 'Fruits', type: 'Grocery',
        iconUrl: '🍎'),
    const Category(id: 'cat_dairy', name: 'Dairy & Eggs', type: 'Grocery',
        iconUrl: '🥛'),
    const Category(id: 'cat_phone', name: 'Phones', type: 'Electronics',
        iconUrl: '📱'),
    const Category(id: 'cat_audio', name: 'Audio', type: 'Electronics',
        iconUrl: '🎧'),
    const Category(id: 'cat_wear', name: 'Wearables', type: 'Electronics',
        iconUrl: '⌚'),
  ];

  // ---------- Products ----------
  static final products = <Product>[
    // GreenLeaf Organics
    const Product(
      id: 'p_tomato',
      companyId: 'c_organic',
      categoryId: 'cat_veg',
      name: 'Fresh Tomatoes',
      details: 'Vine-ripened, pesticide-free tomatoes.',
      type: 'weight_based',
      unit: 500,
      unitType: 'grams',
      amount: 60,
      discountAmt: 48,
      images: [],
      stockQty: 120,
      isRecommended: true,
    ),
    const Product(
      id: 'p_spinach',
      companyId: 'c_organic',
      categoryId: 'cat_veg',
      name: 'Baby Spinach',
      details: 'Tender, nutrient-rich spinach leaves.',
      type: 'weight_based',
      unit: 250,
      unitType: 'grams',
      amount: 40,
      stockQty: 80,
    ),
    const Product(
      id: 'p_apple',
      companyId: 'c_organic',
      categoryId: 'cat_fruit',
      name: 'Himalayan Apples',
      details: 'Crisp and juicy orchard apples.',
      type: 'weight_based',
      unit: 1,
      unitType: 'kg',
      amount: 180,
      discountAmt: 150,
      images: [],
      stockQty: 60,
      isRecommended: true,
    ),
    const Product(
      id: 'p_milk',
      companyId: 'c_organic',
      categoryId: 'cat_dairy',
      name: 'Organic Cow Milk',
      details: 'Fresh, full-cream organic milk.',
      type: 'quantity_based',
      unit: 1,
      unitType: 'liters',
      amount: 68,
      stockQty: 200,
    ),
    // TechTronics Hub
    const Product(
      id: 'p_phone',
      companyId: 'c_techtronics',
      categoryId: 'cat_phone',
      name: 'Nova X5 Smartphone',
      details: '6.7" AMOLED, 128GB, 50MP camera.',
      type: 'quantity_based',
      unit: 1,
      unitType: 'pieces',
      amount: 24999,
      discountAmt: 21999,
      images: [],
      stockQty: 25,
      isRecommended: true,
      variants: [
        ProductVariant(color: 'Black', sku: 'NOVA-X5-BLK', stockQty: 15),
        ProductVariant(color: 'Silver', sku: 'NOVA-X5-SLV', stockQty: 10),
      ],
    ),
    const Product(
      id: 'p_buds',
      companyId: 'c_techtronics',
      categoryId: 'cat_audio',
      name: 'AirBeat Wireless Buds',
      details: 'Active noise cancellation, 30h battery.',
      type: 'quantity_based',
      unit: 1,
      unitType: 'pieces',
      amount: 2999,
      discountAmt: 2499,
      images: [],
      stockQty: 80,
      isRecommended: true,
    ),
    const Product(
      id: 'p_watch',
      companyId: 'c_techtronics',
      categoryId: 'cat_wear',
      name: 'PulseFit Smartwatch',
      details: 'Heart-rate, SpO2 and GPS tracking.',
      type: 'quantity_based',
      unit: 1,
      unitType: 'pieces',
      amount: 4999,
      stockQty: 40,
    ),
  ];

  // ---------- Ad banners (platform-wide) ----------
  static final adBanners = <AdBanner>[
    const AdBanner(
      id: 'ad_1',
      image: '',
      actionType: BannerActionType.product,
      actionTarget: 'p_phone',
      priority: 1,
    ),
    const AdBanner(
      id: 'ad_2',
      image: '',
      actionType: BannerActionType.category,
      actionTarget: 'cat_veg',
      priority: 2,
    ),
    const AdBanner(
      id: 'ad_3',
      image: '',
      actionType: BannerActionType.companyPage,
      actionTarget: 'greenleaf-organics',
      priority: 3,
    ),
  ];

  // ---------- Company offer banners ----------
  static final offerBanners = <OfferBanner>[
    const OfferBanner(
      id: 'ob_1',
      companyId: 'c_organic',
      image: '',
      actionType: BannerActionType.category,
      targetCatId: 'cat_fruit',
      priority: 1,
    ),
    const OfferBanner(
      id: 'ob_2',
      companyId: 'c_techtronics',
      image: '',
      actionType: BannerActionType.product,
      targetProdId: 'p_phone',
      priority: 1,
    ),
  ];

  // ---------- Vouchers ----------
  static final vouchers = <Voucher>[
    Voucher(
      id: 'v_1',
      companyId: 'c_organic',
      code: 'FRESH20',
      discountType: 'percentage',
      discountValue: 20,
      appliesTo: 'all_categories',
      minOrderAmt: 100,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    ),
    Voucher(
      id: 'v_2',
      companyId: 'c_techtronics',
      code: 'TECH1000',
      discountType: 'fixed_amount',
      discountValue: 1000,
      appliesTo: 'all_categories',
      minOrderAmt: 5000,
      expiryDate: DateTime.now().add(const Duration(days: 15)),
    ),
    Voucher(
      id: 'v_3',
      companyId: 'c_organic',
      code: 'FREESHIP',
      discountType: 'free_shipping',
      appliesTo: 'all_categories',
      minOrderAmt: 0,
      expiryDate: DateTime.now().add(const Duration(days: 60)),
    ),
  ];

  // ---------- Delivery charges ----------
  static final deliveryCharges = <DeliveryCharge>[
    const DeliveryCharge(pincode: '380001', charge: 30),
    const DeliveryCharge(pincode: '380002', charge: 40),
    const DeliveryCharge(pincode: '380005', charge: 25),
    const DeliveryCharge(pincode: '400001', charge: 60),
  ];

  // ---------- Reviews ----------
  static final reviews = <Review>[
    Review(
      id: 'r_1',
      orderId: 'o_seed_1',
      userId: 'u_seed',
      userName: 'Priya S.',
      companyId: 'c_organic',
      rating: 5,
      message: 'Super fresh vegetables, delivered on time!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Review(
      id: 'r_2',
      orderId: 'o_seed_2',
      userId: 'u_seed2',
      userName: 'Rahul M.',
      companyId: 'c_techtronics',
      rating: 4,
      message: 'Great phone, quick delivery.',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
}
