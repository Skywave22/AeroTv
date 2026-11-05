
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'player_controller.dart';

/// Custom overlay controls tuned for both touch and D-pad.
///
/// media_kit ships default controls, but we need: TV-friendly focus targets,
/// a seek bar that responds to left/right on a remote, and our own track sheet.
class AeroPlayerControls extends StatefulWidget {
  const AeroPlayerControls({
    required this.controller,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onOpenTracks,
    this.visible = true,
    this.onInteracted,
    this.isTv = false,
    super.key,
  });

  final AeroPlayerController controller;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onOpenTracks;
  final bool visible;
  final VoidCallback? onInteracted;
  final bool isTv;

  @override
  State<AeroPlayerControls> createState() => _AeroPlayerControlsState();
}

class _AeroPlayerControlsState extends State<AeroPlayerControls> {
  bool _scrubbing = false;
  double _scrubValue = 0;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snap = widget.controller.snapshot;
        final bottomPadding = widget.isTv ? 40.0 : 16.0;

        return AnimatedOpacity(
          opacity: widget.visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0x1A000000),
                    Color(0x1A000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.25, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // ---- top bar ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.subtitle != null)
                                  Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onOpenTracks,
                            icon: const Icon(Icons.tune_rounded, color: Colors.white),
                            tooltip: 'Audio & subtitles',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // ---- centre transport ----
                    if (snap.buffering)
                      const SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _roundButton(
                            icon: Icons.replay_10_rounded,
                            size: 34,
                            onTap: () {
                              widget.controller.seekBy(const Duration(seconds: -10));
                              widget.onInteracted?.call();
                            },
                          ),
                          const SizedBox(width: 28),
                          _roundButton(
                            icon: snap.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 52,
                            autofocus: widget.isTv,
                            filled: true,
                            onTap: () {
                              widget.controller.playPause();
                              widget.onInteracted?.call();
                            },
                          ),
                          const SizedBox(width: 28),
                          _roundButton(
                            icon: Icons.forward_30_rounded,
                            size: 34,
                            onTap: () {
                              widget.controller.seekBy(const Duration(seconds: 30));
                              widget.onInteracted?.call();
                            },
                          ),
                        ],
                      ),
                    const Spacer(),

                    // ---- seek bar ----
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                _fmt(_scrubbing
                                    ? Duration(
                                        milliseconds: (_scrubValue *
                                                snap.duration.inMilliseconds)
                                            .round())
                                    : snap.position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const Spacer(),
                              if (snap.rate != 1.0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    '${snap.rate}x',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              Text(
                                _fmt(snap.duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16),
                              activeTrackColor:
                                  Theme.of(context).colorScheme.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: (_scrubbing ? _scrubValue : snap.progress)
                                  .clamp(0.0, 1.0),
                              onChangeStart: (v) => setState(() {
                                _scrubbing = true;
                                _scrubValue = v;
                              }),
                              onChanged: (v) => setState(() => _scrubValue = v),
                              onChangeEnd: (v) {
                                setState(() => _scrubbing = false);
                                widget.controller.seek(Duration(
                                  milliseconds:
                                      (v * snap.duration.inMilliseconds).round(),
                                ));
                                widget.onInteracted?.call();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 32,
    bool filled = false,
    bool autofocus = false,
  }) {
    return _FocusableCircle(
      icon: icon,
      size: size,
      filled: filled,
      autofocus: autofocus,
      onTap: onTap,
      accent: Theme.of(context).colorScheme.primary,
    );
  }
}

class _FocusableCircle extends StatefulWidget {
  const _FocusableCircle({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.filled,
    required this.autofocus,
    required this.accent,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  final bool autofocus;
  final Color accent;

  @override
  State<_FocusableCircle> createState() => _FocusableCircleState();
}

class _FocusableCircleState extends State<_FocusableCircle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final diameter = widget.size + 22;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.filled
                ? (_focused ? Colors.white : Colors.white.withValues(alpha: 0.18))
                : (_focused ? Colors.white24 : Colors.transparent),
            border: Border.all(
              color: _focused ? widget.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.filled && _focused ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
