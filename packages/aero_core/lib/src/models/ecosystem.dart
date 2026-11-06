/// The five plugin ecosystems Aero TV treats as first-class citizens.
enum Ecosystem {
  stremio('stremio', 'Stremio', 'Add-ons'),
  vega('vega', 'Vega', 'Providers'),
  nuvio('nuvio', 'Nuvio', 'Scrapers'),
  skystream('skystream', 'SkyStream', 'Plugins'),
  cloudstream('cloudstream', 'CloudStream', 'Plugins');

  const Ecosystem(this.id, this.displayName, this.sourceNoun);

  final String id;
  final String displayName;

  /// What this ecosystem calls an installed unit ("Add-ons", "Providers", ...).
  final String sourceNoun;

  /// Ecosystems whose plugins are JavaScript and run in the QuickJS host.
  bool get isJsBased =>
      this == Ecosystem.vega || this == Ecosystem.nuvio || this == Ecosystem.skystream;

  /// CloudStream ships compiled Kotlin/DEX and therefore needs a native host.
  bool get requiresNativeHost => this == Ecosystem.cloudstream;

  /// Whether this ecosystem's units contribute catalogues to the unified Home
  /// feed, as opposed to being standalone providers you open one at a time.
  ///
  /// Add-ons are fragments of one catalogue: several installed together are
  /// meant to merge into a single home. A SkyStream or Vega provider is a
  /// whole site with its own categories and ordering, so flattening several of
  /// them into Home produces an incoherent feed — those are browsed
  /// individually instead. Nuvio has no catalogue API at all.
  ///
  /// Expressed here, as a property of the ecosystem, so nothing above the
  /// adapter layer has to branch on an ecosystem name.
  bool get mergesIntoHome => this == Ecosystem.stremio;

  /// Not usable yet, but visible so the user knows it is coming rather than
  /// wondering why it is missing. CloudStream ships compiled Kotlin/DEX and
  /// needs a native host that has not landed.
  bool get isBeta => this == Ecosystem.cloudstream;

  /// Whether this ecosystem is presented as a browsable provider with its own
  /// home page. The complement of [mergesIntoHome] for anything that has
  /// catalogues; Nuvio has neither.
  bool get isStandaloneProvider =>
      this == Ecosystem.vega ||
      this == Ecosystem.skystream ||
      this == Ecosystem.cloudstream;

  /// Badge color seed, kept here so UI and logs agree.
  int get colorSeed => switch (this) {
        Ecosystem.stremio => 0xFF7B5CFF,
        Ecosystem.vega => 0xFF00C2A8,
        Ecosystem.nuvio => 0xFFFF8A3D,
        Ecosystem.skystream => 0xFF3DA5FF,
        Ecosystem.cloudstream => 0xFFFF5C7A,
      };

  static Ecosystem fromId(String id) => Ecosystem.values.firstWhere(
        (e) => e.id == id,
        orElse: () => throw ArgumentError('Unknown ecosystem: $id'),
      );

  static Ecosystem? tryFromId(String? id) {
    if (id == null) return null;
    for (final e in Ecosystem.values) {
      if (e.id == id) return e;
    }
    return null;
  }
}
