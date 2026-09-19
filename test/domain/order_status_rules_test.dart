import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/order_status.dart';
import 'package:myshop/core/models/order.dart';

void main() {
  group('OrderStatusRules — transitions', () {
    test('the happy path advances one stage at a time', () {
      expect(OrderStatusRules.nextStage(OrderStatus.pending), OrderStatus.confirmed);
      expect(OrderStatusRules.nextStage(OrderStatus.confirmed), OrderStatus.packing);
      expect(OrderStatusRules.nextStage(OrderStatus.packing), OrderStatus.ready);
      expect(OrderStatusRules.nextStage(OrderStatus.ready), OrderStatus.onTheWay);
      expect(OrderStatusRules.nextStage(OrderStatus.onTheWay), OrderStatus.completed);
      expect(OrderStatusRules.nextStage(OrderStatus.completed), isNull);
      expect(OrderStatusRules.nextStage(OrderStatus.cancelled), isNull);
    });

    test('nextStage ignores cancellation', () {
      expect(
        OrderStatusRules.allowedNext(OrderStatus.pending),
        contains(OrderStatus.cancelled),
      );
      expect(OrderStatusRules.nextStage(OrderStatus.pending), isNot(OrderStatus.cancelled));
    });

    test('backwards and nonsense transitions are refused', () {
      expect(OrderStatusRules.canTransition(OrderStatus.completed, OrderStatus.pending), isFalse);
      expect(OrderStatusRules.canTransition(OrderStatus.pending, OrderStatus.completed), isFalse);
      expect(OrderStatusRules.canTransition(OrderStatus.cancelled, OrderStatus.pending), isFalse);
      expect(OrderStatusRules.canTransition(OrderStatus.onTheWay, OrderStatus.packing), isFalse);
    });

    test('legal moves are allowed and a no-op is always safe', () {
      expect(OrderStatusRules.canTransition(OrderStatus.pending, OrderStatus.confirmed), isTrue);
      expect(OrderStatusRules.canTransition(OrderStatus.pending, OrderStatus.cancelled), isTrue);
      expect(OrderStatusRules.canTransition(OrderStatus.ready, OrderStatus.onTheWay), isTrue);
      expect(OrderStatusRules.canTransition(OrderStatus.packing, OrderStatus.packing), isTrue);
    });

    test('unknown statuses have no allowed moves', () {
      expect(OrderStatusRules.allowedNext('teleported'), isEmpty);
      expect(OrderStatusRules.isTerminal('teleported'), isTrue);
    });

    test('ensureTransition throws with a helpful message', () {
      expect(
        () => OrderStatusRules.ensureTransition(
          OrderStatus.completed,
          OrderStatus.pending,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Illegal order status transition'),
          ),
        ),
      );
      expect(
        () => OrderStatusRules.ensureTransition(OrderStatus.pending, OrderStatus.confirmed),
        returnsNormally,
      );
    });

    test('ensureValidStatus rejects unknown values', () {
      expect(() => OrderStatusRules.ensureValidStatus('nope'), throwsArgumentError);
      expect(() => OrderStatusRules.ensureValidStatus(OrderStatus.ready), returnsNormally);
    });
  });

  group('OrderStatusRules — queries', () {
    test('terminal, open and cancellable', () {
      expect(OrderStatusRules.isTerminal(OrderStatus.completed), isTrue);
      expect(OrderStatusRules.isTerminal(OrderStatus.cancelled), isTrue);
      expect(OrderStatusRules.isTerminal(OrderStatus.packing), isFalse);

      expect(OrderStatusRules.isOpen(OrderStatus.pending), isTrue);
      expect(OrderStatusRules.isOpen(OrderStatus.cancelled), isFalse);

      expect(OrderStatusRules.isCancellable(OrderStatus.pending), isTrue);
      expect(OrderStatusRules.isCancellable(OrderStatus.packing), isTrue);
      expect(OrderStatusRules.isCancellable(OrderStatus.onTheWay), isFalse,
          reason: 'a parcel on the road cannot be cancelled');
      expect(OrderStatusRules.isCancellable(OrderStatus.completed), isFalse);
    });

    test('tracker index follows the customer facing chain', () {
      expect(OrderStatusRules.trackerIndex(OrderStatus.pending), 0);
      expect(OrderStatusRules.trackerIndex(OrderStatus.completed), 5);
      expect(
        OrderStatusRules.trackerIndex(OrderStatus.cancelled),
        -1,
        reason: 'cancelled is not part of the tracker',
      );
    });

    test('the board shows cancelled orders too', () {
      expect(OrderStatusRules.boardColumns, contains(OrderStatus.cancelled));
      expect(OrderStatusRules.boardColumns.length, OrderStatus.all.length);
    });

    test('every status in the model is covered by the machine', () {
      for (final status in OrderStatus.all) {
        expect(OrderStatusRules.transitions.containsKey(status), isTrue,
            reason: '$status is missing from the transition table');
      }
    });

    test('previousStage walks backwards', () {
      expect(OrderStatusRules.previousStage(OrderStatus.ready), OrderStatus.packing);
      expect(OrderStatusRules.previousStage(OrderStatus.pending), isNull);
    });
  });
}
