import 'package:aero_core/aero_core.dart';

/// A parsed Stremio `manifest.json`.
///
/// Spec: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md
class StremioManifest {
  const StremioManifest({
    required this.id,
    required this.version,
    required this.name,
    this.description,
    this.logo,
    this.background,
    this.types = const [],
    this.resources = const [],
    this.catalogs = const [],
    this.idPrefixes = const [],
    this.behaviorHints = const {},
    this.contactEmail,
    this.isAdult = false,
  });

  final String id;
  final String version;
  final String name;
  final String? description;
  final String? logo;
  final String? background;
  final List<MediaType> types;
  final List<StremioResource> resources;
  final List<CatalogDescriptor> catalogs;
  final List<String> idPrefixes;
  final Map<String, dynamic> behaviorHints;
  final String? contactEmail;
  final bool isAdult;

  /// `configurationRequired` add-ons must be configured before install.
  bool get requiresConfiguration =>
      behaviorHints['configurationRequired'] == true;

  bool get isConfigurable => behaviorHints['configurable'] == true;

  Set<Capability> get capabilities {
    final out = <Capability>{};
    for (final r in resources) {
      switch (r.name) {
        case 'catalog':
          out.add(Capability.catalogs);
          if (catalogs.any((c) => c.searchable)) out.add(Capability.search);
          break;
        case 'meta':
          out.add(Capability.meta);
          break;
        case 'stream':
          out.add(Capability.streams);
          break;
        case 'subtitles':
          out.add(Capability.subtitles);
          break;
      }
    }
    return out;
  }

  /// Does this manifest declare `resource` for `type`, honouring per-resource
  /// `types` and `idPrefixes` overrides?
  bool serves(String resource, MediaType type, {String? mediaId}) {
    for (final r in resources.where((r) => r.name == resource)) {
      final types = r.types.isEmpty ? this.types : r.types;
      if (types.isNotEmpty && !types.contains(type)) continue;
      final prefixes = r.idPrefixes.isEmpty ? idPrefixes : r.idPrefixes;
      if (mediaId != null && prefixes.isNotEmpty) {
        if (!prefixes.any(mediaId.startsWith)) continue;
      }
      return true;
    }
    return false;
  }

  factory StremioManifest.fromJson(Map<String, dynamic> j) {
    final hints = Map<String, dynamic>.from(j['behaviorHints'] as Map? ?? const {});
    return StremioManifest(
      id: (j['id'] ?? '').toString(),
      version: (j['version'] ?? '0.0.0').toString(),
      name: (j['name'] ?? 'Unnamed add-on').toString(),
      description: j['description'] as String?,
      logo: j['logo'] as String?,
      background: j['background'] as String?,
      types: (j['types'] as List?)
              ?.map((e) => MediaType.fromWire(e as String?))
              .toList() ??
          const [],
      resources: (j['resources'] as List?)
              ?.map(StremioResource.parse)
              .whereType<StremioResource>()
              .toList() ??
          const [],
      catalogs: (j['catalogs'] as List?)
              ?.map((e) => _catalog(Map<String, dynamic>.from(e as Map)))
              .whereType<CatalogDescriptor>()
              .toList() ??
          const [],
      idPrefixes:
          (j['idPrefixes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      behaviorHints: hints,
      contactEmail: j['contactEmail'] as String?,
      isAdult: hints['adult'] == true,
    );
  }

  static CatalogDescriptor? _catalog(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    // `extra` declares supported filters; `search` presence ⇒ searchable.
    final extra = (j['extra'] as List?) ?? const [];
    // Accept our own toJson output too, otherwise a cached manifest loses
    // searchable/genres/requiredExtras on every launch after the first.
    if (j.containsKey('searchable') && !j.containsKey('extra')) {
      return CatalogDescriptor.fromJson(j);
    }
    var searchable = false;
    var genres = <String>[];
    final requiredExtras = <String>[];
    int? pageSize;
    for (final e in extra) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final name = m['name']?.toString();
      if (name == null || name.isEmpty) continue;
      if (name == 'search') searchable = true;
      if (m['isRequired'] == true && !requiredExtras.contains(name)) {
        requiredExtras.add(name);
      }
      if (name == 'genre') {
        genres = (m['options'] as List?)?.map((o) => o.toString()).toList() ?? const [];
      }
    }
    if (j['pageSize'] != null) pageSize = (j['pageSize'] as num?)?.toInt();
    return CatalogDescriptor(
      id: id,
      type: MediaType.fromWire(j['type'] as String?),
      name: j['name'] as String?,
      searchable: searchable,
      genres: genres,
      pageSize: pageSize,
      requiredExtras: requiredExtras,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'name': name,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
        if (background != null) 'background': background,
        'types': types.map((t) => t.wire).toList(),
        'resources': resources.map((r) => r.toJson()).toList(),
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
        'idPrefixes': idPrefixes,
        'behaviorHints': behaviorHints,
        if (contactEmail != null) 'contactEmail': contactEmail,
      };
}

/// A resource entry. The spec allows either a bare string ("stream") or an
/// object with per-resource `types` / `idPrefixes`.
class StremioResource {
  const StremioResource({
    required this.name,
    this.types = const [],
    this.idPrefixes = const [],
  });

  final String name;
  final List<MediaType> types;
  final List<String> idPrefixes;

  static StremioResource? parse(Object? raw) {
    if (raw is String) return StremioResource(name: raw);
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final name = m['name']?.toString();
      if (name == null || name.isEmpty) return null;
      // Some add-ons use a singular `type` instead of `types`.
      final types = <MediaType>[];
      if (m['types'] is List) {
        types.addAll((m['types'] as List).map((e) => MediaType.fromWire(e as String?)));
      } else if (m['type'] != null) {
        types.add(MediaType.fromWire(m['type'] as String?));
      }
      return StremioResource(
        name: name,
        types: types,
        idPrefixes:
            (m['idPrefixes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (types.isNotEmpty) 'types': types.map((t) => t.wire).toList(),
        if (idPrefixes.isNotEmpty) 'idPrefixes': idPrefixes,
      };
}
