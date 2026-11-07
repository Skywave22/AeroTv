import 'dart:async';

import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';

/// Searching inside one provider, from the Browse tab's corner button.
///
/// Scoped to the browsed provider on purpose: the global Search tab already
/// queries everything installed, whereas SkyStream's own search stays inside
/// the site you are currently in. Same word, different scope, both useful.
class BrowseSearchOverlay extends ConsumerStatefulWidget {
  const BrowseSearchOverlay({super.key});

  @override
  ConsumerState<BrowseSearchOverlay> createState() =>
      _BrowseSearchOverlayState();
}

class _BrowseSearchOverlayState extends ConsumerState<BrowseSearchOverlay> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourceAsync = ref.watch(activeBrowseSourceProvider);
    final resultsAsync = ref.watch(browseSearchProvider);
    final formFactor =
        Adaptive.detect(context, isTv: ref.watch(isTvProvider));
    final pad = Adaptive.pagePadding(formFactor);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sourceAsync.valueOrNull == null
              ? 'Search'
              : 'Search ${sourceAsync.valueOrNull!.name}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                // Keep the shared query in sync so a rebuild or a back-nav
                // does not resurrect a stale result set.
                ref.read(browseSearchQueryProvider.notifier).state = v;
                _onChanged(v);
              },
              onSubmitted: (v) {
                _debounce?.cancel();
                ref.read(browseSearchQueryProvider.notifier).state = v;
                setState(() => _query = v.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search this provider',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          ref.read(browseSearchQueryProvider.notifier).state = '';
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Search failed',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(browseSearchProvider),
        ),
        data: (items) {
          if (_query.length < 2) {
            return const EmptyState(
              icon: Icons.search_rounded,
              title: 'Type at least two characters',
              message: 'Results come from the provider you are browsing.',
            );
          }
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nothing found',
              message: 'No results for "$_query" in this provider.',
            );
          }
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: Adaptive.posterWidth(formFactor) * 1.9,
              childAspectRatio: 0.58,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final source = sourceAsync.valueOrNull;
              return PosterCard(
                item: item,
                width: Adaptive.posterWidth(formFactor),
                onTap: () => context.openDetails(
                  item.ref,
                  sourceId: source?.id,
                  ecosystem: source?.ecosystem,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
