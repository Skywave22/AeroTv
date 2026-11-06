import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Remote-only interaction tests: the automated half of Phase 1 exit
/// criterion 2 ("browse and play with only a remote").
void main() {
  Future<void> pumpTv(WidgetTester tester, Widget child) async {
    // MediaQuery alone does not resize the render surface; set the real view
    // so a TV-width row does not overflow the default 800x600.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080), disableAnimations: true),
        child: Scaffold(body: child),
      ),
    ));
    await tester.pump();
  }

  group('TvFocus activation via remote keys', () {
    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      testWidgets('${key.debugName} activates the focused item', (tester) async {
        var selected = 0;
        await pumpTv(tester, TvFocus(
          autofocus: true,
          onSelect: () => selected++,
          child: const SizedBox(width: 200, height: 300),
        ));
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(selected, 1, reason: '${key.debugName} must activate');
      });
    }

    testWidgets('a disabled item ignores Select', (tester) async {
      var selected = 0;
      await pumpTv(tester, TvFocus(
        autofocus: true, enabled: false, onSelect: () => selected++,
        child: const SizedBox(width: 200, height: 300),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(selected, 0);
    });

    testWidgets('reports focus changes', (tester) async {
      final changes = <bool>[];
      await pumpTv(tester, TvFocus(
        autofocus: true, onFocusChange: changes.add,
        child: const SizedBox(width: 200, height: 300),
      ));
      expect(changes, contains(true));
    });
  });

  group('D-pad traversal', () {
    testWidgets('Right advances, Left goes back', (tester) async {
      final nodes = List.generate(3, (_) => FocusNode());
      addTearDown(() { for (final n in nodes) { n.dispose(); } });
      await pumpTv(tester, FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(children: [
          for (var i = 0; i < 3; i++)
            FocusTraversalOrder(
              order: NumericFocusOrder(i.toDouble()),
              child: TvFocus(
                focusNode: nodes[i], autofocus: i == 0,
                child: const SizedBox(width: 200, height: 300),
              ),
            ),
        ]),
      ));
      expect(nodes[0].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(nodes[1].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(nodes[2].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(nodes[1].hasFocus, isTrue);
    });

    testWidgets('Right at the last item does not wrap to the first', (tester) async {
      final nodes = List.generate(2, (_) => FocusNode());
      addTearDown(() { for (final n in nodes) { n.dispose(); } });
      await pumpTv(tester, FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(children: [
          for (var i = 0; i < 2; i++)
            FocusTraversalOrder(
              order: NumericFocusOrder(i.toDouble()),
              child: TvFocus(
                focusNode: nodes[i], autofocus: i == 1,
                child: const SizedBox(width: 200, height: 300),
              ),
            ),
        ]),
      ));
      expect(nodes[1].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(nodes[0].hasFocus, isFalse);
    });

    testWidgets('Down moves to the next row', (tester) async {
      final top = FocusNode();
      final bottom = FocusNode();
      addTearDown(() { top.dispose(); bottom.dispose(); });
      await pumpTv(tester, Column(children: [
        TvFocus(focusNode: top, autofocus: true, child: const SizedBox(width: 200, height: 300)),
        TvFocus(focusNode: bottom, child: const SizedBox(width: 200, height: 300)),
      ]));
      expect(top.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(bottom.hasFocus, isTrue);
    });
  });

  group('RowFocusMemory', () {
    test('defaults to the first cell of an unseen row', () {
      final m = RowFocusMemory();
      addTearDown(m.clear);
      expect(m.indexFor('row'), 0);
    });

    test('remembers a per-row index independently', () {
      final m = RowFocusMemory();
      addTearDown(m.clear);
      m.remember('a', 3);
      m.remember('b', 7);
      expect(m.indexFor('a'), 3);
      expect(m.indexFor('b'), 7);
    });

    test('returns a stable node per cell', () {
      final m = RowFocusMemory();
      addTearDown(m.clear);
      final n1 = m.nodeFor('a', 2);
      expect(identical(n1, m.nodeFor('a', 2)), isTrue);
      expect(identical(n1, m.nodeFor('a', 3)), isFalse);
      expect(identical(n1, m.nodeFor('b', 2)), isFalse);
    });

    testWidgets('focusRow restores the remembered cell', (tester) async {
      final m = RowFocusMemory();
      addTearDown(m.clear);
      final nodes = [for (var i = 0; i < 4; i++) m.nodeFor('row', i)];
      await pumpTv(tester, Row(children: [
        for (var i = 0; i < 4; i++)
          TvFocus(focusNode: nodes[i], child: const SizedBox(width: 200, height: 300)),
      ]));
      m.remember('row', 2);
      m.focusRow('row', maxIndex: 3);
      await tester.pumpAndSettle();
      expect(nodes[2].hasFocus, isTrue);
    });

    testWidgets('focusRow clamps an index that no longer exists', (tester) async {
      final m = RowFocusMemory();
      addTearDown(m.clear);
      final nodes = [for (var i = 0; i < 2; i++) m.nodeFor('row', i)];
      await pumpTv(tester, Row(children: [
        for (var i = 0; i < 2; i++)
          TvFocus(focusNode: nodes[i], child: const SizedBox(width: 200, height: 300)),
      ]));
      m.remember('row', 9);
      m.focusRow('row', maxIndex: 1);
      await tester.pumpAndSettle();
      expect(nodes[1].hasFocus, isTrue);
    });
  });
}
