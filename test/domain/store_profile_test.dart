import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/order_eta.dart';
import 'package:myshop/core/domain/store_profile.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/review.dart';

Company _shop({required List<WeeklyHours> hours}) => Company(
  id: 'c_1',
  name: 'Test Shop',
  slug: 'test-shop',
  weeklyHours: hours,
);

void main() {
  final standardWeek = [
    for (var i = 0; i < 6; i++)
      const WeeklyHours(day: 'Mon', openTime: '09:00', closeTime: '21:00'),
    const WeeklyHours(
      day: 'Sun',
      openTime: '00:00',
      closeTime: '00:00',
      isClosed: true,
    ),
  ];

  group('StoreHours.prettyTime', () {
    test('formats on-the-hour times without minutes', () {
      expect(StoreHours.prettyTime('21:00'), '9 PM');
      expect(StoreHours.prettyTime('09:00'), '9 AM');
      expect(StoreHours.prettyTime('00:00'), '12 AM');
      expect(StoreHours.prettyTime('12:00'), '12 PM');
    });

    test('keeps minutes when they matter', () {
      expect(StoreHours.prettyTime('09:30'), '9:30 AM');
      expect(StoreHours.prettyTime('18:45'), '6:45 PM');
    });
  });

  group('StoreHours.isOpenAt', () {
    test('open during the day, closed after closing time', () {
      final shop = _shop(hours: standardWeek);
      final monday = DateTime(2026, 9, 21); // a Monday
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 21, 10)), isTrue);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 21, 20, 59)), isTrue);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 21, 21, 0)), isFalse);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 21, 8, 59)), isFalse);
      expect(monday.weekday, 1, reason: 'sanity: 2026-09-21 is a Monday');
    });

    test('respects the closed day', () {
      final shop = _shop(hours: standardWeek);
      // Sunday 2026-09-27.
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 27, 12)), isFalse);
    });

    test('an empty timetable means always open', () {
      final shop = _shop(hours: const []);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 27, 3)), isTrue);
    });

    test('overnight shifts stay open past midnight', () {
      final overnight = [
        const WeeklyHours(day: 'Mon', openTime: '22:00', closeTime: '06:00'),
        ...List.generate(
          6,
          (_) =>
              const WeeklyHours(day: '', openTime: '22:00', closeTime: '06:00'),
        ),
      ];
      final shop = _shop(hours: overnight);

      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 21, 23)), isTrue);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 22, 5, 59)), isTrue);
      expect(StoreHours.isOpenAt(shop, DateTime(2026, 9, 22, 6, 0)), isFalse);
    });
  });

  group('StoreHours labels', () {
    test('open label mentions the closing time', () {
      final shop = _shop(hours: standardWeek);
      expect(
        StoreHours.openLabel(shop, DateTime(2026, 9, 21, 10)),
        'Open Now · Closes 9 PM',
      );
    });

    test('closed label mentions the next opening (later today)', () {
      final shop = _shop(hours: standardWeek);
      expect(
        StoreHours.closedLabel(shop, DateTime(2026, 9, 21, 7)),
        'Closed · Opens 9 AM',
      );
    });

    test('closed label names the day when it reopens later', () {
      final shop = _shop(hours: standardWeek);
      // Sunday afternoon -> next opening is Monday 9 AM.
      expect(
        StoreHours.closedLabel(shop, DateTime(2026, 9, 27, 15)),
        'Closed · Opens 9 AM Mon',
      );
    });
  });

  group('StoreStats', () {
    test('averages only visible reviews', () {
      final stats = StoreStats.fromReviews([
        const Review(
          id: 'a',
          orderId: 'o1',
          userId: 'u',
          companyId: 'c',
          rating: 5,
        ),
        const Review(
          id: 'b',
          orderId: 'o2',
          userId: 'u',
          companyId: 'c',
          rating: 3,
        ),
        const Review(
          id: 'hidden',
          orderId: 'o3',
          userId: 'u',
          companyId: 'c',
          rating: 1,
          isVisible: false,
        ),
      ], followerCount: 128);

      expect(stats.averageRating, 4);
      expect(stats.reviewCount, 2);
      expect(stats.ratingLabel, '4.0');
      expect(stats.followerLabel, '128 followers');
    });

    test('a shop with no reviews is "New", never a fake 5.0', () {
      final stats = StoreStats.fromReviews(const [], followerCount: 1);
      expect(stats.ratingLabel, 'New');
      expect(stats.followerLabel, '1 follower');
    });
  });

  group('OrderEta', () {
    final company = Company(
      id: 'c_1',
      name: 'Test Shop',
      slug: 'test-shop',
      handlingMinutes: 30,
      deliveryMinutes: 20,
    );

    Order orderWith({
      String status = OrderStatus.pending,
      String deliveryType = DeliveryType.homeDelivery,
    }) => Order(
      id: 'o_1',
      userId: 'u',
      companyId: 'c_1',
      orderStatus: status,
      deliveryType: deliveryType,
      items: const [OrderItem(productId: 'p', qty: 1, unitPrice: 10)],
    );

    final now = DateTime(2026, 9, 21, 17); // 5:00 PM Monday.

    test('packing + home delivery includes handling and delivery time', () {
      expect(
        OrderEta.label(orderWith(status: OrderStatus.packing), company, now),
        'Arriving by 5:50 PM today',
      );
    });

    test('packing + pickup only waits for handling', () {
      expect(
        OrderEta.label(
          orderWith(
            status: OrderStatus.packing,
            deliveryType: DeliveryType.selfPickup,
          ),
          company,
          now,
        ),
        'Ready for pickup by 5:30 PM today',
      );
    });

    test('ready + pickup is nearly immediate', () {
      expect(
        OrderEta.label(
          orderWith(
            status: OrderStatus.ready,
            deliveryType: DeliveryType.selfPickup,
          ),
          company,
          now,
        ),
        'Ready for pickup by 5:10 PM today',
      );
    });

    test('on the way only adds the delivery leg', () {
      expect(
        OrderEta.label(orderWith(status: OrderStatus.onTheWay), company, now),
        'Arriving by 5:20 PM today',
      );
    });

    test('statuses without a moving parcel get no ETA', () {
      for (final status in [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.completed,
        OrderStatus.cancelled,
      ]) {
        expect(OrderEta.label(orderWith(status: status), company, now), isNull);
      }
    });

    test('an ETA past midnight says tomorrow', () {
      final late = DateTime(2026, 9, 21, 23, 45);
      expect(
        OrderEta.label(orderWith(status: OrderStatus.onTheWay), company, late),
        'Arriving by 12:05 AM tomorrow',
      );
    });

    test('progress follows the tracker chain', () {
      expect(OrderEta.progress(OrderStatus.pending), closeTo(1 / 6, 0.001));
      expect(OrderEta.progress(OrderStatus.confirmed), closeTo(2 / 6, 0.001));
      expect(OrderEta.progress(OrderStatus.onTheWay), closeTo(5 / 6, 0.001));
      expect(OrderEta.progress(OrderStatus.completed), 1);
      expect(OrderEta.progress(OrderStatus.cancelled), 0);
    });
  });
}
