import 'dart:async';

import '../adapter/adapter_registry.dart';
import '../models/capability.dart';
import '../models/ecosystem.dart';
import '../models/play_request.dart';
import '../models/source.dart';
import '../models/stream_link.dart';
import '../util/aero_log.dart';
import 'ranking_rules.dart';
import 'stream_ranker.dart';

/// Why a source produced nothing, surfaced in the source sheet.
enum SourceStatus { pending, resolving, done, empty, failed, timedOut, skipped }

/// Per-source progress so the sheet can show spinners and error chips.
class SourceProgress {
  const SourceProgress({
    required this.source,
    required this.status,
    this.found = 0,
    this.elapsed,
    this.error,
  });

  final InstalledSource source;
  final SourceStatus status;
  final int found;
  final Duration? elapsed;
  final String? error;

  String get label => switch (status) {
        SourceStatus.pending => 'Queued',
        SourceStatus.resolving => 'Searching…',
        SourceStatus.done => '$found found',
        SourceStatus.empty => 'No results',
        SourceStatus.failed => error ?? 'Failed',
        SourceStatus.timedOut => 'Timed out',
        SourceStatus.skipped => 'Skipped',
      };
}

/// Emitted as resolution proceeds.
sealed class ResolverEvent {
  const ResolverEvent();
}

class ResolverStarted extends ResolverEvent {
  const ResolverStarted(this.sources);
  final List<InstalledSource> sources;
}

class ResolverProgress extends ResolverEvent {
  const ResolverProgress(this.progress);
  final SourceProgress progress;

  /// Convenience passthrough so listeners can read `event.status`.
  SourceStatus get status => progress.status;
  InstalledSource get source => progress.source;
}

class ResolverLink extends ResolverEvent {
  const ResolverLink(this.link);
  final StreamLink link;
}

class ResolverFinished extends ResolverEvent {
  const ResolverFinished(this.ranked, this.elapsed);
  final List<RankedStream> ranked;
  final Duration elapsed;
}

/// Fans out to every enabled source in parallel and streams results back.
///
/// Design notes:
/// * Per-source timeout — one slow add-on never blocks playback.
/// * Errors are contained per source and reported, never thrown.
/// * Results are de-duplicated by URL so two add-ons returning the same
///   debrid link don't produce duplicate rows.
/// * Cancellation propagates: leaving the sheet aborts in-flight work.
class StreamResolver {
  StreamResolver({
    required this.registry,
    this.perSourceTimeout = const Duration(seconds: 12),
    this.overallTimeout = const Duration(seconds: 25),
    this.maxConcurrent = 6,
    this.rules = const RankingRules(),
    this.onHealth,
  });

  final AdapterRegistry registry;
  final Duration perSourceTimeout;
  final Duration overallTimeout;

  /// Cap parallelism so low-end TV boxes don't open 30 sockets at once.
  final int maxConcurrent;
  final RankingRules rules;

  /// Callback to persist provider health after each source settles.
  final void Function(String sourceKey, {required bool ok, int? latencyMs, String? error})?
      onHealth;

  /// Cheap pre-filter: does this source even claim to serve this request?
  bool _canServe(InstalledSource s, PlayRequest req) {
    if (!s.enabled) return false;
    if (!s.can(Capability.streams)) return false;
    if (!s.supports(req.ref.type)) return false;
    final id = req.ref.imdbId ?? req.ref.id;
    if (!s.acceptsId(id)) return false;
    if (rules.blockedProviders.contains(s.key)) return false;
    return true;
  }

  /// Resolve across all ecosystems. Emits progress, then links, then a final
  /// ranked list. The returned stream is single-subscription.
  Stream<ResolverEvent> resolve(PlayRequest req) {
    final controller = StreamController<ResolverEvent>();
    unawaited(_run(req, controller));
    return controller.stream;
  }

  Future<void> _run(
    PlayRequest req,
    StreamController<ResolverEvent> controller,
  ) async {
    final sw = Stopwatch()..start();
    final log = AeroLog.instance;
    final collected = <StreamLink>[];
    final seenUrls = <String>{};
    final progress = <String, SourceProgress>{};
    var cancelled = false;

    controller.onCancel = () {
      cancelled = true;
    };

    try {
      final all = await registry.enabledSources();
      final usable = all.where((s) => _canServe(s, req)).toList();

      // Report skipped sources so the user understands why a provider is idle.
      for (final s in all.where((s) => !_canServe(s, req))) {
        final p = SourceProgress(source: s, status: SourceStatus.skipped);
        progress[s.key] = p;
        if (!controller.isClosed) controller.add(ResolverProgress(p));
      }

      if (!controller.isClosed) controller.add(ResolverStarted(usable));
      log.i('resolver',
          'Resolving ${req.stremioVideoId} across ${usable.length} source(s)');

      for (final s in usable) {
        final p = SourceProgress(source: s, status: SourceStatus.pending);
        progress[s.key] = p;
        if (!controller.isClosed) controller.add(ResolverProgress(p));
      }

      final deadline = DateTime.now().add(overallTimeout);
      final queue = List<InstalledSource>.of(usable);
      final active = <Future<void>>[];

      Future<void> runOne(InstalledSource s) async {
        if (cancelled) return;
        final adapter = registry.forEcosystem(s.ecosystem);
        if (adapter == null || !adapter.isAvailable) {
          final p = SourceProgress(
            source: s,
            status: SourceStatus.skipped,
            error: '${s.ecosystem.displayName} unavailable on this platform',
          );
          progress[s.key] = p;
          if (!controller.isClosed) controller.add(ResolverProgress(p));
          return;
        }

        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          final p = SourceProgress(source: s, status: SourceStatus.timedOut);
          progress[s.key] = p;
          if (!controller.isClosed) controller.add(ResolverProgress(p));
          return;
        }

        final start = DateTime.now();
        var count = 0;
        final sourceSw = Stopwatch()..start();

        final p = SourceProgress(source: s, status: SourceStatus.resolving);
        progress[s.key] = p;
        if (!controller.isClosed) controller.add(ResolverProgress(p));

        final budget = remaining < perSourceTimeout ? remaining : perSourceTimeout;
        StreamSubscription<StreamLink>? sub;
        final done = Completer<void>();
        Timer? timer;

        void finish(SourceStatus status, {String? error}) {
          timer?.cancel();
          if (done.isCompleted) return;
          final elapsed = DateTime.now().difference(start);
          final pr = SourceProgress(
            source: s,
            status: status,
            found: count,
            elapsed: elapsed,
            error: error,
          );
          progress[s.key] = pr;
          if (!controller.isClosed) controller.add(ResolverProgress(pr));
          onHealth?.call(
            s.key,
            ok: status == SourceStatus.done || status == SourceStatus.empty,
            latencyMs: sourceSw.elapsedMilliseconds,
            error: error,
          );
          done.complete();
        }

        timer = Timer(budget, () {
          log.w('resolver', '${s.name} timed out after ${budget.inSeconds}s');
          unawaited(sub?.cancel());
          finish(SourceStatus.timedOut);
        });

        try {
          sub = adapter.streams(s.id, req).listen(
            (link) {
              if (cancelled || controller.isClosed) return;
              // De-dup across providers, keeping the first (highest priority).
              final dedupKey = link.url.isNotEmpty ? link.url : link.infoHash ?? '';
              if (dedupKey.isNotEmpty && !seenUrls.add(dedupKey)) return;
              final withLatency =
                  link.copyWith(latencyMs: sourceSw.elapsedMilliseconds);
              collected.add(withLatency);
              count++;
              controller.add(ResolverLink(withLatency));
            },
            onError: (Object e, StackTrace _) {
              log.e('resolver', '${s.name} failed: $e');
              finish(SourceStatus.failed, error: _shortError(e));
            },
            onDone: () {
              finish(count > 0 ? SourceStatus.done : SourceStatus.empty);
            },
            cancelOnError: true,
          );
        } catch (e) {
          finish(SourceStatus.failed, error: _shortError(e));
        }

        await done.future;
        await sub?.cancel();
      }

      // Simple concurrency window.
      while ((queue.isNotEmpty || active.isNotEmpty) && !cancelled) {
        while (queue.isNotEmpty && active.length < maxConcurrent && !cancelled) {
          final s = queue.removeAt(0);
          final f = runOne(s);
          active.add(f);
          unawaited(f.then((_) => active.remove(f)));
        }
        if (active.isEmpty) break;
        await Future.any([
          Future.wait(active).then((_) => null),
          Future<void>.delayed(const Duration(milliseconds: 60)),
        ]);
        if (DateTime.now().isAfter(deadline)) {
          log.w('resolver', 'Overall resolution deadline reached');
          break;
        }
      }

      final ranked = StreamRanker(rules).rank(collected);
      sw.stop();
      log.i('resolver',
          'Resolved ${collected.length} link(s), ${ranked.length} playable, in ${sw.elapsedMilliseconds}ms');
      if (!controller.isClosed) {
        controller.add(ResolverFinished(ranked, sw.elapsed));
      }
    } catch (e, st) {
      log.e('resolver', 'Fatal resolver error: $e\n$st');
      if (!controller.isClosed) {
        controller.add(ResolverFinished(const [], sw.elapsed));
      }
    } finally {
      await controller.close();
    }
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }

  /// Convenience for callers that just want the final list.
  Future<List<RankedStream>> resolveAll(PlayRequest req) async {
    await for (final ev in resolve(req)) {
      if (ev is ResolverFinished) return ev.ranked;
    }
    return const [];
  }

  /// Groups links for the source sheet: ecosystem → provider.
  static Map<Ecosystem, Map<String, List<StreamLink>>> group(
    Iterable<StreamLink> links,
  ) {
    final out = <Ecosystem, Map<String, List<StreamLink>>>{};
    for (final l in links) {
      final byProvider = out.putIfAbsent(l.ecosystem, () => {});
      byProvider.putIfAbsent(l.sourceName, () => []).add(l);
    }
    return out;
  }
}
