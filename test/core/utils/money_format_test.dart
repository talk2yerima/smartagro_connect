import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/utils/money_format.dart';

void main() {
  group('formatNgn', () {
    test('formats zero', () {
      expect(formatNgn(0), '₦0');
    });

    test('formats whole thousands with comma separator', () {
      expect(formatNgn(1000), '₦1,000');
    });

    test('formats large values', () {
      expect(formatNgn(1500000), '₦1,500,000');
    });

    test('truncates decimals', () {
      expect(formatNgn(350.9), '₦351');
    });

    test('uses Naira symbol', () {
      expect(formatNgn(500).startsWith('₦'), isTrue);
    });
  });
}
