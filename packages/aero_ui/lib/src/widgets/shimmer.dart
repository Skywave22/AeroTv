import 'package:flutter/material.dart';

import '../theme/aero_colors.dart';

/// Lightweight shimmer. Uses a single AnimationController per widget and a
/// plain gradient — no shader work, so it stays cheap on low-end TV boxes.
class Shimmer extends StatefulWidget {
  const Shimmer({
    this.width,
    this.height,
    this.radius = 12,
    this.enabled = true,
    super.key,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform's "reduce motion" setting. This also keeps widget
    // tests deterministic: with animations disabled no ticker is left pending.
    final animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_started) {
      _started = true;
      _c.repeat();
    } else if (!animate && _started) {
      _started = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AeroColors.surfaceHigh;
    final highlight = AeroColors.surfaceHigher;
    final animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: animate
          ? AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + _c.value * 2.4, -0.3),
                      end: Alignment(0.2 + _c.value * 2.4, 0.3),
                      colors: [base, highlight, base],
                      stops: const [0.1, 0.5, 0.9],
                    ),
                  ),
                );
              },
            )
          : ColoredBox(color: base),
    );
    return SizedBox(width: widget.width, height: widget.height, child: child);
  }
}

/// Poster-shaped placeholder used while catalogs load.
class PosterSkeleton extends StatelessWidget {
  const PosterSkeleton({this.width = 120, this.reduceMotion = false, super.key});

  final double width;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer(
            width: width,
            height: width * 1.5,
            enabled: !reduceMotion,
          ),
          const SizedBox(height: 8),
          Shimmer(width: width * 0.8, height: 12, radius: 4, enabled: !reduceMotion),
          const SizedBox(height: 5),
          Shimmer(width: width * 0.45, height: 10, radius: 4, enabled: !reduceMotion),
        ],
      ),
    );
  }
}
