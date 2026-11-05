import 'ecosystem.dart';
import 'subtitle.dart';

/// How the URL must be handled by the player.
enum StreamKind {
  direct,
  hls,
  dash,
  torrent,
  youtube,
  external;

  bool get isPlayableByPlayer =>
      this == StreamKind.direct || this == StreamKind.hls || this == StreamKind.dash;
}

/// Video quality bucket, ordered worst → best so comparisons are trivial.
enum Quality implements Comparable<Quality> {
  unknown(0, 'Unknown'),
  sd(480, '480p'),
  hd(720, '720p'),
  fullHd(1080, '1080p'),
  qhd(1440, '1440p'),
  uhd(2160, '4K');

  const Quality(this.height, this.label);

  final int height;
  final String label;

  @override
  int compareTo(Quality other) => height.compareTo(other.height);

  bool operator >(Quality other) => height > other.height;
  bool operator <(Quality other) => height < other.height;
  bool operator >=(Quality other) => height >= other.height;
  bool operator <=(Quality other) => height <= other.height;

  /// Parses quality out of messy provider text like "1080p WEB-DL x265".
  static Quality parse(String? text) {
    if (text == null || text.isEmpty) return Quality.unknown;
    final t = text.toLowerCase();
    if (t.contains('2160') || t.contains('4k') || t.contains('uhd')) return Quality.uhd;
    if (t.contains('1440') || t.contains('2k') || t.contains('qhd')) return Quality.qhd;
    if (t.contains('1080') || t.contains('fullhd') || t.contains('fhd')) {
      return Quality.fullHd;
    }
    if (t.contains('720') || RegExp(r'\bhd\b').hasMatch(t)) return Quality.hd;
    if (t.contains('480') || t.contains('360') || RegExp(r'\bsd\b').hasMatch(t)) {
      return Quality.sd;
    }
    final m = RegExp(r'(\d{3,4})\s*p\b').firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1)!) ?? 0;
      if (h >= 2000) return Quality.uhd;
      if (h >= 1400) return Quality.qhd;
      if (h >= 1000) return Quality.fullHd;
      if (h >= 700) return Quality.hd;
      if (h > 0) return Quality.sd;
    }
    return Quality.unknown;
  }
}

/// A playable link, normalised across all five ecosystems.
class StreamLink {
  const StreamLink({
    required this.url,
    required this.sourceId,
    required this.sourceName,
    required this.ecosystem,
    this.kind = StreamKind.direct,
    this.quality = Quality.unknown,
    this.title,
    this.description,
    this.sizeBytes,
    this.language,
    this.headers = const {},
    this.subtitles = const [],
    this.bingeGroup,
    this.infoHash,
    this.fileIdx,
    this.notWebReady = false,
    this.isHdr = false,
    this.codec,
    this.latencyMs,
    this.debrid = false,
  });

  final String url;
  final String sourceId;
  final String sourceName;
  final Ecosystem ecosystem;
  final StreamKind kind;
  final Quality quality;

  /// Provider-supplied short name, usually the quality line.
  final String? title;
  final String? description;
  final int? sizeBytes;
  final String? language;

  /// Headers required to make the URL play (Referer, User-Agent, cookies...).
  final Map<String, String> headers;
  final List<SubtitleTrack> subtitles;
  final String? bingeGroup;
  final String? infoHash;
  final int? fileIdx;
  final bool notWebReady;
  final bool isHdr;
  final String? codec;
  final int? latencyMs;

  /// True when a debrid service already resolved the torrent to a direct URL.
  final bool debrid;

  String get sourceKey => '${ecosystem.id}:$sourceId';

  bool get isPlayable => kind.isPlayableByPlayer && url.isNotEmpty;

  bool get isTorrent => infoHash != null && infoHash!.isNotEmpty;

  /// Human-readable size, e.g. "1.4 GB".
  String? get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = b.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  /// Text the quality parser should inspect.
  String get qualityHint =>
      [title, description, url].whereType<String>().join(' ');

  StreamLink copyWith({
    Quality? quality,
    int? sizeBytes,
    Map<String, String>? headers,
    List<SubtitleTrack>? subtitles,
    int? latencyMs,
    StreamKind? kind,
    String? language,
  }) =>
      StreamLink(
        url: url,
        sourceId: sourceId,
        sourceName: sourceName,
        ecosystem: ecosystem,
        kind: kind ?? this.kind,
        quality: quality ?? this.quality,
        title: title,
        description: description,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        language: language ?? this.language,
        headers: headers ?? this.headers,
        subtitles: subtitles ?? this.subtitles,
        bingeGroup: bingeGroup,
        infoHash: infoHash,
        fileIdx: fileIdx,
        notWebReady: notWebReady,
        isHdr: isHdr,
        codec: codec,
        latencyMs: latencyMs ?? this.latencyMs,
        debrid: debrid,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'ecosystem': ecosystem.id,
        'kind': kind.name,
        'quality': quality.name,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (language != null) 'language': language,
        'headers': headers,
        'subtitles': subtitles.map((s) => s.toJson()).toList(),
        if (bingeGroup != null) 'bingeGroup': bingeGroup,
        if (infoHash != null) 'infoHash': infoHash,
        if (fileIdx != null) 'fileIdx': fileIdx,
        'notWebReady': notWebReady,
        'isHdr': isHdr,
        if (codec != null) 'codec': codec,
        if (latencyMs != null) 'latencyMs': latencyMs,
        'debrid': debrid,
      };

  factory StreamLink.fromJson(Map<String, dynamic> j) => StreamLink(
        url: (j['url'] ?? '').toString(),
        sourceId: (j['sourceId'] ?? '').toString(),
        sourceName: (j['sourceName'] ?? '').toString(),
        ecosystem: Ecosystem.fromId(j['ecosystem'] as String),
        kind: StreamKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => StreamKind.direct,
        ),
        quality: Quality.values.firstWhere(
          (q) => q.name == j['quality'],
          orElse: () => Quality.unknown,
        ),
        title: j['title'] as String?,
        description: j['description'] as String?,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        language: j['language'] as String?,
        headers: Map<String, String>.from(
          (j['headers'] as Map? ?? const {}).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ),
        ),
        subtitles: (j['subtitles'] as List?)
                ?.map((e) =>
                    SubtitleTrack.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        bingeGroup: j['bingeGroup'] as String?,
        infoHash: j['infoHash'] as String?,
        fileIdx: (j['fileIdx'] as num?)?.toInt(),
        notWebReady: j['notWebReady'] as bool? ?? false,
        isHdr: j['isHdr'] as bool? ?? false,
        codec: j['codec'] as String?,
        latencyMs: (j['latencyMs'] as num?)?.toInt(),
        debrid: j['debrid'] as bool? ?? false,
      );

  @override
  String toString() =>
      'StreamLink(${quality.label}, $sourceName, ${kind.name}, $url)';
}
