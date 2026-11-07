import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

/// One provider's own settings, in place of a shared extensions manager.
///
/// SkyStream gives every installed plugin its own settings page — enable,
/// order, update, remove — and Aero follows that shape here. The common
/// controls live on this page; anything the provider itself exposes (a Vega
/// provider's own config keys) is listed underneath, because a plugin's config
/// is part of its identity, not an afterthought in a global menu.
class ProviderSettingsScreen extends ConsumerStatefulWidget {
  const ProviderSettingsScreen({
    super.key,
    this.source,
    this.sourceId,
    this.ecosystemId,
  });

  final InstalledSource? source;
  final String? sourceId;
  final String? ecosystemId;

  @override
  ConsumerState<ProviderSettingsScreen> createState() =>
      _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState
    extends ConsumerState<ProviderSettingsScreen> {
  InstalledSource? _resolved;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _resolved = widget.source;
    if (_resolved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final all = await ref.read(installedSourcesProvider.future);
    final match = all
        .where((s) =>
            s.id == widget.sourceId &&
            (widget.ecosystemId == null || s.ecosystem.id == widget.ecosystemId))
        .firstOrNull;
    if (mounted) setState(() => _resolved = match);
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _status = message);
    } catch (e) {
      if (mounted) setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _resolved ?? widget.source;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(source?.name ?? 'Provider settings'),
        actions: [
          if (source != null)
            IconButton(
              tooltip: 'Diagnostics',
              icon: const Icon(Icons.monitor_heart_outlined),
              onPressed: () => context.openDiagnostics(source),
            ),
        ],
      ),
      body: source == null
          ? const EmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Provider not found',
              message: 'It may have been removed.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Header(source: source),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _status!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AeroColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 8),
                _SectionLabel(label: 'This provider'),
                SwitchListTile(
                  title: const Text('Enabled'),
                  subtitle: const Text(
                      'A disabled provider is skipped when you play something.'),
                  value: source.enabled,
                  onChanged: (v) => _run(() async {
                    final updated = source.copyWith(enabled: v);
                    await ref.read(sourceRepoProvider).save(updated);
                    _invalidateAll();
                    if (mounted) setState(() => _resolved = updated);
                    return v ? 'Enabled' : 'Disabled';
                  }),
                ),
                ListTile(
                  title: const Text('Update'),
                  subtitle: const Text(
                      'Re-check the source for a newer version of this provider.'),
                  trailing: const Icon(Icons.refresh_rounded),
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    final registry = ref.read(adapterRegistryProvider);
                    final adapter =
                        registry.forEcosystem(source.ecosystem);
                    if (adapter == null) return 'No adapter for this ecosystem';
                    final res = await adapter.checkUpdate(source.id);
                    _invalidateAll();
                    return res.isOk
                        ? 'Updated to v${res.valueOrNull!.version}'
                        : (res.errorOrNull ?? 'Update failed');
                  }),
                ),
                ListTile(
                  title: const Text('Health check'),
                  subtitle:
                      const Text('Try to start this provider in its sandbox.'),
                  trailing: const Icon(Icons.bolt_rounded),
                  enabled: !_busy,
                  onTap: () => _run(() async {
                    final registry = ref.read(adapterRegistryProvider);
                    final adapter =
                        registry.forEcosystem(source.ecosystem);
                    if (adapter == null) return 'No adapter for this ecosystem';
                    final res = await adapter.healthCheck(source.id);
                    return res.isOk
                        ? 'Healthy — started in ${res.valueOrNull!.inMilliseconds} ms'
                        : (res.errorOrNull ?? 'Unhealthy');
                  }),
                ),
                ListTile(
                  title: const Text('Remove'),
                  subtitle: const Text(
                      'Deletes the provider, its cached code and its settings.'),
                  trailing: const Icon(Icons.delete_outline_rounded),
                  iconColor: AeroColors.warning,
                  enabled: !_busy,
                  onTap: () => _confirmRemove(source),
                ),
                if (_configEntries(source).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(label: 'Provider configuration'),
                  for (final e in _configEntries(source).entries)
                    ListTile(
                      dense: true,
                      title: Text(e.key),
                      subtitle: Text(e.value.toString()),
                    ),
                ],
                const SizedBox(height: 12),
                _SectionLabel(label: 'About'),
                ListTile(
                  dense: true,
                  title: const Text('Ecosystem'),
                  subtitle: Text(source.ecosystem.displayName),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Version'),
                  subtitle: Text(source.version),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Source'),
                  subtitle: Text(source.url, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                if (source.sha256 != null)
                  ListTile(
                    dense: true,
                    title: const Text('Pinned checksum'),
                    subtitle: Text(source.sha256!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
    );
  }

  Map<String, Object?> _configEntries(InstalledSource s) {
    // Internal plumbing is not user-facing configuration.
    const hidden = {'value', 'id', 'display_name', 'packageName', 'name'};
    return {
      for (final e in s.config.entries)
        if (!hidden.contains(e.key)) e.key: e.value,
    };
  }

  void _invalidateAll() {
    ref.invalidate(installedSourcesProvider);
    ref.invalidate(browsableSourcesProvider);
    ref.invalidate(homeRowsProvider);
  }

  Future<void> _confirmRemove(InstalledSource source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${source.name}?'),
        content: const Text(
            'Its cached code and settings are deleted. You can add it again '
            'from Providers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final registry = ref.read(adapterRegistryProvider);
      final adapter = registry.forEcosystem(source.ecosystem);
      if (adapter == null) return 'No adapter for this ecosystem';
      await adapter.uninstall(source.id);
      // Drop the selection if the provider being browsed just disappeared.
      if (ref.read(browseSelectionProvider) == source.key) {
        ref.read(browseSelectionProvider.notifier).state = null;
      }
      _invalidateAll();
      if (mounted) Navigator.of(context).maybePop();
      return 'Removed';
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.source});

  final InstalledSource source;

  @override
  Widget build(BuildContext context) {
    final tint = Color(source.ecosystem.colorSeed);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: tint.withValues(alpha: 0.18),
            backgroundImage: source.logo == null ? null : NetworkImage(source.logo!),
            child: source.logo == null
                ? Icon(Icons.extension_rounded, color: tint)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${source.ecosystem.displayName} · v${source.version}'
                  '${source.enabled ? '' : ' · disabled'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AeroColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AeroColors.textTertiary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
