import '../models/capability.dart';
import '../models/catalog.dart';
import '../models/ecosystem.dart';
import '../models/media.dart';
import '../models/play_request.dart';
import '../models/source.dart';
import '../models/stream_link.dart';
import '../models/subtitle.dart';
import '../util/result.dart';

/// The contract every ecosystem implements.
///
/// Implementations must be **defensive**: a broken third-party plugin should
/// produce an [Err] or an empty page, never an unhandled exception that takes
/// down the UI. Methods that a source cannot serve should return empty data
/// rather than throwing.
abstract class EcosystemAdapter {
  Ecosystem get ecosystem;

  /// What this adapter can do on the current platform.
  Set<Capability> get capabilities;

  /// False when the ecosystem needs a host that this platform lacks
  /// (CloudStream off Android).
  bool get isAvailable;

  /// Human-readable reason shown in the greyed-out Extensions Manager section.
  String? get unavailableReason => null;

  Future<List<InstalledSource>> installedSources();

  /// Fetches the manifest/bundle, validates it, and persists it.
  Future<Result<InstalledSource>> install(SourceRef ref);


  Future<void> uninstall(String sourceId);

  /// Re-reads the remote manifest and reports whether a newer version exists.
  Future<Result<InstalledSource>> checkUpdate(String sourceId);

  /// Lightweight reachability probe used by the health check button.
  Future<Result<Duration>> healthCheck(String sourceId);

  Future<List<CatalogRow>> catalogs(String sourceId);

  Future<Page<MediaItem>> browse(String sourceId, String catalogId, CatalogQuery q);

  Future<Page<MediaItem>> search(String sourceId, String query);

  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref);

  /// Emits links **as they are found** so the source sheet fills progressively.
  Stream<StreamLink> streams(String sourceId, PlayRequest req);

  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req);

  /// Releases native/JS resources. Called on app shutdown and on uninstall.
  Future<void> dispose();
}

/// Optional capability: this ecosystem distributes plugins through a
/// repository index that can be listed before anything is installed.
///
/// Kept separate from [EcosystemAdapter] on purpose. Adding members to the base
/// interface would break every `implements EcosystemAdapter` — including
/// single-URL ecosystems that have no notion of a repository. Managers detect
/// support with `adapter is RepositorySource`.
abstract interface class RepositorySource {
  /// Reads a repository index and returns the plugins it offers, installing
  /// nothing.
  ///
  /// Formats differ per ecosystem: SkyStream `repo.json`, Vega an array
  /// `manifest.json`, Nuvio an object `manifest.json` listing scrapers. Each
  /// adapter parses its own; the manager UI stays generic.
  Future<Result<List<SourceRef>>> fetchRepository(String url);
}
