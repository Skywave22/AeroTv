import 'media.dart';

/// Everything an adapter needs to find streams for one playback.
class PlayRequest {
  const PlayRequest({
    required this.ref,
    this.season,
    this.episode,
    this.episodeId,
    this.bingeGroup,
  });

  final MediaRef ref;
  final int? season;
  final int? episode;

  /// Some ecosystems key episodes by their own id rather than S/E numbers.
  final String? episodeId;
  final String? bingeGroup;

  bool get isEpisode => season != null && episode != null;

  /// Stremio video id for an episode: `tt0944947:1:2`.
  /// For movies it is just the IMDb id.
  String get stremioVideoId {
    final base = ref.imdbId ?? ref.id;
    if (isEpisode) return '$base:$season:$episode';
    return base;
  }

  /// Cache key for resolved streams.
  String get cacheKey => '${ref.cacheKey}|${season ?? '-'}|${episode ?? '-'}';

  Map<String, dynamic> toJson() => {
        'ref': ref.toJson(),
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (episodeId != null) 'episodeId': episodeId,
        if (bingeGroup != null) 'bingeGroup': bingeGroup,
      };

  factory PlayRequest.fromJson(Map<String, dynamic> j) => PlayRequest(
        ref: MediaRef.fromJson(Map<String, dynamic>.from(j['ref'] as Map)),
        season: (j['season'] as num?)?.toInt(),
        episode: (j['episode'] as num?)?.toInt(),
        episodeId: j['episodeId'] as String?,
        bingeGroup: j['bingeGroup'] as String?,
      );

  @override
  String toString() => 'PlayRequest(${ref.id}, s$season e$episode)';
}
