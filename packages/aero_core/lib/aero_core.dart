/// Aero TV core domain layer.
///
/// This package is pure Dart: no Flutter, no I/O. It defines the vocabulary
/// every ecosystem adapter speaks, plus the resolver and ranking engine.
library;

export 'src/models/capability.dart';
export 'src/models/catalog.dart';
export 'src/models/ecosystem.dart';
export 'src/models/media.dart';
export 'src/models/play_request.dart';
export 'src/models/source.dart';
export 'src/models/stream_link.dart';
export 'src/models/subtitle.dart';
export 'src/adapter/ecosystem_adapter.dart';
export 'src/adapter/adapter_registry.dart';
export 'src/resolver/stream_resolver.dart';
export 'src/resolver/stream_ranker.dart';
export 'src/resolver/ranking_rules.dart';
export 'src/metadata/metadata_resolver.dart';
export 'src/metadata/id_map.dart';
export 'src/util/result.dart';
export 'src/util/aero_log.dart';
