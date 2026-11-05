import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aero_colors.dart';
import 'adaptive.dart';

/// One navigation destination in the shell.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive navigation shell: bottom bar on phones, side rail on
/// tablet/desktop/TV. On TV the rail is always expanded and D-pad friendly.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
    required this.formFactor,
    this.brandName = 'Aero TV',
    this.overscanPercent = 3.0,
    super.key,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;
  final FormFactor formFactor;

  /// Shown next to the logo in the expanded side rail. Pass
  /// `BrandConfig.appName` so rebranding touches one place only.
  final String brandName;
  final double overscanPercent;

  @override
  Widget build(BuildContext context) {
    final isRail = Adaptive.usesSideRail(formFactor);
    final isTv = formFactor == FormFactor.tv;

    final body = isTv
        ? Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width * (overscanPercent / 100),
              vertical: MediaQuery.sizeOf(context).height * (overscanPercent / 100),
            ),
            child: child,
          )
        : child;

    if (!isRail) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _SideRail(
            brandName: brandName,
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            expanded: isTv || formFactor == FormFactor.desktop,
          ),
          VerticalDivider(
            width: 1,
            color: AeroColors.outline.withValues(alpha: 0.6),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.brandName,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.expanded,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expanded;
  final String brandName;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: expanded ? 210 : 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 20, color: Colors.white),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      brandName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: destinations.length,
                itemBuilder: (context, i) {
                  final d = destinations[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: FocusTraversalOrder(
                      order: NumericFocusOrder(i.toDouble()),
                      child: _RailItem(
                        destination: d,
                        selected: selected,
                        expanded: expanded,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FocusableActionDetector(
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
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 14 : 0,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: _focused
                ? accent.withValues(alpha: 0.26)
                : widget.selected
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _focused ? accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                widget.selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 22,
                color: widget.selected || _focused
                    ? accent
                    : AeroColors.textSecondary,
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.destination.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              widget.selected ? FontWeight.w600 : FontWeight.w500,
                          color: widget.selected || _focused
                              ? AeroColors.textPrimary
                              : AeroColors.textSecondary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
