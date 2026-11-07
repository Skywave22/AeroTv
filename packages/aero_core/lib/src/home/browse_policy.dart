import '../models/capability.dart';
import '../models/ecosystem.dart';
import '../models/source.dart';

/// Which ecosystems are browsable, and which only contribute pieces.
///
/// This is the single place the product's rule lives, expressed as a property
/// of the ecosystem rather than as name checks scattered through the UI:
///
/// * **Browse** is SkyStream's own experience — a whole site per provider, so
///   it is offered by SkyStream, Vega and CloudStream.
/// * **Home** is a merged feed: TMDB rows plus Stremio add-on catalogues.
///   Add-ons are fragments of one catalogue, so they belong there.
/// * **Nuvio** has no catalogue API at all. Its scrapers are streams-only and
///   therefore appear in the play sheet, never as a page to browse.
///
/// Keeping the policy here means the tabs cannot drift apart again: a future
/// ecosystem declares its role once and every screen follows.
abstract final class BrowsePolicy {
  /// Ecosystems presented as browsable providers in the Browse tab, in the
  /// order they are usually installed.
  static const List<Ecosystem> browsable = [
    Ecosystem.skystream,
    Ecosystem.vega,
    Ecosystem.cloudstream,
  ];

  /// Ecosystems whose catalogues merge into the Home feed.
  static const List<Ecosystem> homeFeed = [Ecosystem.stremio];

  /// Ecosystems that only ever supply streams.
  static const List<Ecosystem> streamsOnly = [Ecosystem.nuvio];

  /// Sources the Browse tab may list and open.
  ///
  /// Requires the catalogs capability as well as the ecosystem role: a
  /// CloudStream section exists before its native host lands, but nothing in it
  /// can be opened until the adapter reports the capability.
  static List<InstalledSource> browsableSources(
    List<InstalledSource> all, {
    Set<Ecosystem> unavailable = const {},
  }) {
    final out = all
        .where((s) =>
            browsable.contains(s.ecosystem) &&
            !unavailable.contains(s.ecosystem) &&
            s.can(Capability.catalogs))
        .toList()
      ..sort(_byPriority);
    return out;
  }

  /// Sources that may fill Home with catalogue rows.
  static List<InstalledSource> homeSources(
    List<InstalledSource> all, {
    Set<Ecosystem> unavailable = const {},
    int maxSources = 8,
  }) {
    final out = all
        .where((s) =>
            homeFeed.contains(s.ecosystem) &&
            s.enabled &&
            !unavailable.contains(s.ecosystem) &&
            s.can(Capability.catalogs))
        .toList()
      ..sort(_byPriority);
    return out.take(maxSources).toList();
  }

  /// Sources the play sheet fans out to: everything with the streams
  /// capability, which is exactly "Stremio add-ons and Nuvio scrapers" today.
  static List<InstalledSource> streamSources(
    List<InstalledSource> all, {
    Set<Ecosystem> unavailable = const {},
  }) {
    final out = all
        .where((s) =>
            s.enabled &&
            !unavailable.contains(s.ecosystem) &&
            s.can(Capability.streams))
        .toList()
      ..sort(_byPriority);
    return out;
  }

  /// True when [ecosystem] is a Browse destination at all, regardless of what
  /// the user has installed. Drives whether an empty section is offered.
  static bool isBrowsableEcosystem(Ecosystem ecosystem) =>
      browsable.contains(ecosystem);

  /// Why an ecosystem is not in Browse, for the strip under the tab.
  static String? absentReason(Ecosystem ecosystem) => switch (ecosystem) {
        Ecosystem.stremio =>
          'Add-ons fill Home; their catalogue works there, not here.',
        Ecosystem.nuvio =>
          'Scrapers supply streams only — they appear when you play something.',
        _ => null,
      };

  static int _byPriority(InstalledSource a, InstalledSource b) {
    if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
    return a.priority.compareTo(b.priority);
  }
}
