import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/domain/entities/price_alert.dart';

void main() {
  test('a target above today\'s price waits for a rise, below for a fall', () {
    expect(PriceAlert.directionFor(target: 30000, current: 28000), isTrue);
    expect(PriceAlert.directionFor(target: 25000, current: 28000), isFalse);
  });

  test('reads an alert, including one that has fired', () {
    final a = PriceAlert.fromMap('a1', const {
      'commodityId': 'maize',
      'targetNgn': 25000,
      'direction': 'below',
      'active': false,
    });
    expect(a.above, isFalse);
    expect(a.active, isFalse);
    expect(a.targetNgn, 25000);
  });
}
