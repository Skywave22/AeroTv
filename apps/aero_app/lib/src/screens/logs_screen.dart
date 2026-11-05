import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Shows exactly what the app and plugins are doing, including every network
/// destination. This is the transparency requirement for untrusted code.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  LogLevel? _filter;
  bool _verbose = AeroLog.instance.verbose;

  @override
  Widget build(BuildContext context) {
    // Rebuild when new entries arrive.
    ref.watch(logStreamProvider);
    final entries = AeroLog.instance.entries.reversed
        .where((e) => _filter == null || e.level == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy all',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: AeroLog.instance.dump()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear',
            onPressed: () => setState(AeroLog.instance.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('All', _filter == null,
                            () => setState(() => _filter = null)),
                        ...LogLevel.values.map((l) => _chip(
                              l.name,
                              _filter == l,
                              () => setState(() => _filter = l),
                            )),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text('Verbose', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _verbose,
                      onChanged: (v) => setState(() {
                        _verbose = v;
                        AeroLog.instance.verbose = v;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No log entries',
                    message:
                        'Activity will appear here. Enable Verbose to see every '
                        'network request made by plugins.',
                    compact: true,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final color = switch (e.level) {
                        LogLevel.error => AeroColors.danger,
                        LogLevel.warn => AeroColors.warning,
                        LogLevel.info => AeroColors.info,
                        LogLevel.debug => AeroColors.textTertiary,
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    e.level.name.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: color),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  e.tag,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AeroColors.textSecondary),
                                ),
                                const Spacer(),
                                Text(
                                  e.at.toIso8601String().substring(11, 19),
                                  style: const TextStyle(
                                      fontSize: 10, color: AeroColors.textTertiary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            SelectableText(
                              e.message,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AeroColors.textPrimary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
