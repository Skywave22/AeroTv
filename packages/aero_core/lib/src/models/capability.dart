/// What a source can do. Adapters declare these so the resolver only fans out
/// to sources that can actually answer a request.
enum Capability { catalogs, search, meta, streams, subtitles }

/// How a plugin bundle is delivered and executed.
enum SourceRuntime { http, javaScript, nativeDex }
