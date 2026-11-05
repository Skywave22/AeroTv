import '../models/capability.dart';
import '../models/ecosystem.dart';
import '../models/source.dart';
import 'ecosystem_adapter.dart';

/// Holds one adapter per ecosystem and answers cross-ecosystem questions.
class AdapterRegistry {
  final Map<Ecosystem, EcosystemAdapter> _adapters = {};

  void register(EcosystemAdapter adapter) {
    _adapters[adapter.ecosystem] = adapter;
  }

  void unregister(Ecosystem ecosystem) => _adapters.remove(ecosystem);

  EcosystemAdapter? forEcosystem(Ecosystem e) => _adapters[e];

  List<EcosystemAdapter> get all => _adapters.values.toList();

  List<EcosystemAdapter> get available =>
      _adapters.values.where((a) => a.isAvailable).toList();

  /// Adapters that can resolve streams on this platform, in ecosystem order.
  List<EcosystemAdapter> get streamProviders => available
      .where((a) => a.capabilities.contains(Capability.streams))
      .toList()
    ..sort((a, b) => a.ecosystem.index.compareTo(b.ecosystem.index));

  /// Enabled sources across every ecosystem, ordered by user priority.
  Future<List<InstalledSource>> enabledSources() async {
    final out = <InstalledSource>[];
    for (final a in available) {
      try {
        out.addAll((await a.installedSources()).where((s) => s.enabled));
      } catch (_) {
        // One misbehaving adapter must not hide the others.
      }
    }
    out.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      return p != 0 ? p : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  Future<void> disposeAll() async {
    for (final a in _adapters.values) {
      try {
        await a.dispose();
      } catch (_) {
        // Ignore teardown failures.
      }
    }
    _adapters.clear();
  }
}
