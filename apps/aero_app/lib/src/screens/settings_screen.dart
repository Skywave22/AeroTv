import 'dart:async';
import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerSettingsProvider);
    final ui = ref.watch(uiSettingsProvider);
    final ranking = ref.watch(rankingRulesProvider);
    final isTv = ref.watch(isTvProvider);
    final enabled = ref.watch(enabledSourceCountProvider);
    final settingsRepo = ref.watch(settingsRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // The Extensions Manager no longer lives in Settings: installing and
          // configuring a provider belongs to that provider's own page (open
          // it from Browse or Providers), the way SkyStream does it.
          SectionHeader(
            title: 'Sources',
            subtitle: enabled == 0
                ? 'No sources enabled yet'
                : '$enabled source(s) enabled',
          ),
          _tile(
            context,
            icon: Icons.extension_rounded,
            title: 'Manage providers',
            subtitle: 'Installed providers, per-ecosystem settings and updates',
            onTap: () => context.go(Routes.providers),
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'Playback'),
          SwitchListTile(
            title: const Text('Resume where I left off'),
            subtitle: const Text('Continue from your last position'),
            value: player.resumePlayback,
            onChanged: (v) => _setPlayer(ref, player.copyWith(resumePlayback: v)),
          ),
          SwitchListTile(
            title: const Text('Hardware decoding'),
            subtitle: const Text('Turn off if you see green frames or crashes'),
            value: player.hardwareDecoding,
            onChanged: (v) => _setPlayer(ref, player.copyWith(hardwareDecoding: v)),
          ),
          SwitchListTile(
            title: const Text('Subtitles by default'),
            value: player.subtitlesEnabledByDefault,
            onChanged: (v) =>
                _setPlayer(ref, player.copyWith(subtitlesEnabledByDefault: v)),
          ),
          _tile(
            context,
            icon: Icons.closed_caption_rounded,
            title: 'Subtitle language',
            subtitle: player.defaultSubtitleLang.toUpperCase(),
            onTap: () => _pickLanguage(
              context,
              title: 'Subtitle language',
              current: player.defaultSubtitleLang,
              onPick: (v) => _setPlayer(ref, player.copyWith(defaultSubtitleLang: v)),
            ),
          ),
          _tile(
            context,
            icon: Icons.audiotrack_rounded,
            title: 'Audio language',
            subtitle: player.preferredAudioLang.toUpperCase(),
            onTap: () => _pickLanguage(
              context,
              title: 'Preferred audio language',
              current: player.preferredAudioLang,
              onPick: (v) => _setPlayer(ref, player.copyWith(preferredAudioLang: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields_rounded),
            title: const Text('Subtitle size'),
            subtitle: Slider(
              value: player.subtitleSize,
              min: 0.6,
              max: 2.0,
              divisions: 14,
              label: '${player.subtitleSize.toStringAsFixed(1)}x',
              onChanged: (v) => _setPlayer(
                ref,
                player.copyWith(subtitleSize: double.parse(v.toStringAsFixed(2))),
              ),
            ),
            trailing: Text('${player.subtitleSize.toStringAsFixed(1)}x'),
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(
            title: 'Auto-play & ranking',
            subtitle: 'How Aero TV picks the best stream for you',
          ),
          SwitchListTile(
            title: const Text('Auto-play best source'),
            subtitle: const Text('Skip the picker when a good match is found'),
            value: ranking.autoPlayEnabled,
            onChanged: (v) => _setRanking(ref, ranking.copyWith(autoPlayEnabled: v)),
          ),
          _tile(
            context,
            icon: Icons.high_quality_rounded,
            title: 'Preferred quality',
            subtitle: ranking.preferredQuality.label,
            onTap: () => _pickQuality(context, ref, ranking),
          ),
          SwitchListTile(
            title: const Text('Allow higher than preferred'),
            subtitle: const Text('e.g. pick 4K when 1080p is unavailable'),
            value: ranking.allowHigherThanPreferred,
            onChanged: (v) =>
                _setRanking(ref, ranking.copyWith(allowHigherThanPreferred: v)),
          ),
          _tile(
            context,
            icon: Icons.sd_storage_rounded,
            title: 'Maximum file size',
            subtitle: ranking.maxSizeBytes == null
                ? 'No limit'
                : '${(ranking.maxSizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
            onTap: () => _pickMaxSize(context, ref, ranking),
          ),
          SwitchListTile(
            title: const Text('Prefer HDR'),
            subtitle: const Text('Only if your display supports it'),
            value: ranking.preferHdr,
            onChanged: (v) => _setRanking(ref, ranking.copyWith(preferHdr: v)),
          ),
          _tile(
            context,
            icon: Icons.sort_rounded,
            title: 'Ecosystem priority',
            subtitle: ranking.ecosystemOrder.map((e) => e.displayName).join(' → '),
            onTap: () => _reorderEcosystems(context, ref, ranking),
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Tint pages from artwork'),
            subtitle: const Text('Extract a colour from the poster/backdrop'),
            value: ui.dynamicColorFromArtwork,
            onChanged: (v) => _setUi(ref, ui.copyWith(dynamicColorFromArtwork: v)),
          ),
          SwitchListTile(
            title: const Text('Show source badges'),
            value: ui.showEcosystemBadges,
            onChanged: (v) => _setUi(ref, ui.copyWith(showEcosystemBadges: v)),
          ),
          SwitchListTile(
            title: const Text('Blur effects'),
            subtitle: const Text('Disable on low-end TV boxes for smoother UI'),
            value: ui.enableBlur,
            onChanged: (v) => _setUi(ref, ui.copyWith(enableBlur: v)),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            value: ui.reduceMotion,
            onChanged: (v) => _setUi(ref, ui.copyWith(reduceMotion: v)),
          ),
          if (isTv)
            ListTile(
              leading: const Icon(Icons.crop_free_rounded),
              title: const Text('TV overscan margin'),
              subtitle: Slider(
                value: ui.tvOverscanPercent,
                min: 0,
                max: 8,
                divisions: 16,
                label: '${ui.tvOverscanPercent.toStringAsFixed(1)}%',
                onChanged: (v) => _setUi(
                  ref,
                  ui.copyWith(tvOverscanPercent: double.parse(v.toStringAsFixed(1))),
                ),
              ),
              trailing: Text('${ui.tvOverscanPercent.toStringAsFixed(1)}%'),
            ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'Metadata'),
          _tile(
            context,
            icon: Icons.key_rounded,
            title: 'TMDB API key',
            subtitle: settingsRepo.tmdbApiKey.isEmpty
                ? 'Not set — no Home trending rows, ID mapping falls back to IMDb/title'
                : 'Configured — powers Home rows and ID mapping',
            onTap: () => _editTmdbKey(context, ref),
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'Backup & data'),
          _tile(
            context,
            icon: Icons.upload_file_rounded,
            title: 'Export configuration',
            subtitle: 'Sources, settings and library. Never credentials.',
            onTap: () => _export(context, ref),
          ),
          _tile(
            context,
            icon: Icons.download_rounded,
            title: 'Restore from backup',
            onTap: () => _restore(context, ref),
          ),
          _tile(
            context,
            icon: Icons.cleaning_services_rounded,
            title: 'Clear cache',
            subtitle: 'Frees space; your sources and library are kept',
            onTap: () async {
              await ref.read(cacheRepoProvider).clear();
              ref.invalidate(homeRowsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              }
            },
          ),
          _tile(
            context,
            icon: Icons.delete_sweep_rounded,
            title: 'Clear watch history',
            onTap: () async {
              final ok = await _confirm(
                context,
                'Clear watch history?',
                'This removes all resume points. Your library is not affected.',
              );
              if (ok) {
                await ref.read(historyRepoProvider).clear();
                ref.invalidate(continueWatchingProvider);
              }
            },
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'Privacy & diagnostics'),
          SwitchListTile(
            title: const Text('Anonymous crash reports'),
            subtitle: const Text('Off by default. No content or URLs are sent.'),
            value: settingsRepo.telemetryOptIn,
            onChanged: (v) async {
              await settingsRepo.setTelemetryOptIn(v);
              ref.invalidate(settingsRepoProvider);
            },
          ),
          _tile(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Log viewer',
            subtitle: 'See exactly where plugins are making requests',
            onTap: () => context.push('${Routes.settings}/logs'),
          ),
          const Divider(indent: 20, endIndent: 20),

          const SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Aero TV'),
            subtitle: Text('Version 0.1.0 · Phase 1 (Stremio MVP)'),
          ),
          _tile(
            context,
            icon: Icons.description_outlined,
            title: 'Open-source licences',
            subtitle: 'Flutter, media_kit and the packages this app builds on',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Aero TV',
              applicationVersion: '0.1.0',
              applicationLegalese:
                  'A neutral media player and plugin host.\n'
                  'No content, no add-ons and no repositories are included.',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              'Aero TV is a neutral media player and plugin host. It ships with '
              'no content, no add-ons and no repositories. You are responsible '
              'for the sources you add and for having the right to access the '
              'content you play.',
              style: TextStyle(color: AeroColors.textTertiary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );

  /// Applies a setting immediately in memory and persists it in the
  /// background. A failed write is logged rather than swallowed: the UI keeps
  /// the new value either way, so a silent failure would look like it saved.
  void _persist(WidgetRef ref, Future<void> write) {
    unawaited(write.catchError((Object e) {
      AeroLog.instance.e('settings', 'Could not save setting: $e');
    }));
  }

  void _setPlayer(WidgetRef ref, PlayerSettings s) {
    ref.read(playerSettingsProvider.notifier).state = s;
    _persist(ref, ref.read(settingsRepoProvider).setPlayer(s));
  }

  void _setUi(WidgetRef ref, UiSettings s) {
    ref.read(uiSettingsProvider.notifier).state = s;
    _persist(ref, ref.read(settingsRepoProvider).setUi(s));
  }

  void _setRanking(WidgetRef ref, RankingRules r) {
    ref.read(rankingRulesProvider.notifier).state = r;
    _persist(ref, ref.read(settingsRepoProvider).setRanking(r));
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _pickLanguage(
    BuildContext context, {
    required String title,
    required String current,
    required void Function(String) onPick,
  }) async {
    const langs = {
      'en': 'English', 'hi': 'Hindi', 'ur': 'Urdu', 'es': 'Spanish',
      'fr': 'French', 'de': 'German', 'it': 'Italian', 'pt': 'Portuguese',
      'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean', 'zh': 'Chinese',
      'ar': 'Arabic', 'tr': 'Turkish', 'ta': 'Tamil', 'te': 'Telugu',
      'ml': 'Malayalam', 'bn': 'Bengali', 'pa': 'Punjabi',
    };
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...langs.entries.map((e) => RadioListTile<String>(
                  value: e.key,
                  // ignore: deprecated_member_use
                  groupValue: current,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) onPick(v);
                    Navigator.of(context).pop();
                  },
                  title: Text(e.value),
                  subtitle: Text(e.key.toUpperCase()),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _pickQuality(
      BuildContext context, WidgetRef ref, RankingRules ranking) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Preferred quality',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...Quality.values.where((q) => q != Quality.unknown).map(
              (q) => RadioListTile<Quality>(
                value: q,
                // ignore: deprecated_member_use
                groupValue: ranking.preferredQuality,
                // ignore: deprecated_member_use
                onChanged: (v) {
                  if (v != null) _setRanking(ref, ranking.copyWith(preferredQuality: v));
                  Navigator.of(context).pop();
                },
                title: Text(q.label),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMaxSize(
      BuildContext context, WidgetRef ref, RankingRules ranking) async {
    final options = <int?>[null, 2, 4, 8, 15, 30];
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Maximum file size',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...options.map((gb) {
              final bytes = gb == null ? null : gb * 1024 * 1024 * 1024;
              return ListTile(
                title: Text(gb == null ? 'No limit' : '$gb GB'),
                trailing: ranking.maxSizeBytes == bytes
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  _setRanking(
                    ref,
                    gb == null
                        ? ranking.copyWith(clearMaxSize: true)
                        : ranking.copyWith(maxSizeBytes: bytes),
                  );
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _reorderEcosystems(
      BuildContext context, WidgetRef ref, RankingRules ranking) async {
    final order = [...ranking.ecosystemOrder];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SizedBox(
            height: 460,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Ecosystem priority',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Drag to reorder. Higher up wins when quality is equal.',
                    style: TextStyle(color: AeroColors.textSecondary, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorderItem: (oldIndex, newIndex) {
                      setSheetState(() {
                        final moved = order.removeAt(oldIndex);
                        order.insert(newIndex, moved);
                      });
                    },
                    children: [
                      for (final e in order)
                        ListTile(
                          key: ValueKey(e.id),
                          leading: EcosystemBadge(ecosystem: e),
                          title: Text(e.displayName),
                          trailing: ReorderableDragStartListener(
                            index: order.indexOf(e),
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () {
                      _setRanking(ref, ranking.copyWith(ecosystemOrder: order));
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Save order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editTmdbKey(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(settingsRepoProvider);
    final controller = TextEditingController(text: repo.tmdbApiKey);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('TMDB API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional, but recommended. Fills Home with trending and popular '
              'rows, and maps IMDb ↔ TMDB IDs so more sources can find the same '
              'title. This is how Nuvio-style scrapers get their metadata — they '
              'only supply streams.\n\n'
              'Get a free key from themoviedb.org. Aero TV ships with no key.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'API key (v3)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await repo.setTmdbApiKey(controller.text.trim());
              ref.invalidate(metadataResolverProvider);
              ref.invalidate(settingsRepoProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(backupServiceProvider).export();
      await SharePlus.instance.share(
        ShareParams(
          text: json,
          subject: 'Aero TV backup',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!context.mounted) return;
      final replace = await _confirm(
        context,
        'Replace existing sources?',
        'Confirm to replace your current sources with the backup. '
        'Cancel to merge them instead.',
      );
      final summary =
          await ref.read(backupServiceProvider).import(text, replace: replace);
      ref.invalidate(installedSourcesProvider);
      ref.invalidate(homeRowsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(summary)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}
