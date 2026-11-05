import 'dart:io' show Platform;

import 'package:aero_core/aero_core.dart';
import 'package:flutter/foundation.dart';

import 'cloudstream_channel.dart';

/// CloudStream adapter.
///
/// Guarded by three independent gates, all of which must pass:
/// 1. platform is Android,
/// 2. the build was compiled with `AERO_ENABLE_CLOUDSTREAM=true`,
/// 3. a native host is actually present at runtime.
///
/// Until then the Extensions Manager shows the section greyed out with a
/// clear explanation, which is the correct Phase-1 behaviour.
class CloudStreamAdapter implements EcosystemAdapter {
  CloudStreamAdapter({
    CloudStreamChannel? channel,
    this.buildFlagEnabled = const bool.fromEnvironment(
      'AERO_ENABLE_CLOUDSTREAM',
      defaultValue: false,
    ),
  }) : _channel = channel ?? CloudStreamChannel();

  final CloudStreamChannel _channel;

  /// Compile-time gate: `--dart-define=AERO_ENABLE_CLOUDSTREAM=true`.
  final bool buildFlagEnabled;

  bool? _hostPresent;
  final List<InstalledSource> _installed = [];

  static const String _licenseNote =
      'CloudStream plugins are compiled Kotlin/DEX and run with full app '
      'privileges. CloudStream is GPL-3.0, so this bridge is disabled by '
      'default pending a licensing review.';

  bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Ecosystem get ecosystem => Ecosystem.cloudstream;

  @override
  bool get isAvailable =>
      _isAndroid && buildFlagEnabled && (_hostPresent ?? false);

  @override
  String? get unavailableReason {
    if (!_isAndroid) {
      return 'Android and Android TV only. CloudStream plugins are compiled '
          'Kotlin/DEX and cannot run on iOS, desktop or web.';
    }
    if (!buildFlagEnabled) return _licenseNote;
    if (!(_hostPresent ?? false)) {
      return 'The native CloudStream host is not included in this build.';
    }
    return null;
  }

  /// Probes for the native host. Called once during app bootstrap.
  Future<void> probe() async {
    if (!_isAndroid || !buildFlagEnabled) {
      _hostPresent = false;
      return;
    }
    _hostPresent = await _channel.isHostPresent();
    AeroLog.instance.i('cloudstream', 'Native host present: $_hostPresent');
  }

  @override
  Set<Capability> get capabilities => isAvailable
      ? {Capability.search, Capability.meta, Capability.streams}
      : const {};

  @override
  Future<List<InstalledSource>> installedSources() async =>
      isAvailable ? List.of(_installed) : const [];

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async =>
      Err(unavailableReason ?? 'CloudStream is not enabled in this build.');

  @override
  Future<void> uninstall(String sourceId) async {
    _installed.removeWhere((s) => s.id == sourceId);
    if (isAvailable) {
      try {
        await _channel.unload(sourceId);
      } catch (e) {
        AeroLog.instance.w('cloudstream', 'unload failed: $e');
      }
    }
  }

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async =>
      const Err('Not available in this build.');

  @override
  Future<Result<Duration>> healthCheck(String sourceId) async =>
      Err(unavailableReason ?? 'Unavailable');

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async => const [];

  @override
  Future<Page<MediaItem>> browse(
          String sourceId, String catalogId, CatalogQuery q) async =>
      Page.empty();

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async =>
      Page.empty();

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async =>
      Err(unavailableReason ?? 'Unavailable');

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) =>
      const Stream<StreamLink>.empty();

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async =>
      const [];

  @override
  Future<void> dispose() async {
    _installed.clear();
  }
}
