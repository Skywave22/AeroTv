import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

/// Providers — the plugin directory.
///
/// This tab answers "what do I have installed, and does it work?". Browsing a
/// plugin's *content* lives in the Browse tab; installing and configuring lives
/// in the Extensions manager. Keeping those three separate stops the old
/// behaviour where Providers duplicated Browse with a worse layout.
class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTvProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final sourcesAsync = ref.watch(installedSourcesProvider);
    final pad = Adaptive.pagePadding(formFactor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Providers'),
        actions: [
          IconButton(
            tooltip: 'Add a provider',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.openExtensions(),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your plugins',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(installedSourcesProvider),
        ),
        data: (sources) {
          if (sources.isEmpty) {
            return EmptyState(
              icon: Icons.extension_outlined,
              title: 'No plugins installed',
              message: 'Aero TV ships with no sources. Add a repository or a '
                  'plugin URL to get started.',
              actionLabel: 'Add a plugin',
              onAction: () => context.openExtensions(),
            );
          }

          // Group by ecosystem so each plugin world is visually distinct.
          final byEco = <Ecosystem, List<InstalledSource>>{};
          for (final s in sources) {
            byEco.putIfAbsent(s.ecosystem, () => []).add(s);
          }
          final ecosystems = Ecosystem.values.where(byEco.containsKey).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(installedSourcesProvider);
              await ref.read(installedSourcesProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
              children: [
                for (final eco in ecosystems) ...[
                  SectionHeader(
                    title: eco.displayName,
                    subtitle: _ecosystemNote(eco),
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                    trailing: Text(
                      '${byEco[eco]!.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final s in byEco[eco]!)
                    _ProviderTile(source: s, formFactor: formFactor),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// One honest line about what each ecosystem can actually do, derived from
  /// the verified contracts rather than marketing.
  static String _ecosystemNote(Ecosystem eco) => switch (eco) {
        Ecosystem.stremio => 'Catalogs, search, details and streams',
        Ecosystem.skystream => 'Own home categories, search and streams',
        Ecosystem.vega => 'Own catalogs, search and streams',
        Ecosystem.nuvio => 'Streams only — metadata comes from TMDB',
        Ecosystem.cloudstream => 'Android only, disabled pending licence review',
      };
}

class _ProviderTile extends ConsumerWidget {
  const _ProviderTile({required this.source, required this.formFactor});

  final InstalledSource source;
  final FormFactor formFactor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final registry = ref.watch(adapterRegistryProvider);
    final adapter = registry.forEcosystem(source.ecosystem);
    final canBrowse =
        adapter?.capabilities.contains(Capability.catalogs) ?? false;
    final unavailable = adapter != null && !adapter.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocus(
        borderRadius: 14,
        onSelect: () => _open(context, canBrowse),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _open(context, canBrowse),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Color(source.ecosystem.colorSeed).withValues(alpha: 0.16),
                    child: source.logo != null && source.logo!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              source.logo!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _fallbackIcon(source.ecosystem),
                            ),
                          )
                        : _fallbackIcon(source.ecosystem),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                source.name,
                                style: theme.textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!source.enabled) ...[
                              const SizedBox(width: 8),
                              const MetaChip(label: 'Disabled'),
                            ],
                            if (unavailable) ...[
                              const SizedBox(width: 8),
                              const MetaChip(label: 'Unavailable'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'v${source.version} · '
                          '${canBrowse ? "Browsable" : "Streams only"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AeroColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canBrowse)
                    const Icon(Icons.chevron_right_rounded, size: 22)
                  else
                    Tooltip(
                      message: 'This plugin only supplies streams. It appears '
                          'in the source picker when you play something.',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AeroColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(Ecosystem eco) => Icon(
        eco == Ecosystem.nuvio ? Icons.bolt_rounded : Icons.extension_rounded,
        color: Color(eco.colorSeed),
        size: 20,
      );

  void _open(BuildContext context, bool canBrowse) {
    if (canBrowse) {
      // Browse is now a directory of sections, so open this provider's own
      // page rather than selecting it in a picker that no longer exists.
      context.openProviderHome(source);
    } else {
      context.openProviderSettings(source);
    }
  }
}
