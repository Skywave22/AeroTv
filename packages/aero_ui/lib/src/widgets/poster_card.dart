import 'package:aero_core/aero_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../focus/tv_focus.dart';
import '../theme/aero_colors.dart';
import 'shimmer.dart';

/// 2:3 poster card with title, year and an optional resume progress bar.
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.item,
    required this.onTap,
    this.width = 120,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.progress,
    this.badge,
    this.reduceMotion = false,
    this.showTitle = true,
    super.key,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// 0..1 resume progress; draws a bar under the poster when set.
  final double? progress;
  final String? badge;
  final bool reduceMotion;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: TvFocus(
        focusNode: focusNode,
        autofocus: autofocus,
        onSelect: onTap,
        onFocusChange: onFocusChange,
        reduceMotion: reduceMotion,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PosterImage(url: item.poster, title: item.title),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (progress != null && progress! > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.black54,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showTitle) ...[
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AeroColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (item.year != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${item.year}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AeroColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      // Decode at display size: huge posters are the #1 cause of TV jank.
      memCacheWidth: 400,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const Shimmer(height: double.infinity, radius: 0),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: AeroColors.surfaceHigh,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AeroColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
