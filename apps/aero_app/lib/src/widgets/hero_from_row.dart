import 'package:aero_core/aero_core.dart';

/// Picks hero candidates: prefer items with a backdrop and a description.
List<MediaItem> pickHeroItems(List<MediaItem> items, {int max = 5}) {
  final withArt = items
      .where((i) => i.background != null && i.background!.isNotEmpty)
      .toList();
  final pool = withArt.isNotEmpty ? withArt : items;
  return pool.take(max).toList();
}
