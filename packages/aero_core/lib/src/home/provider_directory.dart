/// Groups installed sources into the Browse directory's sections.
///
/// Browse is an extension list, the way SkyStream presents its own: a section
/// per ecosystem, that ecosystem's providers underneath, and an "add" action
/// even when the section is empty so it is discoverable before anything is
/// installed.
///
/// Ordering and gating live here so they can be tested without a widget tree.
library;

import '../models/capability.dart';
import '../models/ecosystem.dart';
import '../models/source.dart';

class ProviderSection {
  const ProviderSection({
    required this.ecosystem,
    required this.sources,
    this.unavailableReason,
  });

  final Ecosystem ecosystem;
  final List<InstalledSource> sources;

  /// Set when the adapter cannot run on this platform.
  final String? unavailableReason;

  bool get isEmpty => sources.isEmpty;

  /// Shown but not openable: the ecosystem is announced, not yet usable.
  bool get isBeta => ecosystem.isBeta;

  /// Streams-only ecosystems have nothing to browse; they are listed to
  /// explain their absence from the browsable sections rather than to open.
  bool get isStreamsOnly => !ecosystem.mergesIntoHome &&
      !ecosystem.isStandaloneProvider;

  /// Whether a row in this section can be opened as a provider page.
  bool get isOpenable =>
      !isBeta && !isStreamsOnly && unavailableReason == null;

  String get title => ecosystem.displayName;

  String get noun => ecosystem.sourceNoun;

  String get note {
    if (isBeta) return 'Beta soon';
    if (unavailableReason != null) return unavailableReason!;
    if (isStreamsOnly) {
      return 'Streams only — these appear in the source picker when you play '
          'something. Metadata comes from TMDB.';
    }
    if (ecosystem.mergesIntoHome) {
      return 'Catalogues from these also appear on Home.';
    }
    return 'Each provider has its own categories and layout.';
  }
}

abstract final class ProviderDirectory {
  /// Section order. The standalone providers a user browses come first, in
  /// the order they are usually installed; add-ons follow because their
  /// content is already on Home; streams-only scrapers come last as an
  /// explanation rather than a destination.
  static const List<Ecosystem> order = [
    Ecosystem.skystream,
    Ecosystem.vega,
    Ecosystem.cloudstream,
    Ecosystem.stremio,
    Ecosystem.nuvio,
  ];

  static List<ProviderSection> build(
    List<InstalledSource> all, {
    Map<Ecosystem, String> unavailable = const {},
    bool includeEmpty = true,
  }) {
    final out = <ProviderSection>[];
    for (final eco in order) {
      final sources = all.where((s) => s.ecosystem == eco).toList()
        ..sort((a, b) {
          // Enabled first, then the user's own ordering.
          if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
          return a.priority.compareTo(b.priority);
        });
      final beta = eco.isBeta;
      // An empty section is worth showing when the user could still add to
      // it. A beta section is always shown, empty or not: that is the point.
      if (sources.isEmpty && !includeEmpty && !beta) continue;
      out.add(ProviderSection(
        ecosystem: eco,
        sources: sources,
        unavailableReason: beta ? null : unavailable[eco],
      ));
    }
    return out;
  }

  /// Whether a source can be opened as a provider page right now.
  static bool canOpen(InstalledSource s,
      {Map<Ecosystem, String> unavailable = const {}}) {
    if (s.ecosystem.isBeta) return false;
    if (unavailable.containsKey(s.ecosystem)) return false;
    return s.can(Capability.catalogs);
  }
}
