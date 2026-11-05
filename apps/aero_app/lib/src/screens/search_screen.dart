import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Debounce so we don't hammer every add-on on each keystroke.
    _debounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchEcosystemFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final sourcesAsync = ref.watch(installedSourcesProvider);
    final enabledCount = ref.watch(enabledSourceCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    ref.read(searchQueryProvider.notifier).state = v;
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search across your sources…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _controller.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              setState(() {});
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('All', filter.isEmpty, () {
                        ref.read(searchEcosystemFilterProvider.notifier).state = {};
                      }),
                      ...Ecosystem.values.map((e) {
                        final selected = filter.contains(e);
                        return _chip(e.displayName, selected, () {
                          final next = {...filter};
                          if (selected) {
                            next.remove(e);
                          } else {
                            next.add(e);
                          }
                          ref.read(searchEcosystemFilterProvider.notifier).state = next;
                        });
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load sources',
          message: '$e',
        ),
        data: (_) {
          if (enabledCount == 0) {
            return EmptyState(
              icon: Icons.extension_outlined,
              title: 'No sources enabled',
              message: 'Add and enable an add-on to search across it.',
              actionLabel: 'Add an add-on',
              onAction: () => context.openExtensions(),
            );
          }
          if (query.trim().length < 2) {
            return const EmptyState(
              icon: Icons.search_rounded,
              title: 'Search your sources',
              message:
                  'Type at least two characters. Results are merged and '
                  'de-duplicated across every enabled source.',
            );
          }
          return resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Search failed',
              message: '$e',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(searchResultsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No results for "$query"',
                  message:
                      'None of your enabled sources matched. Try a different '
                      'spelling, or enable more sources.',
                  actionLabel: 'Manage sources',
                  onAction: () => context.openExtensions(),
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
                  // poster 2:3 plus title space
                  childAspectRatio: cardWidth / (cardWidth * 1.5 + 52),
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => PosterCard(
                  item: items[i],
                  width: cardWidth,
                  reduceMotion: ui.reduceMotion,
                  onTap: () => context.openDetails(items[i].ref),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
