import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/screens/analytics_screen.dart';

void main() {
  group('fmtMoney', () {
    test('formats whole and cents with grouping', () {
      expect(fmtMoney(1250, '\$'), '\$1,250.00');
      expect(fmtMoney(0, '\$'), '\$0.00');
      expect(fmtMoney(1234567.5, '\$'), '\$1,234,567.50');
    });

    test('carries cents that round up to 100 (regression: no "\$19.100")', () {
      expect(fmtMoney(19.9952, '\$'), '\$20.00');
      expect(fmtMoney(9.9992, '\$'), '\$10.00');
      expect(fmtMoney(99.999, '\$'), '\$100.00');
      expect(fmtMoney(0.999, '\$'), '\$1.00');
    });

    test('handles non-\$ symbols', () {
      expect(fmtMoney(100, 'XOF'), 'XOF100.00');
      expect(fmtMoney(50.5, '€'), '€50.50');
    });
  });

  group('fmtMoneyCompact', () {
    test('compacts thousands', () {
      expect(fmtMoneyCompact(1500, '\$'), '\$1.5k');
      expect(fmtMoneyCompact(1000, '\$'), '\$1.0k');
    });

    test('gates on rounded magnitude (regression: 999.6 -> "\$1.0k")', () {
      expect(fmtMoneyCompact(999.6, '\$'), '\$1.0k');
      expect(fmtMoneyCompact(999.4, '\$'), '\$999');
    });

    test('leaves sub-thousand values uncompacted', () {
      expect(fmtMoneyCompact(250, '\$'), '\$250');
      expect(fmtMoneyCompact(0, '\$'), '\$0');
    });
  });
}
