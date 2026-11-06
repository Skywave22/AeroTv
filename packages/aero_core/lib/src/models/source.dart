import 'capability.dart';
import 'ecosystem.dart';
import 'media.dart';

/// Where an installable source came from: a direct URL or a repository entry.
class SourceRef {
  const SourceRef({
    required this.ecosystem,
    required this.url,
    this.repoId,
    this.name,
    this.version,
    this.expectedSha256,
    this.extra = const {},
  });

  final Ecosystem ecosystem;

  /// Manifest URL (Stremio), bundle URL (JS), or `.cs3` URL (CloudStream).
  final String url;
  final String? repoId;
  final String? name;
  final String? version;

  /// Hash pinning for untrusted native/JS payloads.
  final String? expectedSha256;

  /// Raw repository entry, when the ecosystem ships metadata alongside the
  /// plugin URL (SkyStream inlines `plugin.json` fields in `repo.json`).
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
        'ecosystem': ecosystem.id,
        'url': url,
        if (repoId != null) 'repoId': repoId,
        if (name != null) 'name': name,
        if (version != null) 'version': version,
        if (expectedSha256 != null) 'expectedSha256': expectedSha256,
      };
}

/// A user-installed add-on / provider / scraper / plugin.
class InstalledSource {
  const InstalledSource({
    required this.id,
    required this.ecosystem,
    required this.name,
    required this.url,
    this.version = '0.0.0',
    this.description,
    this.logo,
    this.enabled = true,
    this.priority = 100,
    this.repoId,
    this.capabilities = const {},
    this.types = const [],
    this.idPrefixes = const [],
    this.catalogs = const [],
    this.config = const {},
    this.installedAt,
    this.sha256,
    this.adult = false,
  });

  final String id;
  final Ecosystem ecosystem;
  final String name;
  final String url;
  final String version;
  final String? description;
  final String? logo;
  final bool enabled;

  /// Lower runs first. Users reorder this in the Extensions Manager.
  final int priority;
  final String? repoId;
  final Set<Capability> capabilities;
  final List<MediaType> types;

  /// e.g. `['tt']` for IMDb-only add-ons — lets the resolver skip cheaply.
  final List<String> idPrefixes;
  final List<CatalogDescriptor> catalogs;
  final Map<String, dynamic> config;
  final DateTime? installedAt;
  final String? sha256;
  final bool adult;

  /// Composite key: the same add-on id can exist in two ecosystems.
  String get key => '${ecosystem.id}:$id';

  bool supports(MediaType type) => types.isEmpty || types.contains(type);

  bool acceptsId(String mediaId) {
    if (idPrefixes.isEmpty) return true;
    return idPrefixes.any(mediaId.startsWith);
  }

  bool can(Capability c) => capabilities.contains(c);

  InstalledSource copyWith({
    bool? enabled,
    int? priority,
    String? name,
    String? version,
    Map<String, dynamic>? config,
    Set<Capability>? capabilities,
    List<CatalogDescriptor>? catalogs,
    String? sha256,
  }) =>
      InstalledSource(
        id: id,
        ecosystem: ecosystem,
        name: name ?? this.name,
        url: url,
        version: version ?? this.version,
        description: description,
        logo: logo,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
        repoId: repoId,
        capabilities: capabilities ?? this.capabilities,
        types: types,
        idPrefixes: idPrefixes,
        catalogs: catalogs ?? this.catalogs,
        config: config ?? this.config,
        installedAt: installedAt,
        sha256: sha256 ?? this.sha256,
        adult: adult,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ecosystem': ecosystem.id,
        'name': name,
        'url': url,
        'version': version,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
        'enabled': enabled,
        'priority': priority,
        if (repoId != null) 'repoId': repoId,
        'capabilities': capabilities.map((c) => c.name).toList(),
        'types': types.map((t) => t.wire).toList(),
        'idPrefixes': idPrefixes,
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
        'config': config,
        if (installedAt != null) 'installedAt': installedAt!.toIso8601String(),
        if (sha256 != null) 'sha256': sha256,
        'adult': adult,
      };

  factory InstalledSource.fromJson(Map<String, dynamic> j) => InstalledSource(
        id: (j['id'] ?? '').toString(),
        ecosystem: Ecosystem.fromId(j['ecosystem'] as String),
        name: (j['name'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        version: (j['version'] ?? '0.0.0').toString(),
        description: j['description'] as String?,
        logo: j['logo'] as String?,
        enabled: j['enabled'] as bool? ?? true,
        priority: (j['priority'] as num?)?.toInt() ?? 100,
        repoId: j['repoId'] as String?,
        capabilities: (j['capabilities'] as List?)
                ?.map((e) => Capability.values.firstWhere(
                      (c) => c.name == e,
                      orElse: () => Capability.streams,
                    ))
                .toSet() ??
            const {},
        types: (j['types'] as List?)
                ?.map((e) => MediaType.fromWire(e as String?))
                .toList() ??
            const [],
        idPrefixes:
            (j['idPrefixes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        catalogs: (j['catalogs'] as List?)
                ?.map((e) =>
                    CatalogDescriptor.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        config: Map<String, dynamic>.from(j['config'] as Map? ?? const {}),
        installedAt: DateTime.tryParse(j['installedAt']?.toString() ?? ''),
        sha256: j['sha256'] as String?,
        adult: j['adult'] as bool? ?? false,
      );
}

/// A catalog declared in a source's manifest.
class CatalogDescriptor {
  const CatalogDescriptor({
    required this.id,
    required this.type,
    this.name,
    this.searchable = false,
    this.genres = const [],
    this.pageSize,
    this.requiredExtras = const [],
  });

  final String id;
  final MediaType type;
  final String? name;
  final bool searchable;
  final List<String> genres;
  final int? pageSize;

  /// Extras the add-on *requires* before this catalog returns anything.
  /// A catalog demanding input cannot be a passive Home row.
  final List<String> requiredExtras;

  String get displayTitle => name ?? id;

  /// `skip`/`limit` are pagination, not filters, so they do not disqualify.
  bool get isHomeEligible =>
      !requiredExtras.any((e) => e != 'skip' && e != 'limit');

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        if (name != null) 'name': name,
        'searchable': searchable,
        'genres': genres,
        if (pageSize != null) 'pageSize': pageSize,
        if (requiredExtras.isNotEmpty) 'requiredExtras': requiredExtras,
      };

  factory CatalogDescriptor.fromJson(Map<String, dynamic> j) => CatalogDescriptor(
        id: (j['id'] ?? '').toString(),
        type: MediaType.fromWire(j['type'] as String?),
        name: j['name'] as String?,
        searchable: j['searchable'] as bool? ?? false,
        genres: (j['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        pageSize: (j['pageSize'] as num?)?.toInt(),
        requiredExtras: (j['requiredExtras'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// A plugin repository (Vega / Nuvio / SkyStream / CloudStream).
class Repository {
  const Repository({
    required this.id,
    required this.ecosystem,
    required this.url,
    required this.name,
    this.lastSync,
    this.enabled = true,
  });

  final String id;
  final Ecosystem ecosystem;
  final String url;
  final String name;
  final DateTime? lastSync;
  final bool enabled;

  bool get isSecure => Uri.tryParse(url)?.scheme == 'https';

  Map<String, dynamic> toJson() => {
        'id': id,
        'ecosystem': ecosystem.id,
        'url': url,
        'name': name,
        if (lastSync != null) 'lastSync': lastSync!.toIso8601String(),
        'enabled': enabled,
      };

  factory Repository.fromJson(Map<String, dynamic> j) => Repository(
        id: (j['id'] ?? '').toString(),
        ecosystem: Ecosystem.fromId(j['ecosystem'] as String),
        url: (j['url'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        lastSync: DateTime.tryParse(j['lastSync']?.toString() ?? ''),
        enabled: j['enabled'] as bool? ?? true,
      );
}

/// Rolling health counters used to auto-demote flaky providers.
class ProviderHealth {
  const ProviderHealth({
    required this.sourceKey,
    this.successCount = 0,
    this.failCount = 0,
    this.avgLatencyMs = 0,
    this.lastChecked,
    this.lastError,
  });

  final String sourceKey;
  final int successCount;
  final int failCount;
  final double avgLatencyMs;
  final DateTime? lastChecked;
  final String? lastError;

  int get total => successCount + failCount;

  double get successRate => total == 0 ? 1.0 : successCount / total;

  /// A source that keeps failing gets blocked from auto-play.
  bool get isFlaky => total >= 5 && successRate < 0.25;

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'successCount': successCount,
        'failCount': failCount,
        'avgLatencyMs': avgLatencyMs,
        if (lastChecked != null) 'lastChecked': lastChecked!.toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      };

  factory ProviderHealth.fromJson(Map<String, dynamic> j) => ProviderHealth(
        sourceKey: (j['sourceKey'] ?? '').toString(),
        successCount: (j['successCount'] as num?)?.toInt() ?? 0,
        failCount: (j['failCount'] as num?)?.toInt() ?? 0,
        avgLatencyMs: (j['avgLatencyMs'] as num?)?.toDouble() ?? 0,
        lastChecked: DateTime.tryParse(j['lastChecked']?.toString() ?? ''),
        lastError: j['lastError'] as String?,
      );
}
