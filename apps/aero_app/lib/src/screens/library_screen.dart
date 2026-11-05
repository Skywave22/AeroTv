import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Watchlist'),
            Tab(text: 'Favorites'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ItemsGrid(
            asyncItems: ref.watch(watchlistProvider),
            formFactor: formFactor,
            emptyTitle: 'Your watchlist is empty',
            emptyMessage:
                'Open any title and tap Watchlist to save it here for later.',
            onRemove: (item) => ref
                .read(libraryRepoProvider)
                .remove(item.ref.cacheKey, LibraryLists.watchlist),
          ),
          _ItemsGrid(
            asyncItems: ref.watch(favoritesProvider),
            formFactor: formFactor,
            emptyTitle: 'No favorites yet',
            emptyMessage: 'Tap the heart on a title to add it to favorites.',
            onRemove: (item) => ref
                .read(libraryRepoProvider)
                .remove(item.ref.cacheKey, LibraryLists.favorites),
          ),
          const _HistoryList(),
        ],
      ),
    );
  }
}

class _ItemsGrid extends StatelessWidget {
  const _ItemsGrid({
    required this.asyncItems,
    required this.formFactor,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRemove,
  });

  final AsyncValue<List<MediaItem>> asyncItems;
  final FormFactor formFactor;
  final String emptyTitle;
  final String emptyMessage;
  final void Function(MediaItem) onRemove;

  @override
  Widget build(BuildContext context) {
    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load',
        message: '$e',
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: emptyTitle,
            message: emptyMessage,
          );
        }
        final width = MediaQuery.sizeOf(context).width;
        final cols = Adaptive.gridColumns(formFactor, width);
        final cardWidth = (width - 40 - (cols - 1) * 12) / cols;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: cardWidth / (cardWidth * 1.5 + 52),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => GestureDetector(
            onLongPress: () => _confirmRemove(context, items[i]),
            child: PosterCard(
              item: items[i],
              width: cardWidth,
              onTap: () => context.openDetails(items[i].ref),
            ),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, MediaItem item) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove "${item.title}"?'),
        content: const Text('This removes it from this list only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onRemove(item);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyRepoProvider);
    return FutureBuilder<List<HistoryEntry>>(
      future: history.all(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No watch history',
            message: 'Titles you play will appear here with your resume point.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 92),
          itemBuilder: (context, i) {
            final e = entries[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              leading: SizedBox(
                width: 52,
                height: 78,
                child: PosterCard(
                  item: e.item,
                  width: 52,
                  showTitle: false,
                  progress: e.progress,
                  onTap: () => context.openDetails(e.item.ref),
                ),
              ),
              title: Text(e.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.episodeLabel.isNotEmpty) Text(e.episodeLabel),
                  const SizedBox(height: 4),
                  SlimProgressBar(value: e.progress),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDuration(Duration(milliseconds: e.positionMs))} '
                    'of ${formatDuration(Duration(milliseconds: e.durationMs))}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Remove from history',
                onPressed: () async {
                  await history.remove(e.item.ref.cacheKey);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from history')),
                    );
                  }
                },
              ),
              onTap: () => context.openDetails(e.item.ref),
            );
          },
        );
      },
    );
  }
}
