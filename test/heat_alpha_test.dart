import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/utils/heat_alpha.dart';

void main() {
  group('heatAlpha', () {
    test('checkbox and step units keep their existing scale', () {
      expect(heatAlpha(0), 0.25);
      expect(heatAlpha(1), closeTo(0.40, 1e-9));
      expect(heatAlpha(3), closeTo(0.70, 1e-9));
      expect(heatAlpha(20), 1.0);
    });

    test('duration points reach full saturation at three points', () {
      expect(heatAlpha(0, isDuration: true), 0.25);
      expect(heatAlpha(1, isDuration: true), closeTo(0.50, 1e-9));
      expect(heatAlpha(2, isDuration: true), closeTo(0.75, 1e-9));
      expect(heatAlpha(3, isDuration: true), 1.0);
      expect(heatAlpha(9, isDuration: true), 1.0);
    });

    test('fractional duration points map smoothly without rounding', () {
      expect(heatAlpha(0.25, isDuration: true), closeTo(0.3125, 1e-9));
      expect(heatAlpha(0.5, isDuration: true), closeTo(0.375, 1e-9));
      expect(heatAlpha(0.75, isDuration: true), closeTo(0.4375, 1e-9));
      expect(heatAlpha(1.5, isDuration: true), closeTo(0.625, 1e-9));
      expect(heatAlpha(2.25, isDuration: true), closeTo(0.8125, 1e-9));
    });
  });
}
