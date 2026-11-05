import 'package:aero_core/aero_core.dart';
import 'package:eco_vega/eco_vega.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vega module layout', () {
    test('required and optional files match upstream ExtensionManager', () {
      expect(kVegaRequiredModules, ['posts', 'meta', 'stream', 'catalog']);
      expect(kVegaOptionalModules, ['episodes', 'settings']);
    });

    test('default folder is dist/<value>', () {
      expect(vegaProviderFilesUrl('https://src.example', 'myprov', null),
          'https://src.example/dist/myprov');
    });

    test('explicit path overrides the default folder', () {
      expect(vegaProviderFilesUrl('https://src.example/', 'myprov', 'custom/folder'),
          'https://src.example/custom/folder');
    });

    test('traversal and absolute paths are rejected', () {
      expect(isSafeVegaPath('../../etc'), isFalse);
      expect(isSafeVegaPath('a/../../b'), isFalse);
      expect(isSafeVegaPath('/absolute'), isFalse);
      expect(isSafeVegaPath('https://evil.example'), isFalse);
      expect(isSafeVegaPath(r'a\b'), isFalse);
      expect(isSafeVegaPath('dist/prov'), isTrue);
      expect(isSafeVegaPath(''), isTrue);
      // A rejected path must not produce a URL at all.
      expect(vegaProviderFilesUrl('https://src', 'p', '../evil'), isNull);
    });
  });

  group('Vega ES module handling', () {
    test('strips export keywords but keeps the declarations', () {
      const src = '''
import axios from 'axios';
export async function GetHomePosts({filter, page}) { return []; }
export const catalog = [{title:'Trending', filter:'trending'}];
export { GetHomePosts };
''';
      final out = JsVegaProvider.stripEsExports(src);
      expect(out, isNot(contains('import axios')));
      expect(out, contains('async function GetHomePosts('));
      expect(out, contains('const catalog ='));
      expect(out, isNot(contains('export {')));
    });

    test('buildSource concatenates modules and injects providerContext', () {
      final js = JsVegaProvider.buildSource({
        'catalog': 'const catalog = [];',
        'posts': 'function GetHomePosts(a){ return []; }',
      }, 'prov');
      expect(js, contains('var providerContext ='));
      expect(js, contains('kvStore'));
      expect(js, contains('// ---- catalog.js ----'));
      expect(js, contains('// ---- posts.js ----'));
      // catalog must come before posts so posts can reference it.
      expect(js.indexOf('catalog.js'), lessThan(js.indexOf('posts.js')));
    });
  });

  group('Vega shapes', () {
    test('Post maps to a MediaItem keyed by link', () {
      final p = VegaPost.fromJson(
          {'title': 'Show', 'link': 'https://s/x', 'image': 'https://s/i.jpg'});
      final m = p.toMediaItem();
      expect(m.ref.id, 'https://s/x');
      expect(m.title, 'Show');
      expect(m.poster, 'https://s/i.jpg');
    });

    test('Info.linkList carries both episode and direct links', () {
      final info = VegaInfo.fromJson({
        'title': 'Series',
        'image': 'i', 'synopsis': 's', 'type': 'series',
        'imdbId': 'tt0000001',
        'linkList': [
          {'title': 'Season 1', 'episodesLink': 'https://s/eps'},
          {'title': 'Dub', 'directLinks': [{'title': 'E1', 'link': 'https://s/e1'}]},
        ],
      });
      expect(info.mediaType, MediaType.series);
      expect(info.linkList.first.episodesLink, 'https://s/eps');
      expect(info.linkList.last.directLinks.single.link, 'https://s/e1');
      expect(info.toMediaItem('https://s/x').ref.imdbId, 'tt0000001');
    });

    test('Stream subtitle MIME types map to player formats', () {
      final s = VegaStream.fromJson({
        'server': 'S1', 'link': 'https://s/v.m3u8', 'type': 'hls',
        'quality': '1080',
        'subtitles': [
          {'title': 'English', 'language': 'en', 'uri': 'https://s/en.vtt', 'type': 'text/vtt'},
          {'title': 'French', 'language': 'fr', 'uri': 'https://s/fr.srt', 'type': 'application/x-subrip'},
        ],
      });
      expect(s.subtitles, hasLength(2));
      expect(s.subtitles.first.toSubtitle().format, 'vtt');
      expect(s.subtitles.last.toSubtitle().format, 'srt');
      expect(s.subtitles.first.toSubtitle().lang, 'en');
    });

    test('SkipInterval parses intro markers', () {
      final s = VegaStream.fromJson({
        'server': 'S', 'link': 'l', 'type': 'mp4',
        'skip': [{'title': 'Intro', 'from': 10, 'to': 90}],
      });
      expect(s.skip.single.from, 10);
      expect(s.skip.single.to, 90);
      expect(s.skip.single.title, 'Intro');
    });
  });
}
