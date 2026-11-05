import 'package:flutter/material.dart';

import '../theme/aero_colors.dart';
import 'aero_buttons.dart';

/// Friendly empty/error state with an optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 76,
                height: compact ? 56 : 76,
                decoration: BoxDecoration(
                  color: AeroColors.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: AeroColors.outline),
                ),
                child: Icon(
                  icon,
                  size: compact ? 26 : 34,
                  color: AeroColors.textTertiary,
                ),
              ),
              SizedBox(height: compact ? 14 : 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AeroColors.textSecondary,
                    ),
              ),
              if (actionLabel != null) ...[
                SizedBox(height: compact ? 16 : 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    AeroPrimaryButton(
                      label: actionLabel!,
                      onPressed: onAction,
                      autofocus: true,
                    ),
                    if (secondaryLabel != null)
                      AeroSecondaryButton(
                        label: secondaryLabel!,
                        onPressed: onSecondary,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
