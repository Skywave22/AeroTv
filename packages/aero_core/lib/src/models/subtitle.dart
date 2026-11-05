/// An external subtitle track offered by a source.
class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    required this.url,
    required this.lang,
    this.label,
    this.format,
    this.sourceKey,
  });

  final String id;
  final String url;

  /// ISO 639 code when known, otherwise the raw provider string.
  final String lang;
  final String? label;

  /// srt / vtt / ass / ssa — inferred from the URL when absent.
  final String? format;
  final String? sourceKey;

  String get displayLabel => label ?? lang.toUpperCase();

  String get resolvedFormat =>
      (format ?? _guessFormat(url)).toLowerCase().replaceAll('.', '');

  static String _guessFormat(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in ['.srt', '.vtt', '.ass', '.ssa', '.ttml', '.sub']) {
      if (path.endsWith(ext)) return ext.substring(1);
    }
    return 'srt';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'lang': lang,
        if (label != null) 'label': label,
        if (format != null) 'format': format,
        if (sourceKey != null) 'sourceKey': sourceKey,
      };

  factory SubtitleTrack.fromJson(Map<String, dynamic> j) => SubtitleTrack(
        id: (j['id'] ?? j['url'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        lang: (j['lang'] ?? 'und').toString(),
        label: j['label'] as String?,
        format: j['format'] as String?,
        sourceKey: j['sourceKey'] as String?,
      );
}
