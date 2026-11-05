import 'media.dart';

/// One home-screen row contributed by a source ("Trending", "Popular", ...).
class CatalogRow {
  const CatalogRow({
    required this.sourceId,
    required this.catalogId,
    required this.title,
    required this.type,
    this.items = const [],
    this.hasMore = false,
    this.genres = const [],
    this.searchable = false,
  });

  final String sourceId;
  final String catalogId;
  final String title;
  final MediaType type;
  final List<MediaItem> items;
  final bool hasMore;
  final List<String> genres;

  /// True when the add-on declares a `search` extra for this catalog.
  final bool searchable;

  CatalogRow withItems(List<MediaItem> newItems, {bool? hasMore}) => CatalogRow(
        sourceId: sourceId,
        catalogId: catalogId,
        title: title,
        type: type,
        items: newItems,
        hasMore: hasMore ?? this.hasMore,
        genres: genres,
        searchable: searchable,
      );
}

/// A paging + filtering request for a catalog.
class CatalogQuery {
  const CatalogQuery({this.skip = 0, this.genre, this.search, this.extra = const {}});

  final int skip;
  final String? genre;
  final String? search;
  final Map<String, String> extra;

  /// Stremio packs extras into the path: `/catalog/movie/top/genre=Action.json`.
  Map<String, String> toExtraMap() => {
        if (genre != null && genre!.isNotEmpty) 'genre': genre!,
        if (search != null && search!.isNotEmpty) 'search': search!,
        if (skip > 0) 'skip': '$skip',
        ...extra,
      };

  CatalogQuery nextPage(int pageSize) =>
      CatalogQuery(skip: skip + pageSize, genre: genre, search: search, extra: extra);
}

/// A page of results plus a cursor hint.
class Page<T> {
  const Page({required this.items, this.hasMore = false, this.nextSkip});

  final List<T> items;
  final bool hasMore;
  final int? nextSkip;

  static Page<T> empty<T>() => Page<T>(items: const []);
}
