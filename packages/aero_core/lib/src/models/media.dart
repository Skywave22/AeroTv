/// Normalised media types across ecosystems.
enum MediaType {
  movie,
  series,
  channel,
  other;

  String get wire => name;

  static MediaType fromWire(String? raw) => switch (raw?.toLowerCase()) {
        'movie' || 'movies' || 'film' => MediaType.movie,
        'series' || 'tv' || 'show' || 'tvshow' => MediaType.series,
        'channel' || 'live' || 'tvchannel' => MediaType.channel,
        _ => MediaType.other,
      };
}

/// A cross-ecosystem reference to one title.
///
/// [id] is always ecosystem-native. External IDs travel alongside so the
/// MetadataResolver can translate for other ecosystems.
class MediaRef {
  const MediaRef({
    required this.id,
    required this.type,
    this.imdbId,
    this.tmdbId,
    this.title,
    this.year,
  });

  final String id;
  final MediaType type;
  final String? imdbId;
  final String? tmdbId;
  final String? title;
  final int? year;

  bool get hasImdb => (imdbId ?? '').startsWith('tt');

  /// Stable cache key. Prefer IMDb, then TMDB, then the native id.
  String get cacheKey {
    if (hasImdb) return 'imdb:$imdbId';
    if (tmdbId != null && tmdbId!.isNotEmpty) return 'tmdb:$tmdbId';
    return 'raw:$id';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        if (imdbId != null) 'imdbId': imdbId,
        if (tmdbId != null) 'tmdbId': tmdbId,
        if (title != null) 'title': title,
        if (year != null) 'year': year,
      };

  factory MediaRef.fromJson(Map<String, dynamic> j) => MediaRef(
        id: (j['id'] ?? '').toString(),
        type: MediaType.fromWire(j['type'] as String?),
        imdbId: j['imdbId'] as String?,
        tmdbId: j['tmdbId']?.toString(),
        title: j['title'] as String?,
        year: (j['year'] as num?)?.toInt(),
      );

  MediaRef copyWith({String? imdbId, String? tmdbId, String? title, int? year}) =>
      MediaRef(
        id: id,
        type: type,
        imdbId: imdbId ?? this.imdbId,
        tmdbId: tmdbId ?? this.tmdbId,
        title: title ?? this.title,
        year: year ?? this.year,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() => 'MediaRef($id, ${type.wire})';
}

/// A poster/backdrop card in a catalog or search result.
class MediaItem {
  const MediaItem({
    required this.ref,
    required this.title,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.year,
    this.genres = const [],
    this.imdbRating,
    this.runtime,
  });

  final MediaRef ref;
  final String title;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final int? year;
  final List<String> genres;
  final double? imdbRating;
  final String? runtime;

  String get id => ref.id;
  MediaType get type => ref.type;

  Map<String, dynamic> toJson() => {
        'ref': ref.toJson(),
        'title': title,
        if (poster != null) 'poster': poster,
        if (background != null) 'background': background,
        if (logo != null) 'logo': logo,
        if (description != null) 'description': description,
        if (year != null) 'year': year,
        if (genres.isNotEmpty) 'genres': genres,
        if (imdbRating != null) 'imdbRating': imdbRating,
        if (runtime != null) 'runtime': runtime,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        ref: MediaRef.fromJson(Map<String, dynamic>.from(j['ref'] as Map)),
        title: (j['title'] ?? '').toString(),
        poster: j['poster'] as String?,
        background: j['background'] as String?,
        logo: j['logo'] as String?,
        description: j['description'] as String?,
        year: (j['year'] as num?)?.toInt(),
        genres: (j['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        imdbRating: (j['imdbRating'] as num?)?.toDouble(),
        runtime: j['runtime'] as String?,
      );

  @override
  bool operator ==(Object other) => other is MediaItem && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;
}

/// One episode of a series.
class EpisodeRef {
  const EpisodeRef({
    required this.id,
    required this.season,
    required this.episode,
    this.title,
    this.overview,
    this.thumbnail,
    this.released,
  });

  final String id;
  final int season;
  final int episode;
  final String? title;
  final String? overview;
  final String? thumbnail;
  final DateTime? released;

  String get label =>
      'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'season': season,
        'episode': episode,
        if (title != null) 'title': title,
        if (overview != null) 'overview': overview,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (released != null) 'released': released!.toIso8601String(),
      };

  factory EpisodeRef.fromJson(Map<String, dynamic> j) => EpisodeRef(
        id: (j['id'] ?? '').toString(),
        season: (j['season'] as num?)?.toInt() ?? 0,
        episode: (j['episode'] as num?)?.toInt() ?? 0,
        title: j['title'] as String?,
        overview: j['overview'] as String?,
        thumbnail: j['thumbnail'] as String?,
        released: DateTime.tryParse(j['released']?.toString() ?? ''),
      );
}

/// Full details for the hero/details screen.
class MediaDetails {
  const MediaDetails({
    required this.item,
    this.cast = const [],
    this.directors = const [],
    this.seasons = const [],
    this.episodes = const [],
    this.trailers = const [],
    this.countries = const [],
    this.language,
    this.certification,
  });

  final MediaItem item;
  final List<String> cast;
  final List<String> directors;
  final List<int> seasons;
  final List<EpisodeRef> episodes;
  final List<String> trailers;
  final List<String> countries;
  final String? language;
  final String? certification;

  bool get isSeries => item.type == MediaType.series;

  List<EpisodeRef> episodesOfSeason(int season) =>
      episodes.where((e) => e.season == season).toList()
        ..sort((a, b) => a.episode.compareTo(b.episode));

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'cast': cast,
        'directors': directors,
        'seasons': seasons,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'trailers': trailers,
        'countries': countries,
        if (language != null) 'language': language,
        if (certification != null) 'certification': certification,
      };

  factory MediaDetails.fromJson(Map<String, dynamic> j) => MediaDetails(
        item: MediaItem.fromJson(Map<String, dynamic>.from(j['item'] as Map)),
        cast: (j['cast'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        directors:
            (j['directors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        seasons:
            (j['seasons'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
        episodes: (j['episodes'] as List?)
                ?.map((e) => EpisodeRef.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        trailers: (j['trailers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        countries:
            (j['countries'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        language: j['language'] as String?,
        certification: j['certification'] as String?,
      );
}
