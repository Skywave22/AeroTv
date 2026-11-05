import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app.dart';
import 'src/services/device_service.dart';
import 'src/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv must be initialised before any Player is constructed.
  MediaKit.ensureInitialized();

  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  AeroLog.instance.i('app', 'Aero TV starting');

  final overrides = <Override>[];
  Object? bootError;

  try {
    final db = await AeroDatabase.open();
    final settings = SettingsRepository(db);
    await settings.load();
    // Opportunistic cache cleanup; never block startup on it.
    unawaited(db.pruneCache());

    final isTv = await DeviceService.isAndroidTv();
    if (isTv) {
      // TVs are landscape and D-pad driven; lock orientation.
      unawaited(SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
    }

    overrides.addAll([
      databaseProvider.overrideWithValue(db),
      settingsRepoProvider.overrideWithValue(settings),
      isTvProvider.overrideWith((ref) => isTv),
    ]);

    AeroLog.instance.i('app', 'Bootstrap complete (TV mode: $isTv)');
  } catch (e, st) {
    bootError = e;
    AeroLog.instance.e('app', 'Bootstrap failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      child: AeroApp(bootError: bootError),
    ),
  );
}
