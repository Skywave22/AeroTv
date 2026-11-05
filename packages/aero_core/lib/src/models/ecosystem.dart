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
