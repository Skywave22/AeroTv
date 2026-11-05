import 'package:flutter/material.dart';

import '../theme/aero_colors.dart';

/// Slim resume-progress bar used on Continue Watching cards.
class SlimProgressBar extends StatelessWidget {
  const SlimProgressBar({
    required this.value,
    this.height = 3,
    this.color,
    super.key,
  });

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AeroColors.surfaceHigher,
        valueColor: AlwaysStoppedAnimation(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Formats milliseconds as `1:23:45` / `12:34`.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
