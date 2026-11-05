import 'package:aero_core/aero_core.dart';
import 'package:flutter/material.dart';

import '../focus/tv_focus.dart';
import '../layout/adaptive.dart';
import '../theme/aero_colors.dart';
import 'poster_card.dart';
import 'shimmer.dart';

/// A horizontally scrolling catalog row.
///
/// Uses a [ListView.builder] so a 100-item catalog only builds visible cards,
/// and wraps each in [RepaintBoundary] to keep scrolling cheap on TV boxes.
class MediaRow extends StatefulWidget {
  const MediaRow({
    required this.title,
    required this.items,
    required this.onSelect,
    this.rowKey,
    this.formFactor = FormFactor.phone,
    this.isLoading = false,
    this.onSeeAll,
    this.focusMemory,
    this.progressFor,
    this.badgeFor,
    this.reduceMotion = false,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final void Function(MediaItem item) onSelect;
  final String? rowKey;
  final FormFactor formFactor;
  final bool isLoading;
  final VoidCallback? onSeeAll;
  final RowFocusMemory? focusMemory;
  final double? Function(MediaItem)? progressFor;
  final String? Function(MediaItem)? badgeFor;
  final bool reduceMotion;

  @override
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = Adaptive.posterWidth(widget.formFactor);
    final height = width * 1.5 + (widget.formFactor == FormFactor.tv ? 62 : 52);
    final key = widget.rowKey ?? widget.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AeroColors.textTertiary,
                            ),
                      ),
                  ],
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: widget.isLoading && widget.items.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 8,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, _) => PosterSkeleton(
                    width: width,
                    reduceMotion: widget.reduceMotion,
                  ),
                )
              : FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = widget.items[i];
                      return RepaintBoundary(
                        child: FocusTraversalOrder(
                          order: NumericFocusOrder(i.toDouble()),
                          child: PosterCard(
                            item: item,
                            width: width,
                            reduceMotion: widget.reduceMotion,
                            focusNode: widget.focusMemory?.nodeFor(key, i),
                            onFocusChange: (focused) {
                              if (focused) widget.focusMemory?.remember(key, i);
                            },
                            progress: widget.progressFor?.call(item),
                            badge: widget.badgeFor?.call(item),
                            onTap: () => widget.onSelect(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
