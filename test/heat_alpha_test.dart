import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/heat_alpha.dart';

void main() {
  group('heatAlpha', () {
    test('units: 0.15 per unit, within 0.25..1.0', () {
      expect(heatAlpha(0), 0.25);
      expect(heatAlpha(1), closeTo(0.40, 1e-9));
      expect(heatAlpha(3), closeTo(0.70, 1e-9));
      expect(heatAlpha(20), 1.0);
    });

    test('duration: scaled by minutes, full at an hour', () {
      expect(heatAlpha(0, isDuration: true), 0.25);
      expect(heatAlpha(30, isDuration: true), closeTo(0.625, 1e-9));
      expect(heatAlpha(60, isDuration: true), 1.0);
      expect(heatAlpha(300, isDuration: true), 1.0);
    });

    test('a few minutes are visible but not saturated', () {
      expect(heatAlpha(5, isDuration: true), lessThan(0.4));
    });
  });
}
