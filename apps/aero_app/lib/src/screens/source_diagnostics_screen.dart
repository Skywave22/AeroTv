import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Everything needed to answer "why is this plugin not working?".
///
/// Three views over one source: a live capability test, the network hosts it
/// has actually contacted, and its persisted log. The log survives a restart,
/// which is the whole point — a plugin that crashes the player is useless to
/// debug from a ring buffer that was cleared on the way back up.
class SourceDiagnosticsScreen extends ConsumerStatefulWidget {
  const SourceDiagnosticsScreen({
    super.key,
    this.source,
    this.sourceId,
    this.ecosystemId,
  });

  final InstalledSource? source;
  final String? sourceId;
  final String? ecosystemId;

  @override
  ConsumerState<SourceDiagnosticsScreen> createState() =>
      _SourceDiagnosticsScreenState();
}

class _SourceDiagnosticsScreenState
    extends ConsumerState<SourceDiagnosticsScreen> {
  DiagnosticReport? _report;
  bool _running = false;
  final _testId = TextEditingController();
  MediaType _testType = MediaType.movie;
  final _season = TextEditingController();
  final _episode = TextEditingController();
  List<PluginLogRow> _logs = const [];
  List<String> _hosts = const [];
  InstalledSource? _resolved;

  @override
  void dispose() {
    _testId.dispose();
    _season.dispose();
    _episode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _resolved = widget.source;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  InstalledSource? get _source => _resolved ?? widget.source;

  String get _sourceKey {
    final s = _source;
    if (s != null) return '${s.ecosystem.name}:${s.id}';
    return '${widget.ecosystemId ?? "unknown"}:${widget.sourceId ?? ""}';
  }

  Future<void> _load() async {
    var s = _source;
    if (s == null && widget.sourceId != null) {
      final all = await ref.read(installedSourcesProvider.future);
      s = all
          .where((e) =>
              e.id == widget.sourceId &&
              (widget.ecosystemId == null ||
                  e.ecosystem.name == widget.ecosystemId))
          .firstOrNull;
      if (mounted && s != null) setState(() => _resolved = s);
    }
    if (s == null) return;

    final repo = ref.read(pluginLogRepoProvider);
    final key = '${s.ecosystem.name}:${s.id}';
    final logs = await repo.forSource(key, limit: 150);
    final hosts = await repo.hostsFor(key);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _hosts = hosts;
    });
  }

  Future<void> _runTest() async {
    final s = _source;
    if (s == null || _running) return;
    final adapter = ref.read(adapterRegistryProvider).forEcosystem(s.ecosystem);
    if (adapter == null) return;

    setState(() => _running = true);
    final logs = ref.read(pluginLogRepoProvider);
    final breaker = ref.read(circuitBreakerProvider);
    final key = '${s.ecosystem.name}:${s.id}';

    // Subscribe for the duration of the run so the test itself is recorded.
    // Persistence must not block the log listener, so the write is fire-and-
    // forget; the repository is a local SQLite insert.
    final tag = s.id;
    final stop = AeroLog.instance.listen((e) {
      if (e.tag.contains(tag)) unawaited(logs.record(key, e));
    });

    final report =
        await AdapterDiagnostics.run(adapter, s).whenComplete(stop);

    await logs.append(
      key,
      report.ok ? LogLevel.info : LogLevel.error,
      'diagnostics',
      report.summary,
    );
    if (report.ok) {
      breaker.onOk(key);
    } else if (report.failKind != null) {
      breaker.onFail(key, report.failKind!);
    }

    if (!mounted) return;
    setState(() {
      _report = report;
      _running = false;
    });
    await _load();
  }

  /// The stream-only path: there is no catalogue to find a title in, so the
  /// user supplies one. This is the only way to verify a Nuvio scraper.
  Future<void> _runStreamTest() async {
    final s = _source;
    final id = _testId.text.trim();
    if (s == null || _running || id.isEmpty) return;
    final adapter = ref.read(adapterRegistryProvider).forEcosystem(s.ecosystem);
    if (adapter == null) return;

    setState(() => _running = true);
    final report = await AdapterDiagnostics.testStreams(
      adapter,
      s,
      id: id,
      type: _testType,
      season: int.tryParse(_season.text.trim()),
      episode: int.tryParse(_episode.text.trim()),
    );
    final logs = ref.read(pluginLogRepoProvider);
    await logs.append(
      '${s.ecosystem.id}:${s.id}',
      report.ok ? LogLevel.info : LogLevel.error,
      'diagnostics',
      'Stream test ($id): ${report.summary}',
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _running = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _source;
    final breaker = ref.watch(circuitBreakerProvider);
    final title = s?.name ?? widget.sourceId ?? 'Source';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Diagnostics — $title'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Test'),
              Tab(text: 'Network'),
              Tab(text: 'Log'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: 'Copy report',
              onPressed: _copyReport,
            ),
          ],
        ),
        body: s == null
            ? const EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'Source not found',
                message: 'It may have been removed. Go back and pick another.',
              )
            : TabBarView(
                children: [
                  _testTab(s, breaker),
                  _networkTab(),
                  _logTab(),
                ],
              ),
      ),
    );
  }

  Widget _testTab(InstalledSource s, CircuitBreaker breaker) {
    final key = '${s.ecosystem.name}:${s.id}';
    final report = _report;
    final streamsOnly =
        !s.can(Capability.catalogs) && !s.can(Capability.search);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (streamsOnly) ...[
          _streamTestCard(s),
          const SizedBox(height: 16),
        ],
        TvFocus(
          onSelect: _runTest,
          enabled: !_running,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AeroColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _running ? 'Testing…' : 'Run test',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AeroColors.textPrimary),
                  ),
                ),
                if (_running)
                  const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _healthTile(breaker, key),
        const SizedBox(height: 16),
        if (report == null)
          const EmptyState(
            icon: Icons.science_outlined,
            title: 'No test run yet',
            message: 'Run test checks reachability, catalogues, search and '
                'streams in order, and shows exactly which step broke.',
            compact: true,
          )
        else ...[
          SectionHeader(title: 'Result', subtitle: report.summary),
          ...report.steps.map(_stepTile),
        ],
      ],
    );
  }

  Widget _streamTestCard(InstalledSource s) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AeroColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Test with a known title',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${s.name} only supplies streams, so there is nothing to browse '
            'for a title. Enter an IMDb id (tt1160419) or a TMDB id (438631).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AeroColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testId,
            decoration: const InputDecoration(
              labelText: 'IMDb or TMDB id',
              hintText: 'tt1160419',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MediaType>(
                  initialValue: _testType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: MediaType.movie, child: Text('Movie')),
                    DropdownMenuItem(
                        value: MediaType.series, child: Text('Series')),
                  ],
                  onChanged: _running
                      ? null
                      : (v) => setState(() => _testType = v ?? MediaType.movie),
                ),
              ),
              if (_testType == MediaType.series) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _season,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'S'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _episode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'E'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _running ? null : _runStreamTest,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(_running ? 'Testing…' : 'Test streams'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthTile(CircuitBreaker breaker, String key) {
    final open = !breaker.allows(key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (open ? AeroColors.warning : AeroColors.success).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(open ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
              size: 18, color: open ? AeroColors.warning : AeroColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              breaker.describe(key),
              style: const TextStyle(fontSize: 12, color: AeroColors.textSecondary),
            ),
          ),
          if (open)
            TextButton(
              onPressed: () => setState(() => breaker.reset(key)),
              child: const Text('Retry now'),
            ),
        ],
      ),
    );
  }

  Widget _stepTile(DiagnosticStep step) {
    final color = switch (step.status) {
      DiagnosticStatus.pass => AeroColors.success,
      DiagnosticStatus.warn => AeroColors.warning,
      DiagnosticStatus.fail => AeroColors.danger,
      DiagnosticStatus.skipped => AeroColors.textTertiary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(step.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AeroColors.textPrimary)),
                if (step.detail != null || step.count != null)
                  Text(
                    [
                      if (step.count != null) '${step.count} items',
                      if (step.detail != null) step.detail!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: AeroColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text('${step.elapsed.inMilliseconds} ms',
              style: const TextStyle(fontSize: 10, color: AeroColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _networkTab() {
    if (_hosts.isEmpty) {
      return const EmptyState(
        icon: Icons.lan_outlined,
        title: 'No network activity recorded',
        message: 'Run a test or play something. Every host this plugin '
            'contacts is listed here, so you can see where your requests go.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(
          title: 'Hosts contacted',
          subtitle: 'Credentials are removed. Newest first.',
        ),
        ..._hosts.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.dns_outlined, size: 16, color: AeroColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(h,
                        style: const TextStyle(fontSize: 12, color: AeroColors.textPrimary)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _logTab() {
    if (_logs.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No log entries',
        message: 'Entries for this plugin are kept across restarts and '
            'removed when you uninstall it.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final r = _logs[i];
        final color = switch (r.level) {
          'error' => AeroColors.danger,
          'warn' => AeroColors.warning,
          'info' => AeroColors.info,
          _ => AeroColors.textTertiary,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.level.toUpperCase(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(width: 6),
                  Text(r.tag,
                      style: const TextStyle(fontSize: 11, color: AeroColors.textSecondary)),
                  const Spacer(),
                  Text(r.at.toIso8601String().substring(11, 19),
                      style: const TextStyle(fontSize: 10, color: AeroColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 3),
              SelectableText(r.message,
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: AeroColors.textPrimary)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyReport() async {
    final logs = ref.read(pluginLogRepoProvider);
    final buffer = StringBuffer()
      ..writeln(_report?.toText() ?? 'No test run yet for $_sourceKey')
      ..writeln('\nHosts contacted: ${_hosts.isEmpty ? "none" : _hosts.join(", ")}')
      ..writeln('\n--- Log ---\n')
      ..writeln(await logs.dump(_sourceKey));
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied')),
      );
    }
  }
}
