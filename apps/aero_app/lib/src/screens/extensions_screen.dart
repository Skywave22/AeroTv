import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/providers.dart';

/// Extensions Manager: one section per ecosystem, each with its own manager.
class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({this.initialEcosystem, super.key});

  final Ecosystem? initialEcosystem;

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen> {
  late Ecosystem _selected = widget.initialEcosystem ?? Ecosystem.stremio;

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(adapterRegistryProvider);
    final adapter = registry.forEcosystem(_selected);
    final available = adapter?.isAvailable ?? false;
    final sourcesAsync = ref.watch(sourcesByEcosystemProvider(_selected));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(installedSourcesProvider);
              ref.invalidate(homeRowsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: Ecosystem.values.map((eco) {
                final a = registry.forEcosystem(eco);
                final enabled = a?.isAvailable ?? false;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _selected == eco,
                    onSelected: (_) => setState(() => _selected = eco),
                    avatar: enabled
                        ? null
                        : const Icon(Icons.lock_outline_rounded, size: 14),
                    label: Text(eco.displayName),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!available)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AeroColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AeroColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AeroColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adapter?.unavailableReason ??
                          'This ecosystem is not available on this platform.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: AeroPrimaryButton(
                    label: 'Add ${_selected.sourceNoun}',
                    icon: Icons.add_rounded,
                    onPressed: available ? () => _showAddDialog(context) : null,
                  ),
                ),
                const SizedBox(width: 10),
                AeroSecondaryButton(
                  label: 'QR',
                  icon: Icons.qr_code_rounded,
                  onPressed: available ? () => _showQrFlow(context) : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: sourcesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load',
                message: '$e',
              ),
              data: (sources) {
                if (sources.isEmpty) {
                  return EmptyState(
                    icon: Icons.extension_outlined,
                    title: 'No ${_selected.sourceNoun.toLowerCase()} installed',
                    message: _emptyHint(_selected),
                    actionLabel: available ? 'Add now' : null,
                    onAction: available ? () => _showAddDialog(context) : null,
                    compact: true,
                  );
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: sources.length,
                  // onReorderItem already accounts for the removed item.
                  onReorderItem: (oldIndex, newIndex) async {
                    final list = [...sources];
                    final moved = list.removeAt(oldIndex);
                    list.insert(newIndex, moved);
                    await ref
                        .read(sourceRepoProvider)
                        .reorder(list.map((s) => s.key).toList());
                    ref.invalidate(installedSourcesProvider);
                    ref.invalidate(homeRowsProvider);
                  },
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    return _SourceTile(
                      key: ValueKey(s.key),
                      source: s,
                      index: i,
                      onChanged: () {
                        ref.invalidate(installedSourcesProvider);
                        ref.invalidate(homeRowsProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _emptyHint(Ecosystem eco) => switch (eco) {
        Ecosystem.stremio =>
          'Paste a Stremio add-on manifest URL. It usually ends in '
              '/manifest.json. Aero TV ships with none.',
        Ecosystem.vega =>
          'Add a Vega repository, then install providers from it. '
              'Providers run in a sandboxed JavaScript engine.',
        Ecosystem.nuvio =>
          'Add a Nuvio repository manifest, then install scrapers from it.',
        Ecosystem.skystream =>
          'Add a SkyStream repository, then install plugins from it.',
        Ecosystem.cloudstream =>
          'CloudStream support requires the optional native host and is '
              'Android-only. See docs/specs/cloudstream.md.',
      };

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Add ${_selected.sourceNoun}'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _emptyHint(_selected),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'URL',
                      hintText: _selected == Ecosystem.stremio
                          ? 'https://example.com/manifest.json'
                          : 'https://example.com/repo.json',
                      errorText: error,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a URL' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            controller.text = data!.text!.trim();
                            setDialogState(() {});
                          }
                        },
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: const Text('Paste'),
                      ),
                    ],
                  ),
                  if (busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final adapter =
                          ref.read(adapterRegistryProvider).forEcosystem(_selected);
                      final res = await adapter!.install(SourceRef(
                        ecosystem: _selected,
                        url: controller.text.trim(),
                      ));
                      if (!dialogContext.mounted) return;
                      if (res.isOk) {
                        ref.invalidate(installedSourcesProvider);
                        ref.invalidate(homeRowsProvider);
                        Navigator.of(dialogContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Installed ${res.valueOrNull!.name}'),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          busy = false;
                          error = res.errorOrNull;
                        });
                      }
                    },
              child: const Text('Install'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  /// TV-friendly flow: show a QR so the user can open the add-on URL on a
  /// phone, then paste/confirm it here. Typing long URLs with a remote is
  /// painful, so this is the primary path on TV.
  Future<void> _showQrFlow(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add from your phone'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Typing long URLs with a remote is painful. Scan this code on '
                'your phone to open the Extensions page, then use Paste here.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: 'aerotv://extensions/add?eco=${_selected.id}',
                  size: 190,
                  version: QrVersions.auto,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Aero TV does not run a pairing server. The code simply opens '
                'this screen; your add-on URL is never sent anywhere by us.',
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddDialog(context);
            },
            child: const Text('Paste URL'),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends ConsumerStatefulWidget {
  const _SourceTile({
    required this.source,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final InstalledSource source;
  final int index;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends ConsumerState<_SourceTile> {
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 20, color: AeroColors.textTertiary),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          MetaChip(label: 'v${s.version}'),
                          if (s.capabilities.contains(Capability.streams))
                            const MetaChip(label: 'streams'),
                          if (s.capabilities.contains(Capability.catalogs))
                            const MetaChip(label: 'catalogs'),
                          if (s.adult)
                            const MetaChip(label: '18+', tone: MetaChipTone.danger),
                          if (_status != null)
                            MetaChip(
                              label: _status!,
                              tone: _status!.startsWith('OK')
                                  ? MetaChipTone.success
                                  : MetaChipTone.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: s.enabled,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          await ref
                              .read(sourceRepoProvider)
                              .setEnabled(s.ecosystem, s.id, v);
                          widget.onChanged();
                        },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (v) => _onMenu(v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'health', child: Text('Health check')),
                    PopupMenuItem(value: 'update', child: Text('Check for update')),
                    PopupMenuItem(value: 'copy', child: Text('Copy URL')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(String action) async {
    final adapter =
        ref.read(adapterRegistryProvider).forEcosystem(widget.source.ecosystem);
    if (adapter == null) return;
    final s = widget.source;

    switch (action) {
      case 'health':
        setState(() { _busy = true; _status = null; });
        final res = await adapter.healthCheck(s.id);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = res.when(
            ok: (d) => 'OK ${d.inMilliseconds}ms',
            err: (e) => e.length > 40 ? '${e.substring(0, 40)}…' : e,
          );
        });
      case 'update':
        setState(() { _busy = true; _status = null; });
        final res = await adapter.checkUpdate(s.id);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = res.when(
            ok: (updated) => 'v${updated.version}',
            err: (e) => 'Update failed',
          );
        });
        widget.onChanged();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: s.url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL copied')),
          );
        }
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Remove ${s.name}?'),
            content: const Text(
              'This uninstalls the source and clears its cached data. '
              'You can add it again later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await adapter.uninstall(s.id);
          widget.onChanged();
        }
    }
  }
}
