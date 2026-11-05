import '../models/ecosystem.dart';
import '../models/stream_link.dart';

/// User-configurable auto-play rules. Defaults are deliberately conservative:
/// 1080p, no 4K on metered/low-end devices, size-capped.
class RankingRules {
  const RankingRules({
    this.preferredQuality = Quality.fullHd,
    this.allowHigherThanPreferred = true,
    this.maxSizeBytes,
    this.preferredLanguages = const ['en'],
    this.ecosystemOrder = const [
      Ecosystem.stremio,
      Ecosystem.vega,
      Ecosystem.nuvio,
      Ecosystem.skystream,
      Ecosystem.cloudstream,
    ],
    this.providerOrder = const [],
    this.blockedProviders = const [],
    this.preferHdr = false,
    this.preferredCodecs = const ['h264', 'x264', 'avc'],
    this.penaliseUnknownQuality = true,
    this.autoPlayEnabled = false,
    this.minScoreForAutoPlay = 40,
  });

  final Quality preferredQuality;

  /// When false, anything above [preferredQuality] is filtered out entirely.
  final bool allowHigherThanPreferred;
  final int? maxSizeBytes;
  final List<String> preferredLanguages;
  final List<Ecosystem> ecosystemOrder;

  /// Source keys (`ecosystem:sourceId`) in user preference order.
  final List<String> providerOrder;
  final List<String> blockedProviders;
  final bool preferHdr;
  final List<String> preferredCodecs;
  final bool penaliseUnknownQuality;
  final bool autoPlayEnabled;

  /// Guard rail so auto-play never picks a terrible link.
  final int minScoreForAutoPlay;

  RankingRules copyWith({
    Quality? preferredQuality,
    bool? allowHigherThanPreferred,
    int? maxSizeBytes,
    bool clearMaxSize = false,
    List<String>? preferredLanguages,
    List<Ecosystem>? ecosystemOrder,
    List<String>? providerOrder,
    List<String>? blockedProviders,
    bool? preferHdr,
    List<String>? preferredCodecs,
    bool? autoPlayEnabled,
    int? minScoreForAutoPlay,
  }) =>
      RankingRules(
        preferredQuality: preferredQuality ?? this.preferredQuality,
        allowHigherThanPreferred:
            allowHigherThanPreferred ?? this.allowHigherThanPreferred,
        maxSizeBytes: clearMaxSize ? null : (maxSizeBytes ?? this.maxSizeBytes),
        preferredLanguages: preferredLanguages ?? this.preferredLanguages,
        ecosystemOrder: ecosystemOrder ?? this.ecosystemOrder,
        providerOrder: providerOrder ?? this.providerOrder,
        blockedProviders: blockedProviders ?? this.blockedProviders,
        preferHdr: preferHdr ?? this.preferHdr,
        preferredCodecs: preferredCodecs ?? this.preferredCodecs,
        penaliseUnknownQuality: penaliseUnknownQuality,
        autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
        minScoreForAutoPlay: minScoreForAutoPlay ?? this.minScoreForAutoPlay,
      );

  Map<String, dynamic> toJson() => {
        'preferredQuality': preferredQuality.name,
        'allowHigherThanPreferred': allowHigherThanPreferred,
        if (maxSizeBytes != null) 'maxSizeBytes': maxSizeBytes,
        'preferredLanguages': preferredLanguages,
        'ecosystemOrder': ecosystemOrder.map((e) => e.id).toList(),
        'providerOrder': providerOrder,
        'blockedProviders': blockedProviders,
        'preferHdr': preferHdr,
        'preferredCodecs': preferredCodecs,
        'penaliseUnknownQuality': penaliseUnknownQuality,
        'autoPlayEnabled': autoPlayEnabled,
        'minScoreForAutoPlay': minScoreForAutoPlay,
      };

  factory RankingRules.fromJson(Map<String, dynamic> j) => RankingRules(
        preferredQuality: Quality.values.firstWhere(
          (q) => q.name == j['preferredQuality'],
          orElse: () => Quality.fullHd,
        ),
        allowHigherThanPreferred: j['allowHigherThanPreferred'] as bool? ?? true,
        maxSizeBytes: (j['maxSizeBytes'] as num?)?.toInt(),
        preferredLanguages: (j['preferredLanguages'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['en'],
        ecosystemOrder: (j['ecosystemOrder'] as List?)
                ?.map((e) => Ecosystem.tryFromId(e as String?))
                .whereType<Ecosystem>()
                .toList() ??
            Ecosystem.values,
        providerOrder:
            (j['providerOrder'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        blockedProviders:
            (j['blockedProviders'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        preferHdr: j['preferHdr'] as bool? ?? false,
        preferredCodecs: (j['preferredCodecs'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['h264', 'x264', 'avc'],
        penaliseUnknownQuality: j['penaliseUnknownQuality'] as bool? ?? true,
        autoPlayEnabled: j['autoPlayEnabled'] as bool? ?? false,
        minScoreForAutoPlay: (j['minScoreForAutoPlay'] as num?)?.toInt() ?? 40,
      );
}
