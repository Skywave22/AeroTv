import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

/// Nuvio: JS scrapers discovered from a repository manifest, typically keyed
/// by TMDB id rather than IMDb.
class NuvioAdapter extends JsEcosystemAdapterBase {
  NuvioAdapter({
    required super.store,
    super.policy,
    super.dio,
  }) : super(dialect: nuvioDialect);

  @override
  Ecosystem get ecosystem => Ecosystem.nuvio;

  /// Provisional mapping — verify in Phase 0 against the Nuvio repo.
  static const JsDialect nuvioDialect = JsDialect(
    manifestFileName: 'repo.json',
    repoPluginsKey: 'scrapers',
    fnHome: 'getHome',
    fnSearch: 'search',
    fnDetail: 'getDetail',
    fnStreams: 'getSources',
    fieldItems: 'results',
    itemTitle: 'title',
    itemPoster: 'poster',
    itemUrl: 'href',
    streamUrl: 'url',
    streamQuality: 'quality',
  );

  /// Nuvio-style scrapers usually want TMDB ids; expose that so the resolver
  /// can enrich the request before fanning out.
  bool get prefersTmdbIds => true;
}
