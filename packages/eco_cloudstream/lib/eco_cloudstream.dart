/// CloudStream (.cs3) bridge — Android only, and **disabled by default**.
///
/// IMPORTANT: CloudStream is GPL-3.0. Linking its API classes into this app
/// would very likely require the whole app to be GPL-3.0. This package
/// therefore ships only the Dart-side contract and a channel client; the
/// native Kotlin host is NOT included and must be added deliberately after
/// the licensing decision is made. See docs/specs/cloudstream.md and
/// docs/LEGAL.md.
library;

export 'src/cloudstream_adapter.dart';
export 'src/cloudstream_channel.dart';
