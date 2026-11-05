import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

/// Vega: JavaScript providers with a manifest, executed in a sandbox.
class VegaAdapter extends JsEcosystemAdapterBase {
  VegaAdapter({
    required super.store,
    super.policy,
    super.dio,
  }) : super(dialect: vegaDialect);

  @override
  Ecosystem get ecosystem => Ecosystem.vega;

  /// Provisional mapping — verify in Phase 0 against the Vega repo.
  static const JsDialect vegaDialect = JsDialect(
    manifestFileName: 'manifest.json',
    repoPluginsKey: 'providers',
    fnHome: 'getPosts',
    fnSearch: 'search',
    fnDetail: 'getMeta',
    fnStreams: 'getStream',
    fnSubtitles: 'getSubtitles',
    fieldItems: 'items',
    itemTitle: 'title',
    itemPoster: 'image',
    itemUrl: 'url',
    streamUrl: 'url',
    streamQuality: 'quality',
  );
}
