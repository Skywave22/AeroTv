import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../routing/app_router.dart';
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

  /// Whether this ecosystem is normally distributed as a repository of many
  /// plugins rather than one URL at a time.
  bool get _repoFirst =>
      ref.read(adapterRegistryProvider).forEcosystem(_selected)
          is RepositorySource;

  String get _repoHint => switch (_selected) {
        Ecosystem.skystream => 'https://example.com/repo.json',
        Ecosystem.vega => 'https://example.com/manifest.json',
        Ecosystem.nuvio => 'https://example.com/manifest.json',
        _ => 'https://example.com/manifest.json',
      };

  /// Shortcodes exist only where the upstream contract defines them; offering
  /// the field elsewhere would resolve to a stranger's link.
  bool get _acceptsCode => ShortcodeResolver.supportsShortcodes(_selected);

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
                    _repoFirst
                        ? (_acceptsCode
                            ? 'Paste the repository index, or enter its '
                                'shortcode. You will be able to pick which '
                                'plugins to install.'
                            : 'Paste the repository index. You will be able to '
                                'pick which plugins to install.')
                        // Single-URL ecosystems (Stremio add-ons) are added by
                        // their manifest, not by a repository index.
                        : _emptyHint(_selected),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: _repoFirst && _acceptsCode
                          ? 'Repository URL or shortcode'
                          : _repoFirst
                              ? 'Repository URL'
                              : 'Manifest URL',
                      hintText: _repoFirst ? _repoHint : _emptyHint(_selected),
                      errorText: error,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (_acceptsCode && _repoFirst
                            ? 'Enter a URL or code'
                            : 'Enter a URL')
                        : null,
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
                      final url = controller.text.trim();
                      final adapter = ref
                          .read(adapterRegistryProvider)
                          .forEcosystem(_selected);
                      if (adapter == null) return;

                      if (adapter is RepositorySource) {
                        // A shortcode is an untrusted redirect and the repo it
                        // points at is code we will run, so resolve and guard
                        // before anything is fetched.
                        final String repoUrl;
                        String? shortLink;
                        try {
                          final resolved = await ref
                              .read(repoLinkServiceProvider)
                              .resolve(url, ecosystem: _selected);
                          repoUrl = resolved.url;
                          shortLink = resolved.shortLink;
                        } on ShortcodeException catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            busy = false;
                            error = e.message;
                          });
                          return;
                        }
                        final res = await (adapter as RepositorySource)
                            .fetchRepository(repoUrl);
                        if (!dialogContext.mounted) return;
                        if (res.isErr) {
                          setDialogState(() {
                            busy = false;
                            error = res.errorOrNull;
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        if (mounted) {
                          await _showRepoPicker(
                            this.context,
                            res.valueOrNull!,
                            repoUrl,
                            shortLink: shortLink,
                          );
                        }
                        return;
                      }

                      if (_repoFirst) {
                        // Repository ecosystems are installed through their
                        // index only: a bare plugin URL skips the repository
                        // entry, its manifest fields and its checksum pin.
                        setDialogState(() {
                          busy = false;
                          error = 'Add the repository this plugin comes from, '
                              'then install it from the list.';
                        });
                        return;
                      }

                      final res = await adapter.install(SourceRef(
                        ecosystem: _selected,
                        url: url,
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
              child: Text(_repoFirst ? 'Browse' : 'Install'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  /// Identity of a repository entry.
  ///
  /// URL alone is not enough: every Vega provider in a repository shares the
  /// repository's source URL and is distinguished by `extra['value']`. Using
  /// the URL only would mark the whole repository "already installed" after
  /// installing a single provider.
  static String _refKey(SourceRef r) =>
      '${r.url}|${r.extra['value'] ?? r.extra['id'] ?? r.name ?? ''}';

  static String _installedKey(InstalledSource s) =>
      '${s.url}|${s.config['value'] ?? s.config['id'] ?? s.name}';

  /// Repository browser: list every plugin the index offers and let the user
  /// install a subset. This mirrors how SkyStream and Vega distribute plugins.
  Future<void> _showRepoPicker(
    BuildContext context,
    List<SourceRef> refs,
    String repoUrl, {
    String? shortLink,
  }) async {
    final installed =
        ref.read(installedSourcesProvider).valueOrNull ?? const [];
    final installedKeys = installed.map(_installedKey).toSet();

    // Pre-select everything not already installed.
    final selected = <int>{
      for (var i = 0; i < refs.length; i++)
        if (!installedKeys.contains(_refKey(refs[i]))) i,
    };
    var busy = false;
    var done = 0;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text('${refs.length} plugins found'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show which address a code actually resolved to, so the
                  // user can see what they are about to install from.
                  Text(
                    UrlRedactor.redact(repoUrl),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AeroColors.textTertiary),
                  ),
                  if (shortLink != null)
                    Text(
                      'via $shortLink',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AeroColors.textTertiary),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setDialogState(() {
                                  selected
                                    ..clear()
                                    ..addAll(
                                      List.generate(refs.length, (i) => i),
                                    );
                                }),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setDialogState(selected.clear),
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      Text(
                        '${selected.length} selected',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: refs.length,
                      itemBuilder: (_, i) {
                        final r = refs[i];
                        final already = installedKeys.contains(_refKey(r));
                        return CheckboxListTile(
                          value: selected.contains(i),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: busy
                              ? null
                              : (v) => setDialogState(() {
                                    if (v ?? false) {
                                      selected.add(i);
                                    } else {
                                      selected.remove(i);
                                    }
                                  }),
                          title: Text(
                            r.name ?? r.url.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (r.version != null) 'v${r.version}',
                              if (already) 'already installed',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      minHeight: 2,
                      value: selected.isEmpty
                          ? null
                          : done / selected.length.clamp(1, 1 << 30),
                    ),
                    const SizedBox(height: 6),
                    Text('Installing $done of ${selected.length}…',
                        style: theme.textTheme.bodySmall),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy || selected.isEmpty
                    ? null
                    : () async {
                        setDialogState(() {
                          busy = true;
                          error = null;
                          done = 0;
                        });
                        final adapter = ref
                            .read(adapterRegistryProvider)
                            .forEcosystem(_selected);
                        final failures = <String>[];
                        // Sequential: each install downloads and boots code,
                        // and this box has very little memory.
                        for (final i in selected.toList()..sort()) {
                          final res = await adapter!.install(
                            SourceRef(
                              ecosystem: _selected,
                              url: refs[i].url,
                              repoId: repoUrl,
                              name: refs[i].name,
                              version: refs[i].version,
                              expectedSha256: refs[i].expectedSha256,
                              extra: refs[i].extra,
                            ),
                          );
                          if (res.isErr) {
                            failures.add(
                              '${refs[i].name ?? refs[i].url}: '
                              '${res.errorOrNull}',
                            );
                          }
                          if (!dialogContext.mounted) return;
                          setDialogState(() => done++);
                        }
                        ref.invalidate(installedSourcesProvider);
                        ref.invalidate(homeRowsProvider);
                        if (!dialogContext.mounted) return;
                        if (failures.isEmpty) {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Installed ${selected.length} plugins',
                                ),
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            busy = false;
                            error = failures.join('\n');
                          });
                        }
                      },
                child: Text('Install ${selected.length}'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Add-from-phone: run a short-lived LAN server, show a QR, and let the phone
  /// post the add-on URL back. Typing a manifest URL with a remote is painful,
  /// so this is the primary path on TV.
  ///
  /// The server is single-use and token-gated, and is always shut down when the
  /// dialog closes — whether by success, cancellation or timeout.
  Future<void> _showQrFlow(BuildContext context) async {
    PairingSession? session;
    String? startError;
    try {
      session = await PairingServer.start();
    } catch (e) {
      startError = '$e';
    }
    if (!mounted) {
      await session?.close();
      return;
    }

    final pairing = session;
    StreamSubscription<String>? sub;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // Hand the URL to the normal install path so validation, the
        // configurationRequired check and the confirm dialog all still apply.
        sub ??= pairing?.submissions.listen((url) async {
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          if (!mounted) return;
          final adapter =
              ref.read(adapterRegistryProvider).forEcosystem(_selected);
          if (adapter == null) return;
          final res = await adapter.install(SourceRef(
            ecosystem: _selected,
            url: url,
          ));
          if (!mounted) return;
          ref.invalidate(installedSourcesProvider);
          ref.invalidate(homeRowsProvider);
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(res.isOk
                  ? 'Installed ${res.valueOrNull!.name}'
                  : 'Could not install: ${res.errorOrNull}'),
            ),
          );
        });

        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Add from your phone'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (startError != null)
                  Text(
                    'Could not start pairing.\n$startError',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else ...[
                  const Text(
                    'Scan this with your phone, paste the add-on URL there, and '
                    'it will appear here for confirmation.',
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
                      data: pairing!.url,
                      size: 190,
                      version: QrVersions.auto,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    pairing.url.split('?').first,
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Both devices must be on the same Wi-Fi network. The link '
                    'works once and expires after 5 minutes. Aero TV provides '
                    'no content and no sources.',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showAddDialog(this.context);
              },
              child: const Text('Type it instead'),
            ),
          ],
        );
      },
    );

    await sub?.cancel();
    await pairing?.close();
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
                    PopupMenuItem(value: 'diagnose', child: Text('Diagnostics')),
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
      case 'diagnose':
        unawaited(context.push('${Routes.settings}/diagnostics', extra: s));
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
        // Copy the real URL (the user needs it to work), but never render or
        // log it unredacted — add-on URLs often embed a personal token.
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
