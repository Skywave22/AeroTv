import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

/// Snapshot of everything the controls need to render.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = true,
    this.playing = false,
    this.completed = false,
    this.rate = 1.0,
    this.volume = 100.0,
    this.error,
    this.tracks = const [],
    this.track = const TrackSelection(),
  });

  final Duration position;
  final Duration duration;
  final bool buffering;
  final bool playing;
  final bool completed;
  final double rate;
  final double volume;
  final String? error;
  final List<MediaTrackInfo> tracks;
  final TrackSelection track;

  double get progress => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  bool get canResume => position.inSeconds > 30 && progress < 0.92;
}

/// Normalised audio/video/subtitle track descriptor.
class MediaTrackInfo {
  const MediaTrackInfo({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.isDefault = false,
  });

  final String id;
  final TrackKind kind;
  final String? title;
  final String? language;
  final bool isDefault;

  String get label {
    final parts = <String>[
      if (title != null && title!.isNotEmpty) title!,
      if (language != null && language!.isNotEmpty) language!.toUpperCase(),
    ];
    if (parts.isEmpty) return kind == TrackKind.subtitle ? 'Subtitle $id' : 'Track $id';
    return parts.join(' · ');
  }
}

enum TrackKind { audio, subtitle, video }

class TrackSelection {
  const TrackSelection({this.audioId, this.subtitleId, this.videoId});

  final String? audioId;
  final String? subtitleId;
  final String? videoId;

  TrackSelection copyWith({
    String? audioId,
    String? subtitleId,
    String? videoId,
    bool clearSubtitle = false,
  }) =>
      TrackSelection(
        audioId: audioId ?? this.audioId,
        subtitleId: clearSubtitle ? null : (subtitleId ?? this.subtitleId),
        videoId: videoId ?? this.videoId,
      );
}

/// Wraps a media_kit [Player] and exposes a listenable [PlaybackSnapshot].
///
/// Key responsibilities:
/// * pass provider-required HTTP headers to libmpv,
/// * load external subtitles from add-ons,
/// * expose audio/subtitle track lists in a UI-friendly shape,
/// * emit position updates so the app can persist resume points.
class AeroPlayerController extends ChangeNotifier {
  AeroPlayerController({
    required this.link,
    this.startPosition = Duration.zero,
    this.hardwareDecoding = true,
    this.defaultSubtitleLang,
    this.subtitlesEnabled = true,
    this.preferredAudioLang,
    this.userAgent = 'AeroTV/0.1',
  }) {
    _player = mk.Player(
      configuration: mk.PlayerConfiguration(
        // A modest buffer keeps start-up fast on TV boxes with little RAM.
        bufferSize: 24 * 1024 * 1024,
        logLevel: mk.MPVLogLevel.error,
        title: 'Aero TV',
      ),
    );
    _video = VideoController(_player);
    _wire();
  }

  final StreamLink link;
  final Duration startPosition;
  final bool hardwareDecoding;
  final String? defaultSubtitleLang;
  final bool subtitlesEnabled;
  final String? preferredAudioLang;
  final String userAgent;

  late final mk.Player _player;
  late final VideoController _video;

  VideoController get videoController => _video;
  mk.Player get player => _player;

  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  PlaybackSnapshot get snapshot => _snapshot;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _positionTimer;
  bool _disposed = false;

  /// Called roughly every 10s with the current position for resume persistence.
  void Function(Duration position, Duration duration)? onProgress;

  void _wire() {
    _subs.addAll([
      _player.stream.position.listen((v) => _update(position: v)),
      _player.stream.duration.listen((v) => _update(duration: v)),
      _player.stream.buffering.listen((v) => _update(buffering: v)),
      _player.stream.playing.listen((v) => _update(playing: v)),
      _player.stream.completed.listen((v) => _update(completed: v)),
      _player.stream.rate.listen((v) => _update(rate: v)),
      _player.stream.volume.listen((v) => _update(volume: v)),
      _player.stream.error.listen((e) {
        AeroLog.instance.e('player', 'mpv error: $e');
        _update(error: e);
      }),
      _player.stream.tracks.listen((_) => _refreshTracks()),
      _player.stream.track.listen((_) => _refreshTracks()),
    ]);
  }

  void _update({
    Duration? position,
    Duration? duration,
    bool? buffering,
    bool? playing,
    bool? completed,
    double? rate,
    double? volume,
    String? error,
    List<MediaTrackInfo>? tracks,
    TrackSelection? track,
  }) {
    if (_disposed) return;
    _snapshot = PlaybackSnapshot(
      position: position ?? _snapshot.position,
      duration: duration ?? _snapshot.duration,
      buffering: buffering ?? _snapshot.buffering,
      playing: playing ?? _snapshot.playing,
      completed: completed ?? _snapshot.completed,
      rate: rate ?? _snapshot.rate,
      volume: volume ?? _snapshot.volume,
      error: error ?? _snapshot.error,
      tracks: tracks ?? _snapshot.tracks,
      track: track ?? _snapshot.track,
    );
    notifyListeners();
  }

  /// Opens the stream. Headers from `behaviorHints.proxyHeaders` are essential
  /// for many providers — without them the URL returns 403.
  Future<void> open() async {
    try {
      final headers = <String, String>{
        'User-Agent': userAgent,
        ...link.headers,
      };
      AeroLog.instance.i('player',
          'Opening ${link.kind.name} stream from ${link.sourceName} '
          '(${link.headers.length} custom header(s))');

      // libmpv wants these as properties, not just per-request headers.
      final native = _player.platform;
      if (native is mk.NativePlayer) {
        await native.setProperty('http-header-fields', _headerLine(headers));
        await native.setProperty(
          'hwdec',
          hardwareDecoding ? 'auto-safe' : 'no',
        );
        // Keep the network cache modest for low-memory devices.
        await native.setProperty('cache', 'yes');
        await native.setProperty('demuxer-max-bytes', '48MiB');
        await native.setProperty('demuxer-readahead-secs', '20');
        if (link.headers['Referer'] != null) {
          await native.setProperty('referrer', link.headers['Referer']!);
        }
      }

      await _player.open(
        mk.Media(link.url, httpHeaders: headers, start: startPosition),
        play: true,
      );

      // External subtitles supplied by the add-on.
      for (final s in link.subtitles) {
        await _player.setSubtitleTrack(
          mk.SubtitleTrack.uri(s.url, title: s.displayLabel, language: s.lang),
        );
      }

      await _applyLanguagePreferences();
      _refreshTracks();
      _startProgressTimer();
    } catch (e) {
      AeroLog.instance.e('player', 'open failed: $e');
      _update(error: 'Could not open this stream. Try another source.');
    }
  }

  String _headerLine(Map<String, String> headers) =>
      headers.entries.map((e) => '${e.key}: ${e.value}').join(',');

  Future<void> _applyLanguagePreferences() async {
    final tracks = _player.state.tracks;
    if (subtitlesEnabled && defaultSubtitleLang != null) {
      final want = defaultSubtitleLang!.toLowerCase();
      final match = tracks.subtitle.firstWhere(
        (t) =>
            (t.language?.toLowerCase().startsWith(want) ?? false) ||
            (t.title?.toLowerCase().contains(want) ?? false),
        orElse: () => mk.SubtitleTrack.auto(),
      );
      if (match.id != 'auto') {
        await _player.setSubtitleTrack(match);
      }
    } else if (!subtitlesEnabled) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    }

    if (preferredAudioLang != null) {
      final want = preferredAudioLang!.toLowerCase();
      final candidates = tracks.audio.where(
        (t) =>
            (t.language?.toLowerCase().startsWith(want) ?? false) ||
            (t.title?.toLowerCase().contains(want) ?? false),
      );
      if (candidates.isNotEmpty) {
        await _player.setAudioTrack(candidates.first);
      }
    }
  }

  void _refreshTracks() {
    final t = _player.state.tracks;
    final selected = _player.state.track;
    final infos = <MediaTrackInfo>[];

    for (final a in t.audio) {
      if (a.id == 'auto' || a.id == 'no') continue;
      infos.add(MediaTrackInfo(
        id: a.id,
        kind: TrackKind.audio,
        title: a.title,
        language: a.language,
      ));
    }
    for (final s in t.subtitle) {
      if (s.id == 'auto' || s.id == 'no') continue;
      infos.add(MediaTrackInfo(
        id: s.id,
        kind: TrackKind.subtitle,
        title: s.title,
        language: s.language,
      ));
    }
    for (final v in t.video) {
      if (v.id == 'auto' || v.id == 'no') continue;
      infos.add(MediaTrackInfo(
        id: v.id,
        kind: TrackKind.video,
        title: v.title,
        language: v.language,
      ));
    }

    _update(
      tracks: infos,
      track: TrackSelection(
        audioId: selected.audio.id,
        subtitleId: selected.subtitle.id == 'no' ? null : selected.subtitle.id,
        videoId: selected.video.id,
      ),
    );
  }

  void _startProgressTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed) return;
      onProgress?.call(_player.state.position, _player.state.duration);
    });
  }

  // ------------------------------------------------------------- commands

  Future<void> playPause() => _player.playOrPause();
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> seekBy(Duration delta) {
    final target = _player.state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _player.state.duration ? _player.state.duration : target);
    return _player.seek(clamped);
  }

  Future<void> setRate(double rate) => _player.setRate(rate);
  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0, 100));

  Future<void> selectAudio(String id) async {
    final t = _player.state.tracks.audio.firstWhere(
      (a) => a.id == id,
      orElse: () => mk.AudioTrack.auto(),
    );
    await _player.setAudioTrack(t);
    _refreshTracks();
  }

  Future<void> selectSubtitle(String? id) async {
    if (id == null) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    } else {
      final t = _player.state.tracks.subtitle.firstWhere(
        (s) => s.id == id,
        orElse: () => mk.SubtitleTrack.no(),
      );
      await _player.setSubtitleTrack(t);
    }
    _refreshTracks();
  }

  /// Adds an external subtitle at runtime (from a subtitles add-on).
  Future<void> addExternalSubtitle(SubtitleTrack track) async {
    await _player.setSubtitleTrack(
      mk.SubtitleTrack.uri(track.url, title: track.displayLabel, language: track.lang),
    );
    _refreshTracks();
  }

  Future<void> setSubtitleDelay(Duration d) async {
    final native = _player.platform;
    if (native is mk.NativePlayer) {
      await native.setProperty('sub-delay', '${d.inMilliseconds / 1000.0}');
    }
  }

  Future<void> setAudioDelay(Duration d) async {
    final native = _player.platform;
    if (native is mk.NativePlayer) {
      await native.setProperty('audio-delay', '${d.inMilliseconds / 1000.0}');
    }
  }

  /// `contain` | `cover` | `fill`
  Future<void> setAspect(String mode) async {
    final native = _player.platform;
    if (native is! mk.NativePlayer) return;
    switch (mode) {
      case 'cover':
        await native.setProperty('video-aspect-override', '-1');
        await native.setProperty('panscan', '1.0');
        break;
      case 'fill':
        await native.setProperty('video-aspect-override', '16:9');
        await native.setProperty('panscan', '0.0');
        break;
      default:
        await native.setProperty('video-aspect-override', '-1');
        await native.setProperty('panscan', '0.0');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    // Persist one final position before tearing down.
    onProgress?.call(_player.state.position, _player.state.duration);
    unawaited(_player.dispose());
    super.dispose();
  }
}
