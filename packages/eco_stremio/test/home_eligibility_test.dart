import 'package:aero_core/aero_core.dart';
import 'package:eco_stremio/eco_stremio.dart';
import 'package:test/test.dart';

void main() {
  StremioManifest parse(List<Map<String, Object?>> catalogs) =>
      StremioManifest.fromJson({
        'id': 'org.example.addon',
        'version': '1.0.0',
        'name': 'Example',
        'types': ['movie', 'series'],
        'resources': ['catalog'],
        'catalogs': catalogs,
      });

  group('Catalog extra requirements', () {
    test('a plain catalog is home-eligible', () {
      final c = parse([{'id': 'top', 'type': 'movie', 'name': 'Top'}]).catalogs.single;
      expect(c.requiredExtras, isEmpty);
      expect(c.isHomeEligible, isTrue);
    });

    test('a search-only catalog is NOT home-eligible', () {
      final c = parse([
        {'id': 'search', 'type': 'movie', 'extra': [
          {'name': 'search', 'isRequired': true},
        ]},
      ]).catalogs.single;
      expect(c.searchable, isTrue);
      expect(c.requiredExtras, contains('search'));
      expect(c.isHomeEligible, isFalse);
    });

    test('a catalog requiring a genre is NOT home-eligible', () {
      final c = parse([
        {'id': 'bygenre', 'type': 'movie', 'extra': [
          {'name': 'genre', 'isRequired': true, 'options': ['Action', 'Drama']},
        ]},
      ]).catalogs.single;
      expect(c.genres, ['Action', 'Drama']);
      expect(c.isHomeEligible, isFalse);
    });

    test('optional extras do not disqualify a catalog', () {
      final c = parse([
        {'id': 'top', 'type': 'movie', 'extra': [
          {'name': 'genre', 'isRequired': false, 'options': ['Action']},
          {'name': 'search'},
        ]},
      ]).catalogs.single;
      expect(c.searchable, isTrue);
      expect(c.requiredExtras, isEmpty);
      expect(c.isHomeEligible, isTrue);
    });

    test('skip and limit are pagination, not filters', () {
      final c = parse([
        {'id': 'top', 'type': 'movie', 'extra': [
          {'name': 'skip', 'isRequired': true},
          {'name': 'limit', 'isRequired': true},
        ]},
      ]).catalogs.single;
      expect(c.isHomeEligible, isTrue);
    });

    test('requiredExtras survives a JSON round-trip', () {
      final m = parse([
        {'id': 'search', 'type': 'series', 'extra': [
          {'name': 'search', 'isRequired': true},
        ]},
      ]);
      final back = StremioManifest.fromJson(m.toJson());
      expect(back.catalogs.single.requiredExtras, contains('search'));
      expect(back.catalogs.single.isHomeEligible, isFalse);
    });

    test('CatalogDescriptor and CatalogRow agree', () {
      const d = CatalogDescriptor(
          id: 'search', type: MediaType.movie, requiredExtras: ['search']);
      const r = CatalogRow(
          sourceId: 's', catalogId: 'search', title: 'Search',
          type: MediaType.movie, requiredExtras: ['search']);
      expect(d.isHomeEligible, isFalse);
      expect(r.isHomeEligible, isFalse);
      expect(r.withItems(const []).isHomeEligible, isFalse);
    });

    test('malformed extra entries are ignored, not fatal', () {
      final c = parse([
        {'id': 'top', 'type': 'movie', 'extra': [
          'not-an-object',
          {'isRequired': true},
          {'name': '', 'isRequired': true},
          {'name': 'genre', 'isRequired': true},
        ]},
      ]).catalogs.single;
      expect(c.requiredExtras, ['genre']);
    });
  });
}
