import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aero_colors.dart';

/// A focusable card wrapper that gives D-pad navigation a premium feel:
/// a visible ring, a slight scale-up, and a soft glow.
///
/// Why not just [FocusableActionDetector]? We also need:
/// * spring-ish scale animation that respects "reduce motion",
/// * an `autofocus` hook so the first card is focused on TV,
/// * `onFocusChange` so rows can remember their last focused child.
class TvFocus extends StatefulWidget {
  const TvFocus({
    required this.child,
    this.onSelect,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius = 14,
    this.scale = 1.06,
    this.enabled = true,
    this.reduceMotion = false,
    this.accent,
    super.key,
  });

  final Widget child;
  final VoidCallback? onSelect;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final FocusNode? focusNode;
  final double borderRadius;
  final double scale;
  final bool enabled;
  final bool reduceMotion;
  final Color? accent;

  @override
  State<TvFocus> createState() => _TvFocusState();
}

class _TvFocusState extends State<TvFocus> {
  bool _focused = false;
  late FocusNode _node;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    _node = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  void _handleFocus(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
    widget.onFocusChange?.call(value);
    if (value) {
      // Keep the focused card on screen when navigating long rows.
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration:
            widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    final duration =
        widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onFocusChange: _handleFocus,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSelect?.call();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1.0,
        duration: duration,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 2),
            border: Border.all(
              color: _focused ? accent : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Remembers which child was last focused in each row, so moving down and back
/// up returns the user to the same column instead of snapping to the start.
///
/// This is the single biggest usability difference between a ported phone UI
/// and a real TV UI.
class RowFocusMemory {
  final Map<String, int> _lastIndex = {};
  final Map<String, FocusNode> _nodes = {};

  int indexFor(String rowKey) => _lastIndex[rowKey] ?? 0;

  void remember(String rowKey, int index) {
    _lastIndex[rowKey] = index;
  }

  /// Returns a stable node for a cell, creating it on first use.
  FocusNode nodeFor(String rowKey, int index) {
    final key = '$rowKey#$index';
    return _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));
  }

  /// Focuses the remembered cell of [rowKey], falling back to the first cell.
  void focusRow(String rowKey, {int maxIndex = 0}) {
    final wanted = indexFor(rowKey).clamp(0, maxIndex < 0 ? 0 : maxIndex);
    final node = _nodes['$rowKey#$wanted'];
    if (node != null && node.context != null) {
      node.requestFocus();
    } else {
      _nodes['$rowKey#0']?.requestFocus();
    }
  }

  void clear() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _nodes.clear();
    _lastIndex.clear();
  }
}

/// Applies overscan-safe padding on TVs. Many sets crop 2–5% of the image.
class OverscanPadding extends StatelessWidget {
  const OverscanPadding({
    required this.child,
    this.percent = 3.0,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final double percent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || percent <= 0) return child;
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * (percent / 100),
        vertical: size.height * (percent / 100),
      ),
      child: child,
    );
  }
}

/// A visible focus ring for arbitrary controls (buttons, chips, list tiles).
class FocusRing extends StatelessWidget {
  const FocusRing({
    required this.builder,
    this.borderRadius = 12,
    super.key,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: focused
                    ? Theme.of(ctx).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: builder(ctx, focused),
          );
        },
      ),
    );
  }
}

/// Standard surface for cards; keeps border radii consistent app-wide.
class AeroSurface extends StatelessWidget {
  const AeroSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AeroColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AeroColors.outline),
      ),
      child: child,
    );
  }
}
