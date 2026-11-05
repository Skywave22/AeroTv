import 'dart:convert';

import 'package:aero_core/aero_core.dart';

import '../db/database.dart';

/// Player-side preferences.
class PlayerSettings {
  const PlayerSettings({
    this.resumePlayback = true,
    this.defaultSubtitleLang = 'en',
    this.subtitlesEnabledByDefault = true,
    this.subtitleSize = 1.0,
    this.preferredAudioLang = 'en',
    this.hardwareDecoding = true,
    this.defaultSpeed = 1.0,
    this.fitMode = 'contain',
    this.skipIntroSeconds = 0,
    this.autoPlayNextEpisode = false,
    this.seekStepSeconds = 10,
  });

  final bool resumePlayback;
  final String defaultSubtitleLang;
  final bool subtitlesEnabledByDefault;
  final double subtitleSize;
  final String preferredAudioLang;
  final bool hardwareDecoding;
  final double defaultSpeed;
  final String fitMode;
  final int skipIntroSeconds;
  final bool autoPlayNextEpisode;
  final int seekStepSeconds;

  PlayerSettings copyWith({
    bool? resumePlayback,
    String? defaultSubtitleLang,
    bool? subtitlesEnabledByDefault,
    double? subtitleSize,
    String? preferredAudioLang,
    bool? hardwareDecoding,
    double? defaultSpeed,
    String? fitMode,
    int? seekStepSeconds,
    bool? autoPlayNextEpisode,
  }) =>
      PlayerSettings(
        resumePlayback: resumePlayback ?? this.resumePlayback,
        defaultSubtitleLang: defaultSubtitleLang ?? this.defaultSubtitleLang,
        subtitlesEnabledByDefault:
            subtitlesEnabledByDefault ?? this.subtitlesEnabledByDefault,
        subtitleSize: subtitleSize ?? this.subtitleSize,
        preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
        hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
        defaultSpeed: defaultSpeed ?? this.defaultSpeed,
        fitMode: fitMode ?? this.fitMode,
        skipIntroSeconds: skipIntroSeconds,
        autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
        seekStepSeconds: seekStepSeconds ?? this.seekStepSeconds,
      );

  Map<String, dynamic> toJson() => {
        'resumePlayback': resumePlayback,
        'defaultSubtitleLang': defaultSubtitleLang,
        'subtitlesEnabledByDefault': subtitlesEnabledByDefault,
        'subtitleSize': subtitleSize,
        'preferredAudioLang': preferredAudioLang,
        'hardwareDecoding': hardwareDecoding,
        'defaultSpeed': defaultSpeed,
        'fitMode': fitMode,
        'skipIntroSeconds': skipIntroSeconds,
        'autoPlayNextEpisode': autoPlayNextEpisode,
        'seekStepSeconds': seekStepSeconds,
      };

  factory PlayerSettings.fromJson(Map<String, dynamic> j) => PlayerSettings(
        resumePlayback: j['resumePlayback'] as bool? ?? true,
        defaultSubtitleLang: j['defaultSubtitleLang'] as String? ?? 'en',
        subtitlesEnabledByDefault: j['subtitlesEnabledByDefault'] as bool? ?? true,
        subtitleSize: (j['subtitleSize'] as num?)?.toDouble() ?? 1.0,
        preferredAudioLang: j['preferredAudioLang'] as String? ?? 'en',
        hardwareDecoding: j['hardwareDecoding'] as bool? ?? true,
        defaultSpeed: (j['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
        fitMode: j['fitMode'] as String? ?? 'contain',
        skipIntroSeconds: (j['skipIntroSeconds'] as num?)?.toInt() ?? 0,
        autoPlayNextEpisode: j['autoPlayNextEpisode'] as bool? ?? false,
        seekStepSeconds: (j['seekStepSeconds'] as num?)?.toInt() ?? 10,
      );
}

/// UI preferences, including the TV focus/overscan behaviour.
class UiSettings {
  const UiSettings({
    this.accentSeed = 0xFF7B5CFF,
    this.dynamicColorFromArtwork = true,
    this.reduceMotion = false,
    this.tvOverscanPercent = 3.0,
    this.showEcosystemBadges = true,
    this.heroRotationSeconds = 8,
    this.enableBlur = true,
  });

  final int accentSeed;
  final bool dynamicColorFromArtwork;
  final bool reduceMotion;

  /// Safe-area inset for TVs that crop the edges.
  final double tvOverscanPercent;
  final bool showEcosystemBadges;
  final int heroRotationSeconds;

  /// Blur is expensive on low-end TV boxes; users can disable it.
  final bool enableBlur;

  UiSettings copyWith({
    int? accentSeed,
    bool? dynamicColorFromArtwork,
    bool? reduceMotion,
    double? tvOverscanPercent,
    bool? showEcosystemBadges,
    bool? enableBlur,
    int? heroRotationSeconds,
  }) =>
      UiSettings(
        accentSeed: accentSeed ?? this.accentSeed,
        dynamicColorFromArtwork:
            dynamicColorFromArtwork ?? this.dynamicColorFromArtwork,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        tvOverscanPercent: tvOverscanPercent ?? this.tvOverscanPercent,
        showEcosystemBadges: showEcosystemBadges ?? this.showEcosystemBadges,
        enableBlur: enableBlur ?? this.enableBlur,
        heroRotationSeconds: heroRotationSeconds ?? this.heroRotationSeconds,
      );

  Map<String, dynamic> toJson() => {
        'accentSeed': accentSeed,
        'dynamicColorFromArtwork': dynamicColorFromArtwork,
        'reduceMotion': reduceMotion,
        'tvOverscanPercent': tvOverscanPercent,
        'showEcosystemBadges': showEcosystemBadges,
        'enableBlur': enableBlur,
        'heroRotationSeconds': heroRotationSeconds,
      };

  factory UiSettings.fromJson(Map<String, dynamic> j) => UiSettings(
        accentSeed: (j['accentSeed'] as num?)?.toInt() ?? 0xFF7B5CFF,
        dynamicColorFromArtwork: j['dynamicColorFromArtwork'] as bool? ?? true,
        reduceMotion: j['reduceMotion'] as bool? ?? false,
        tvOverscanPercent: (j['tvOverscanPercent'] as num?)?.toDouble() ?? 3.0,
        showEcosystemBadges: j['showEcosystemBadges'] as bool? ?? true,
        enableBlur: j['enableBlur'] as bool? ?? true,
        heroRotationSeconds: (j['heroRotationSeconds'] as num?)?.toInt() ?? 8,
      );
}

/// Typed key/value settings on top of the Drift `AppSettings` table, with an
/// in-memory cache so widgets can read synchronously after bootstrap.
class SettingsRepository {
  SettingsRepository(this.db);

  final AeroDatabase db;
  final Map<String, Map<String, dynamic>> _cache = {};

  static const _kPlayer = 'player';
  static const _kUi = 'ui';
  static const _kRanking = 'ranking';
  static const _kTmdbKey = 'tmdbApiKey';
  static const _kOnboarded = 'onboarded';
  static const _kTelemetry = 'telemetryOptIn';

  Future<void> load() async {
    final rows = await db.select(db.appSettings).get();
    _cache.clear();
    for (final r in rows) {
      try {
        _cache[r.key] = Map<String, dynamic>.from(jsonDecode(r.valueJson) as Map);
      } catch (_) {
        // Ignore a corrupt row rather than failing startup.
      }
    }
  }

  Future<void> _write(String key, Map<String, dynamic> value) async {
    _cache[key] = value;
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, valueJson: jsonEncode(value)),
        );
  }

  PlayerSettings get player =>
      PlayerSettings.fromJson(_cache[_kPlayer] ?? const {});
  Future<void> setPlayer(PlayerSettings s) => _write(_kPlayer, s.toJson());

  UiSettings get ui => UiSettings.fromJson(_cache[_kUi] ?? const {});
  Future<void> setUi(UiSettings s) => _write(_kUi, s.toJson());

  RankingRules get ranking => RankingRules.fromJson(_cache[_kRanking] ?? const {});
  Future<void> setRanking(RankingRules r) => _write(_kRanking, r.toJson());

  String get tmdbApiKey => (_cache[_kTmdbKey]?['v'] ?? '') as String;
  Future<void> setTmdbApiKey(String key) => _write(_kTmdbKey, {'v': key});

  bool get hasOnboarded => (_cache[_kOnboarded]?['v'] ?? false) as bool;
  Future<void> setOnboarded() => _write(_kOnboarded, {'v': true});

  /// Crash reporting is strictly opt-in.
  bool get telemetryOptIn => (_cache[_kTelemetry]?['v'] ?? false) as bool;
  Future<void> setTelemetryOptIn(bool v) => _write(_kTelemetry, {'v': v});

  /// Raw export for backup.
  Map<String, Map<String, dynamic>> exportAll() => Map.of(_cache);

  Future<void> importAll(Map<String, dynamic> raw) async {
    for (final e in raw.entries) {
      if (e.value is Map) {
        await _write(e.key, Map<String, dynamic>.from(e.value as Map));
      }
    }
  }
}
