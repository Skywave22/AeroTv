import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';

/// CRUD for repositories and installed sources across all ecosystems.
///
/// Also implements [StremioStore]-shaped persistence via [loadByEcosystem] /
/// [save] / [delete], so adapters stay free of any Drift dependency.
class SourceRepository {
  SourceRepository(this.db);

  final AeroDatabase db;

  // ---------------------------------------------------------------- sources

  Future<List<InstalledSource>> loadByEcosystem(Ecosystem ecosystem) async {
    final rows = await (db.select(db.installedSources)
          ..where((t) => t.ecosystem.equals(ecosystem.id))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
    return rows.map(_sourceFromRow).toList();
  }

  Future<List<InstalledSource>> loadAll() async {
    final rows = await (db.select(db.installedSources)
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
    return rows.map(_sourceFromRow).toList();
  }

  Future<void> save(InstalledSource s) async {
    await db.into(db.installedSources).insertOnConflictUpdate(_sourceToRow(s));
  }

  Future<void> delete(Ecosystem ecosystem, String id) async {
    await (db.delete(db.installedSources)
          ..where((t) => t.id.equals(id) & t.ecosystem.equals(ecosystem.id)))
        .go();
  }

  Future<void> setEnabled(Ecosystem ecosystem, String id, bool enabled) async {
    await (db.update(db.installedSources)
          ..where((t) => t.id.equals(id) & t.ecosystem.equals(ecosystem.id)))
        .write(InstalledSourcesCompanion(enabled: Value(enabled)));
  }

  /// Persists a new ordering. [keys] are `ecosystem:id` in the desired order.
  Future<void> reorder(List<String> keys) async {
    await db.transaction(() async {
      for (var i = 0; i < keys.length; i++) {
        final parts = keys[i].split(':');
        if (parts.length < 2) continue;
        final eco = parts.first;
        final id = parts.sublist(1).join(':');
        await (db.update(db.installedSources)
              ..where((t) => t.id.equals(id) & t.ecosystem.equals(eco)))
            .write(InstalledSourcesCompanion(priority: Value((i + 1) * 10)));
      }
    });
  }

  Future<void> setConfig(Ecosystem ecosystem, String id, Map<String, dynamic> config) async {
    final rows = await (db.select(db.installedSources)
          ..where((t) => t.id.equals(id) & t.ecosystem.equals(ecosystem.id)))
        .get();
    if (rows.isEmpty) return;
    final current = _sourceFromRow(rows.first);
    await save(current.copyWith(config: {...current.config, ...config}));
  }

  InstalledSource _sourceFromRow(InstalledSourceRow row) {
    final blob = Map<String, dynamic>.from(
      jsonDecode(row.configJson) as Map? ?? const {},
    );
    return InstalledSource(
      id: row.id,
      ecosystem: Ecosystem.fromId(row.ecosystem),
      name: row.name,
      url: row.url,
      version: row.version,
      description: row.description,
      logo: row.logo,
      enabled: row.enabled,
      priority: row.priority,
      repoId: row.repoId,
      capabilities: (blob['capabilities'] as List?)
              ?.map((e) => Capability.values.firstWhere(
                    (c) => c.name == e,
                    orElse: () => Capability.streams,
                  ))
              .toSet() ??
          const {},
      types: (blob['types'] as List?)
              ?.map((e) => MediaType.fromWire(e as String?))
              .toList() ??
          const [],
      idPrefixes:
          (blob['idPrefixes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      catalogs: (blob['catalogs'] as List?)
              ?.map((e) => CatalogDescriptor.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      config: Map<String, dynamic>.from(blob['config'] as Map? ?? const {}),
      installedAt: row.installedAt,
      sha256: row.sha256,
      adult: row.adult,
    );
  }

  InstalledSourcesCompanion _sourceToRow(InstalledSource s) {
    // Store the derived/manifest bits in one JSON blob so schema migrations
    // aren't needed every time an ecosystem adds a manifest field.
    final blob = {
      'capabilities': s.capabilities.map((c) => c.name).toList(),
      'types': s.types.map((t) => t.wire).toList(),
      'idPrefixes': s.idPrefixes,
      'catalogs': s.catalogs.map((c) => c.toJson()).toList(),
      'config': s.config,
    };
    return InstalledSourcesCompanion.insert(
      id: s.id,
      ecosystem: s.ecosystem.id,
      repoId: Value(s.repoId),
      name: s.name,
      url: s.url,
      version: Value(s.version),
      description: Value(s.description),
      logo: Value(s.logo),
      enabled: Value(s.enabled),
      priority: Value(s.priority),
      configJson: Value(jsonEncode(blob)),
      sha256: Value(s.sha256),
      adult: Value(s.adult),
      installedAt: Value(s.installedAt ?? DateTime.now()),
    );
  }

  // ----------------------------------------------------------- repositories

  Future<List<Repository>> loadRepositories([Ecosystem? ecosystem]) async {
    final q = db.select(db.repositories);
    if (ecosystem != null) {
      q.where((t) => t.ecosystem.equals(ecosystem.id));
    }
    final rows = await q.get();
    return rows
        .map((r) => Repository(
              id: r.id,
              ecosystem: Ecosystem.fromId(r.ecosystem),
              url: r.url,
              name: r.name,
              lastSync: r.lastSync,
              enabled: r.enabled,
            ))
        .toList();
  }

  Future<void> saveRepository(Repository r) async {
    await db.into(db.repositories).insertOnConflictUpdate(
          RepositoriesCompanion.insert(
            id: r.id,
            ecosystem: r.ecosystem.id,
            url: r.url,
            name: r.name,
            lastSync: Value(r.lastSync),
            enabled: Value(r.enabled),
          ),
        );
  }

  Future<void> deleteRepository(Ecosystem ecosystem, String id) async {
    await (db.delete(db.repositories)
          ..where((t) => t.id.equals(id) & t.ecosystem.equals(ecosystem.id)))
        .go();
    // Orphaned sources from that repo are removed too.
    await (db.delete(db.installedSources)
          ..where((t) => t.repoId.equals(id) & t.ecosystem.equals(ecosystem.id)))
        .go();
  }
}
