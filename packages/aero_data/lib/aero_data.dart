/// Persistence layer: Drift/SQLite, repositories, cache and secure settings.
library;

export 'src/db/database.dart';
export 'src/db/tables.dart';
export 'src/repos/source_repository.dart';
export 'src/repos/library_repository.dart';
export 'src/repos/history_repository.dart';
export 'src/repos/health_repository.dart';
export 'src/repos/cache_repository.dart';
export 'src/repos/match_repository.dart';
export 'src/repos/plugin_log_repository.dart';
export 'src/repos/tmdb_id_lookup.dart';
export 'src/settings/settings_repository.dart';
export 'src/settings/secure_credentials.dart';
export 'src/backup_service.dart';
export 'src/pairing/pairing_server.dart';
