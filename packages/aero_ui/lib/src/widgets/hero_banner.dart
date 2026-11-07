import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../layout/adaptive.dart';
import '../theme/aero_colors.dart';
import 'aero_buttons.dart';
import 'ecosystem_badge.dart';

/// Auto-rotating hero with backdrop, logo art, gradient scrim and CTAs.
class HeroBanner extends StatefulWidget {
  const HeroBanner({
    required this.items,
    required this.onPlay,
    required this.onMoreInfo,
    this.formFactor = FormFactor.phone,
    this.rotationSeconds = 8,
    this.reduceMotion = false,
    this.autoplayEnabled = true,
    super.key,
  });

  final List<MediaItem> items;
  final void Function(MediaItem) onPlay;
  final void Function(MediaItem) onMoreInfo;
  final FormFactor formFactor;
  final int rotationSeconds;
  final bool reduceMotion;
  final bool autoplayEnabled;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.autoplayEnabled || widget.items.length < 2) return;
    _timer = Timer.periodic(Duration(seconds: widget.rotationSeconds), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed feed can shorten the list under a running timer; without
    // this the next tick animates to a page that no longer exists.
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.rotationSeconds != widget.rotationSeconds ||
        oldWidget.autoplayEnabled != widget.autoplayEnabled) {
      if (_index >= widget.items.length) {
        _index = widget.items.isEmpty ? 0 : widget.items.length - 1;
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final height = Adaptive.heroHeight(widget.formFactor, size);
    final isTv = widget.formFactor == FormFactor.tv;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final item = widget.items[i];
              final art = item.background ?? item.poster;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (art != null)
                    CachedNetworkImage(
                      imageUrl: art,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 1280,
                      fadeInDuration: const Duration(milliseconds: 250),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AeroColors.surfaceHigh),
                    )
                  else
                    const ColoredBox(color: AeroColors.surfaceHigh),
                  // Two scrims: vertical for text, horizontal for the left rail.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AeroColors.heroScrim,
                        stops: [0.25, 0.62, 1.0],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AeroColors.background.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.75],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTv ? 56 : 20,
                        0,
                        isTv ? 56 : 20,
                        isTv ? 48 : 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTv ? size.width * 0.55 : size.width * 0.9,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.logo != null)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: isTv ? 110 : 72,
                                  maxWidth: isTv ? 420 : 260,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: item.logo!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  errorWidget: (_, _, _) =>
                                      _titleText(context, item),
                                ),
                              )
                            else
                              _titleText(context, item),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (item.year != null)
                                  MetaChip(label: '${item.year}'),
                                if (item.imdbRating != null)
                                  MetaChip(
                                    label: '★ ${item.imdbRating!.toStringAsFixed(1)}',
                                    tone: MetaChipTone.warning,
                                  ),
                                if (item.runtime != null)
                                  MetaChip(label: item.runtime!),
                                ...item.genres.take(2).map((g) => MetaChip(label: g)),
                              ],
                            ),
                            if (item.description != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                item.description!,
                                maxLines: isTv ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AeroColors.textSecondary,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                AeroPrimaryButton(
                                  label: 'Play',
                                  icon: Icons.play_arrow_rounded,
                                  autofocus: isTv,
                                  onPressed: () => widget.onPlay(item),
                                ),
                                const SizedBox(width: 12),
                                AeroSecondaryButton(
                                  label: 'More Info',
                                  icon: Icons.info_outline_rounded,
                                  onPressed: () => widget.onMoreInfo(item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: isTv ? 20 : 8,
              right: isTv ? 56 : 20,
              child: Row(
                children: List.generate(widget.items.length.clamp(0, 6), (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : AeroColors.textTertiary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _titleText(BuildContext context, MediaItem item) => Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.displayMedium,
      );
}
