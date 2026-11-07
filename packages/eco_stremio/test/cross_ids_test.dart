import 'package:eco_stremio/eco_stremio.dart';
import 'package:test/test.dart';

/// A title opened from an add-on catalogue has to reach Nuvio scrapers, which
/// are TMDB-keyed. That only works if the cross-ecosystem id survives parsing.
void main() {
  group('cross-ecosystem ids', () {
    test('reads tmdb_id from behaviorHints (the spec location)', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt0133093',
        'type': 'movie',
        'name': 'The Matrix',
        'behaviorHints': {'tmdb_id': '603'},
      })!;
      expect(item.ref.imdbId, 'tt0133093');
      expect(item.ref.tmdbId, '603');
    });

    test('falls back to a top-level tmdb_id for older add-ons', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt0133093',
        'type': 'movie',
        'name': 'The Matrix',
        'tmdb_id': '603',
      })!;
      expect(item.ref.tmdbId, '603');
    });

    test('behaviorHints wins over a stale top-level value', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt1',
        'type': 'movie',
        'name': 'X',
        'tmdb_id': '111',
        'behaviorHints': {'tmdb_id': '222'},
      })!;
      expect(item.ref.tmdbId, '222');
    });

    test('no ids anywhere leaves tmdbId null rather than "null"', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt1',
        'type': 'movie',
        'name': 'X',
      })!;
      expect(item.ref.tmdbId, isNull);
    });

    test('numeric ids are stringified, not dropped', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt1',
        'type': 'movie',
        'name': 'X',
        'behaviorHints': {'tmdb_id': 603},
      })!;
      expect(item.ref.tmdbId, '603');
    });
  });
}
