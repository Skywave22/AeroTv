import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'player_controller.dart';
import 'player_controls.dart';
import 'track_selection.dart';

/// Full-screen playback surface.
///
/// Handles: immersive system UI, wakelock, auto-hiding controls, TV remote
/// keys, resume persistence, and a friendly error state with "try another
/// source" rather than a dead end.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.link,
    required this.title,
    this.subtitle,
    this.startPosition = Duration.zero,
    this.hardwareDecoding = true,
    this.defaultSubtitleLang,
    this.subtitlesEnabled = true,
    this.preferredAudioLang,
    this.isTv = false,
    this.onProgress,
    this.onExit,
    this.onTryAnotherSource,
    this.externalSubtitles = const [],
    super.key,
  });

  final StreamLink link;
  final String title;
  final String? subtitle;
  final Duration startPosition;
  final bool hardwareDecoding;
  final String? defaultSubtitleLang;
  final bool subtitlesEnabled;
  final String? preferredAudioLang;
  final bool isTv;
  final void Function(Duration position, Duration duration)? onProgress;
  final VoidCallback? onExit;
  final VoidCallback? onTryAnotherSource;
  final List<SubtitleTrack> externalSubtitles;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AeroPlayerController _controller;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _controller = AeroPlayerController(
      link: widget.link,
      startPosition: widget.startPosition,
      hardwareDecoding: widget.hardwareDecoding,
      defaultSubtitleLang: widget.defaultSubtitleLang,
      subtitlesEnabled: widget.subtitlesEnabled,
      preferredAudioLang: widget.preferredAudioLang,
    );
    _controller.onProgress = widget.onProgress;
    _controller.addListener(_onControllerUpdate);

    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(WakelockPlus.enable());
    if (!widget.isTv) {
      unawaited(SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.open();
      if (mounted) setState(() => _opened = true);
      _scheduleHide();
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final snap = _controller.snapshot;
    // Surface controls again if playback stalls or errors.
    if (snap.error != null && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.isTv) return; // TV keeps controls until Back is pressed.
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_controller.snapshot.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _exit() {
    widget.onProgress?.call(
      _controller.snapshot.position,
      _controller.snapshot.duration,
    );
    widget.onExit?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    unawaited(WakelockPlus.disable());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  Future<void> _openTracks() async {
    await TrackSelectionSheet.show(
      context,
      controller: _controller,
      externalSubtitles: widget.externalSubtitles
          .map((s) => (id: s.id, label: s.displayLabel, lang: s.lang))
          .toList(),
      onAddExternal: (id) {
        final track = widget.externalSubtitles.firstWhere(
          (s) => s.id == id,
          orElse: () => widget.externalSubtitles.first,
        );
        unawaited(_controller.addExternalSubtitle(track));
      },
    );
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _controller.snapshot;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // On TV, Back hides controls first, then exits.
        if (widget.isTv && _controlsVisible) {
          setState(() => _controlsVisible = false);
          return;
        }
        _exit();
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
              const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.space): const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPlay): const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPause): const _PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const _SeekIntent(1),
          const SingleActivator(LogicalKeyboardKey.mediaFastForward):
              const _SeekIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const _SeekIntent(-1),
          const SingleActivator(LogicalKeyboardKey.mediaRewind): const _SeekIntent(-1),
          const SingleActivator(LogicalKeyboardKey.contextMenu): const _TracksIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _ShowControlsIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _ShowControlsIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const _ExitIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(onInvoke: (_) {
              unawaited(_controller.playPause());
              setState(() => _controlsVisible = true);
              _scheduleHide();
              return null;
            }),
            _SeekIntent: CallbackAction<_SeekIntent>(onInvoke: (intent) {
              unawaited(_controller
                  .seekBy(Duration(seconds: 10 * intent.direction)));
              setState(() => _controlsVisible = true);
              _scheduleHide();
              return null;
            }),
            _TracksIntent: CallbackAction<_TracksIntent>(onInvoke: (_) {
              unawaited(_openTracks());
              return null;
            }),
            _ShowControlsIntent: CallbackAction<_ShowControlsIntent>(onInvoke: (_) {
              _toggleControls();
              return null;
            }),
            _ExitIntent: CallbackAction<_ExitIntent>(onInvoke: (_) {
              _exit();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_opened)
                      Video(
                        controller: _controller.videoController,
                        controls: NoVideoControls,
                        fit: BoxFit.contain,
                        fill: Colors.black,
                      )
                    else
                      const Center(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white54),
                        ),
                      ),
                    if (snap.error != null)
                      _PlayerError(
                        message: snap.error!,
                        sourceName: widget.link.sourceName,
                        onBack: _exit,
                        onRetry: widget.onTryAnotherSource,
                      )
                    else
                      AeroPlayerControls(
                        controller: _controller,
                        title: widget.title,
                        subtitle: widget.subtitle ??
                            '${widget.link.sourceName} · ${widget.link.quality.label}',
                        visible: _controlsVisible,
                        isTv: widget.isTv,
                        onBack: _exit,
                        onOpenTracks: _openTracks,
                        onInteracted: _scheduleHide,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _SeekIntent extends Intent {
  const _SeekIntent(this.direction);
  final int direction;
}

class _TracksIntent extends Intent {
  const _TracksIntent();
}

class _ShowControlsIntent extends Intent {
  const _ShowControlsIntent();
}

class _ExitIntent extends Intent {
  const _ExitIntent();
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({
    required this.message,
    required this.sourceName,
    required this.onBack,
    this.onRetry,
  });

  final String message;
  final String sourceName;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFFF5C7A), size: 46),
                const SizedBox(height: 16),
                const Text(
                  'Playback failed',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Source: $sourceName',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (onRetry != null)
                      FilledButton.icon(
                        autofocus: true,
                        onPressed: onRetry,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Try another source'),
                      ),
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
