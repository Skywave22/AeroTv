import 'package:aero_core/aero_core.dart';
import 'package:flutter/material.dart';

import '../theme/aero_colors.dart';

/// Small coloured chip so users always know which ecosystem produced a result.
class EcosystemBadge extends StatelessWidget {
  const EcosystemBadge({
    required this.ecosystem,
    this.compact = false,
    this.label,
    super.key,
  });

  final Ecosystem ecosystem;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = Color(ecosystem.colorSeed);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label ?? ecosystem.displayName,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral metadata chip (quality, size, language, codec...).
class MetaChip extends StatelessWidget {
  const MetaChip({
    required this.label,
    this.icon,
    this.tone = MetaChipTone.neutral,
    super.key,
  });

  final String label;
  final IconData? icon;
  final MetaChipTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MetaChipTone.neutral => AeroColors.textSecondary,
      MetaChipTone.accent => Theme.of(context).colorScheme.primary,
      MetaChipTone.success => AeroColors.success,
      MetaChipTone.warning => AeroColors.warning,
      MetaChipTone.danger => AeroColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

enum MetaChipTone { neutral, accent, success, warning, danger }
