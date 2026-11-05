import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

/// SkyStream: JS plugins, browsed one at a time in the Providers tab using
/// each plugin's own home/categories/search.
class SkyStreamAdapter extends JsEcosystemAdapterBase {
  SkyStreamAdapter({
    required super.store,
    super.policy,
    super.dio,
  }) : super(dialect: skyStreamDialect);

  @override
  Ecosystem get ecosystem => Ecosystem.skystream;

  /// Provisional mapping — verify in Phase 0 against the SkyStream repo.
  static const JsDialect skyStreamDialect = JsDialect(
    manifestFileName: 'plugins.json',
    repoPluginsKey: 'plugins',
    fnHome: 'loadHome',
    fnSearch: 'search',
    fnDetail: 'load',
    fnStreams: 'loadLinks',
    fieldItems: 'items',
    itemTitle: 'name',
    itemPoster: 'poster',
    itemUrl: 'url',
    streamUrl: 'url',
    streamQuality: 'label',
  );
}
