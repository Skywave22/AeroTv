import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

/// The Providers tab: browse **one plugin at a time**, natively, using that
/// plugin's own home, categories and search — rather than an aggregated feed.
class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  InstalledSource? _selected;

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(installedSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected?.name ?? 'Providers'),
        leading: _selected == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selected = null),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Manage extensions',
            onPressed: () => context.openExtensions(),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load providers',
          message: '$e',
        ),
        data: (sources) {
          if (sources.isEmpty) {
            return EmptyState(
              icon: Icons.extension_outlined,
              title: 'No providers installed',
              message:
                  'The Providers tab lets you browse a single plugin using its '
                  'own categories and search.\n\nInstall one to get started.',
              actionLabel: 'Open Extensions',
              onAction: () => context.openExtensions(),
            );
          }
          if (_selected != null) {
            return _PluginBrowser(source: _selected!);
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const SectionHeader(
                title: 'Choose a provider',
                subtitle: 'Browse one plugin at a time, using its own layout.',
              ),
              ...Ecosystem.values.map((eco) {
                final group = sources.where((s) => s.ecosystem == eco).toList();
                if (group.isEmpty) return const SizedBox.shrink();
                final adapter = ref.read(adapterRegistryProvider).forEcosystem(eco);
                final available = adapter?.isAvailable ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          EcosystemBadge(ecosystem: eco),
                          const SizedBox(width: 8),
                          Text(
                            '${group.length} ${eco.sourceNoun.toLowerCase()}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (!available)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          adapter?.unavailableReason ?? 'Unavailable',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AeroColors.warning,
                              ),
                        ),
                      ),
                    ...group.map((s) => ListTile(
                          enabled: available && s.enabled,
                          leading: CircleAvatar(
                            backgroundColor: Color(eco.colorSeed).withValues(alpha: 0.2),
                            child: Text(
                              s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                              style: TextStyle(color: Color(eco.colorSeed)),
                            ),
                          ),
                          title: Text(s.name),
                          subtitle: Text(
                            s.enabled ? 'v${s.version}' : 'Disabled',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: available && s.enabled
                              ? () => setState(() => _selected = s)
                              : null,
                        )),
                  ],
                );
              }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Browses a single plugin's own catalogs.
class _PluginBrowser extends ConsumerStatefulWidget {
  const _PluginBrowser({required this.source});

  final InstalledSource source;

  @override
  ConsumerState<_PluginBrowser> createState() => _PluginBrowserState();
}

class _PluginBrowserState extends ConsumerState<_PluginBrowser> {
  List<CatalogRow>? _catalogs;
  final Map<String, List<MediaItem>> _items = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final adapter =
          ref.read(adapterRegistryProvider).forEcosystem(widget.source.ecosystem);
      if (adapter == null || !adapter.isAvailable) {
        setState(() {
          _error = adapter?.unavailableReason ?? 'This ecosystem is unavailable.';
          _loading = false;
        });
        return;
      }
      final catalogs = await adapter.catalogs(widget.source.id);
      if (!mounted) return;
      setState(() => _catalogs = catalogs);

      for (final c in catalogs.take(6)) {
        try {
          final page = await adapter.browse(
            widget.source.id,
            c.catalogId,
            const CatalogQuery(),
          );
          if (!mounted) return;
          setState(() => _items[c.catalogId] = page.items);
        } catch (_) {
          // Skip a failing category.
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);

    if (_loading && _catalogs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load this provider',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final catalogs = _catalogs ?? const [];
    if (catalogs.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No categories',
        message:
            '${widget.source.name} did not report any browsable categories.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          for (final c in catalogs)
            MediaRow(
              title: c.title,
              rowKey: '${widget.source.key}:${c.catalogId}',
              items: _items[c.catalogId] ?? const [],
              isLoading: _loading && !_items.containsKey(c.catalogId),
              formFactor: formFactor,
              onSelect: (item) => context.openDetails(
                item.ref,
                sourceId: widget.source.id,
                ecosystem: widget.source.ecosystem,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
