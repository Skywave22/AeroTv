import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

/// Browse — the extension list.
///
/// A section per ecosystem with that ecosystem's providers underneath, the way
/// SkyStream presents its own extensions: SkyStream first, then Vega, then
/// CloudStream. Tapping a provider opens its own page with its own hero and
/// categories.
///
/// Empty sections are still shown, with an add action, so an ecosystem is
/// discoverable before anything is installed. CloudStream is listed as
/// "Beta soon" rather than hidden or faked. Streams-only scrapers are listed to
/// explain where they do appear.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTvProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final sourcesAsync = ref.watch(installedSourcesProvider);
    final registry = ref.watch(adapterRegistryProvider);

    final unavailable = <Ecosystem, String>{
      for (final eco in Ecosystem.values)
        if (registry.forEcosystem(eco) case final adapter?)
          if (!adapter.isAvailable)
            eco: adapter.unavailableReason ?? 'Not available on this platform',
    };

    return Scaffold(
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your providers',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(installedSourcesProvider),
        ),
        data: (sources) {
          final sections = ProviderDirectory.build(
            sources,
            unavailable: unavailable,
          );
          final pad = Adaptive.pagePadding(formFactor);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(installedSourcesProvider);
              await ref.read(installedSourcesProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 40),
              children: [
                for (final section in sections)
                  _Section(
                    section: section,
                    formFactor: formFactor,
                    canOpen: (s) =>
                        ProviderDirectory.canOpen(s, unavailable: unavailable),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.formFactor,
    required this.canOpen,
  });

  final ProviderSection section;
  final FormFactor formFactor;
  final bool Function(InstalledSource) canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eco = section.ecosystem;
    final tint = Color(eco.colorSeed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (section.isBeta)
                const MetaChip(label: 'Beta soon', tone: MetaChipTone.warning)
              else
                Text(
                  '${section.sources.length}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AeroColors.textTertiary),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 10),
          child: Text(
            section.note,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AeroColors.textSecondary),
          ),
        ),
        for (final s in section.sources)
          _ProviderTile(
            source: s,
            enabled: section.isOpenable && canOpen(s),
            formFactor: formFactor,
          ),
        if (section.isEmpty && !section.isStreamsOnly)
          _AddTile(section: section, formFactor: formFactor),
        if (!section.isEmpty && !section.isStreamsOnly && !section.isBeta)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: TextButton.icon(
                onPressed: () => context.openExtensions(ecosystem: eco),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add ${section.noun.toLowerCase()}'),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Divider(height: 1),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.source,
    required this.enabled,
    required this.formFactor,
  });

  final InstalledSource source;
  final bool enabled;
  final FormFactor formFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = Color(source.ecosystem.colorSeed);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocus(
        borderRadius: 12,
        enabled: enabled,
        onSelect: enabled
            ? () => context.openProviderHome(source)
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: formFactor == FormFactor.tv ? 16 : 10),
            decoration: BoxDecoration(
              color: AeroColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: tint.withValues(alpha: 0.18),
                  backgroundImage: source.logo == null
                      ? null
                      : NetworkImage(source.logo!),
                  child: source.logo == null
                      ? Icon(Icons.extension_rounded, size: 16, color: tint)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        source.enabled
                            ? 'v${source.version}'
                            : 'v${source.version} · disabled',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AeroColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right_rounded,
                      color: AeroColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.section, required this.formFactor});

  final ProviderSection section;
  final FormFactor formFactor;

  @override
  Widget build(BuildContext context) {
    final beta = section.isBeta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocus(
        borderRadius: 12,
        enabled: !beta,
        onSelect: beta
            ? null
            : () => context.openExtensions(ecosystem: section.ecosystem),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: formFactor == FormFactor.tv ? 18 : 14),
          decoration: BoxDecoration(
            border: Border.all(color: AeroColors.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(beta ? Icons.schedule_rounded : Icons.add_rounded,
                  size: 18, color: AeroColors.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  beta
                      ? 'CloudStream support is in beta soon'
                      : 'No ${section.noun.toLowerCase()} yet — add one',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AeroColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
