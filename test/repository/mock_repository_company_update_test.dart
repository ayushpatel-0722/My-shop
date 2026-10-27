import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/company.dart';

void main() {
  late MockAppRepository repo;

  const original = Company(
    id: 'c_edit',
    name: 'Woodnest Living',
    slug: 'woodnest-living',
    companyPassword: 'secret-pass',
    status: 'active',
    details: 'Old description',
    address: 'Old address',
    category: 'Furniture',
    currency: 'INR',
    rating: 4.5,
    reviewCount: 12,
    followers: 7,
    isVerified: true,
    deliveryTypes: ['self_pickup'],
    minOrderAmount: 500,
  );

  setUp(() async {
    repo = MockAppRepository();
    await repo.createCompany(original);
  });

  test('updateCompanyDetails saves every editable field', () async {
    final edited = original.copyWith(
      details: 'New description',
      address: 'New address',
      phone: '+91 98765 43210',
      location: 'https://maps.example.com/x',
      category: 'Home Decor',
      logoUrl: 'https://img.example.com/logo.jpg',
      bannerUrl: 'https://img.example.com/banner.jpg',
      profileImageUrl: 'https://img.example.com/front.jpg',
      deliveryTypes: ['self_pickup', 'home_delivery'],
      weeklyHours: [
        const WeeklyHours(day: 'Mon', openTime: '10:00', closeTime: '20:00'),
      ],
      handlingMinutes: 60,
      deliveryMinutes: 90,
      minOrderAmount: 1500,
    );
    await repo.updateCompanyDetails(edited);

    final saved = (await repo.company('c_edit'))!;
    expect(saved.details, 'New description');
    expect(saved.address, 'New address');
    expect(saved.phone, '+91 98765 43210');
    expect(saved.location, 'https://maps.example.com/x');
    expect(saved.category, 'Home Decor');
    expect(saved.logoUrl, 'https://img.example.com/logo.jpg');
    expect(saved.bannerUrl, 'https://img.example.com/banner.jpg');
    expect(saved.profileImageUrl, 'https://img.example.com/front.jpg');
    expect(saved.deliveryTypes, ['self_pickup', 'home_delivery']);
    expect(saved.weeklyHours.single.openTime, '10:00');
    expect(saved.handlingMinutes, 60);
    expect(saved.deliveryMinutes, 90);
    expect(saved.minOrderAmount, 1500);
  });

  test(
    'identity, password, status and ratings can never be overwritten',
    () async {
      // Even if a caller passes a company with tampered protected fields...
      final tampered = original.copyWith(
        details: 'Edited',
        name: 'Hijacked Name',
        slug: 'hijacked',
        companyPassword: 'new-password',
        status: 'suspended',
        currency: 'USD',
        rating: 1.0,
        reviewCount: 0,
        followers: 0,
        isVerified: false,
      );
      await repo.updateCompanyDetails(tampered);

      final saved = (await repo.company('c_edit'))!;
      expect(saved.details, 'Edited', reason: 'the editable part is saved');
      expect(saved.name, 'Woodnest Living');
      expect(saved.slug, 'woodnest-living');
      expect(saved.companyPassword, 'secret-pass');
      expect(saved.status, 'active');
      expect(saved.currency, 'INR');
      expect(saved.rating, 4.5);
      expect(saved.reviewCount, 12);
      expect(saved.followers, 7);
      expect(saved.isVerified, isTrue);
    },
  );

  test('the companies stream emits the update', () async {
    final emissions = <List<Company>>[];
    final sub = repo.companies().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(emissions, isNotEmpty, reason: 'initial snapshot');
    final before = emissions.length;

    await repo.updateCompanyDetails(original.copyWith(address: 'Streamed'));
    await pumpEventQueue();

    expect(emissions.length, greaterThan(before));
    expect(
      emissions.last.firstWhere((c) => c.id == 'c_edit').address,
      'Streamed',
    );
  });

  test('updating an unknown company fails loudly', () async {
    expect(
      () => repo.updateCompanyDetails(original.copyWith(id: 'nope')),
      throwsStateError,
    );
  });

  test('toEditableMap never includes protected fields', () {
    final keys = original.toEditableMap().keys.toSet();
    for (final protected in [
      'name',
      'slug',
      'companyPassword',
      'status',
      'currency',
      'rating',
      'reviewCount',
      'followers',
      'isVerified',
      'openingDate',
    ]) {
      expect(keys, isNot(contains(protected)), reason: protected);
    }
  });
}
