import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Adaptive layout', () {
    test('side rail everywhere except phone', () {
      expect(Adaptive.usesSideRail(FormFactor.phone), isFalse);
      expect(Adaptive.usesSideRail(FormFactor.tablet), isTrue);
      expect(Adaptive.usesSideRail(FormFactor.desktop), isTrue);
      expect(Adaptive.usesSideRail(FormFactor.tv), isTrue);
    });

    test('TV posters are the largest', () {
      final tv = Adaptive.posterWidth(FormFactor.tv);
      expect(tv, greaterThan(Adaptive.posterWidth(FormFactor.desktop)));
      expect(tv, greaterThan(Adaptive.posterWidth(FormFactor.phone)));
    });

    test('grid columns stay within sane bounds', () {
      expect(Adaptive.gridColumns(FormFactor.phone, 360), greaterThanOrEqualTo(2));
      expect(Adaptive.gridColumns(FormFactor.tv, 3840), lessThanOrEqualTo(8));
      expect(Adaptive.gridColumns(FormFactor.phone, 100), 2);
    });
  });

  group('RowFocusMemory', () {
    test('remembers the last focused column per row', () {
      final memory = RowFocusMemory();
      expect(memory.indexFor('trending'), 0);
      memory.remember('trending', 4);
      memory.remember('popular', 2);
      expect(memory.indexFor('trending'), 4);
      expect(memory.indexFor('popular'), 2);
      memory.clear();
      expect(memory.indexFor('trending'), 0);
    });

    test('creates stable nodes per cell', () {
      final memory = RowFocusMemory();
      final a = memory.nodeFor('row', 0);
      final b = memory.nodeFor('row', 0);
      final c = memory.nodeFor('row', 1);
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
      memory.clear();
    });
  });

  group('Duration formatting', () {
    test('drops the hour when zero', () {
      expect(formatDuration(const Duration(minutes: 12, seconds: 34)), '12:34');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 23, seconds: 45)),
        '1:23:45',
      );
      expect(formatDuration(Duration.zero), '00:00');
    });
  });

  group('Quality ordering used by the picker', () {
    test('4K sorts above 1080p', () {
      final list = [Quality.hd, Quality.uhd, Quality.fullHd]..sort();
      expect(list.last, Quality.uhd);
    });
  });
}
