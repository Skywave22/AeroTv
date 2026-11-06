import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_app/src/screens/browse_screen.dart';
import 'package:aero_app/src/screens/home_screen.dart';
import 'package:aero_app/src/state/providers.dart';

/// Pumps a screen with **static** provider values.
///
/// Widget tests deliberately avoid live Drift streams: those keep internal
/// timers alive and would fail the framework's "no pending timers" invariant.
/// Database behaviour is covered by `aero_data`'s own tests instead.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required AeroDatabase db,
  bool isTv = false,
  List<InstalledSource> sources = const [],
}) async {
  final settings = SettingsRepository(db);
  await settings.load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(settings),
        isTvProvider.overrideWith((ref) => isTv),
        installedSourcesProvider.overrideWith((ref) async => sources),
        continueWatchingProvider.overrideWith((ref) => Stream.value(const [])),
        homeRowsProvider.overrideWith((ref) async => const []),
        browsableSourcesProvider.overrideWith((ref) async => sources),
        nonBrowsableSourcesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AeroTheme.dark(tvMode: isTv),
        // Deterministic: no shimmer tickers, no hero rotation.
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: inner!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late AeroDatabase db;

  setUp(() => db = AeroDatabase.memory());
  tearDown(() async => db.close());

  testWidgets('Home states the neutral, zero-content posture', (tester) async {
    await pumpScreen(tester, const HomeScreen(), db: db);

    expect(find.text('Welcome to Aero TV'), findsOneWidget);
    expect(find.text('Add an add-on'), findsOneWidget);
    expect(
      find.textContaining('ships with no content and no sources'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home renders on a 1080p TV without overflow', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, const HomeScreen(), db: db, isTv: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome to Aero TV'), findsOneWidget);
  });

  testWidgets('Home renders on a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, const HomeScreen(), db: db);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Browse lists an ecosystem section even with nothing installed',
      (tester) async {
    await pumpScreen(tester, const BrowseScreen(), db: db);

    // Sections are discoverable before anything is installed.
    expect(find.text('SkyStream'), findsOneWidget);
    expect(find.text('Vega'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Browse marks CloudStream as beta rather than hiding it',
      (tester) async {
    await pumpScreen(tester, const BrowseScreen(), db: db);

    expect(find.text('CloudStream'), findsOneWidget);
    expect(find.text('Beta soon'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Browse lists a provider under its own ecosystem', (tester) async {
    final source = InstalledSource(
      id: 'p1',
      ecosystem: Ecosystem.skystream,
      name: 'My Plugin',
      url: 'https://example.com/plugin.js',
      version: '1',
    );
    await pumpScreen(
      tester,
      const BrowseScreen(),
      db: db,
      sources: [source],
    );

    // The tile names the provider inside its ecosystem's section.
    expect(find.text('My Plugin'), findsWidgets);
    expect(find.text('SkyStream'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Theme', () {
    test('dark theme uses the brand accent and near-black background', () {
      final theme = AeroTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, BrandConfig.standard.accent);
      expect(theme.scaffoldBackgroundColor, AeroColors.background);
    });

    test('TV typography is larger than phone typography', () {
      final phone = AeroTheme.dark();
      final tv = AeroTheme.dark(tvMode: true);
      expect(
        tv.textTheme.bodyLarge!.fontSize!,
        greaterThan(phone.textTheme.bodyLarge!.fontSize!),
      );
    });
  });
}
