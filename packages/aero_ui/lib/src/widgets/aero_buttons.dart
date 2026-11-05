import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aero_colors.dart';

/// Primary CTA with a D-pad focus ring. Works with touch, mouse and remote.
class AeroPrimaryButton extends StatefulWidget {
  const AeroPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;
  final bool expand;

  @override
  State<AeroPrimaryButton> createState() => _AeroPrimaryButtonState();
}

class _AeroPrimaryButtonState extends State<AeroPrimaryButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final button = FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: widget.icon == null ? const SizedBox.shrink() : Icon(widget.icon),
          label: Text(widget.label),
          style: FilledButton.styleFrom(
            backgroundColor: _focused ? Colors.white : accent,
            foregroundColor: _focused ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary/ghost CTA.
class AeroSecondaryButton extends StatefulWidget {
  const AeroSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;

  @override
  State<AeroSecondaryButton> createState() => _AeroSecondaryButtonState();
}

class _AeroSecondaryButtonState extends State<AeroSecondaryButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: OutlinedButton.icon(
        onPressed: widget.onPressed,
        icon: widget.icon == null ? const SizedBox.shrink() : Icon(widget.icon),
        label: Text(widget.label),
        style: OutlinedButton.styleFrom(
          backgroundColor: _focused
              ? AeroColors.surfaceHigher
              : AeroColors.surface.withValues(alpha: 0.6),
          side: BorderSide(
            color: _focused
                ? Theme.of(context).colorScheme.primary
                : AeroColors.outline,
            width: _focused ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
