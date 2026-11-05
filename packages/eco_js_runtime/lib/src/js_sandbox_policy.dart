/// Resource limits and permissions for one plugin context.
class JsSandboxPolicy {
  const JsSandboxPolicy({
    this.memoryLimitBytes = 32 * 1024 * 1024,
    this.stackSizeBytes = 1024 * 1024,
    this.evalTimeout = const Duration(seconds: 20),
    this.httpTimeout = const Duration(seconds: 15),
    this.maxConcurrentRequests = 4,
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.allowedSchemes = const ['https', 'http'],
    this.blockedHosts = const [
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      '169.254.169.254', // cloud metadata endpoint
      '::1',
      '10.0.0.0/8',
      '192.168.0.0/16',
    ],
    this.allowInsecureHttp = true,
    this.maxRedirects = 5,
  });

  final int memoryLimitBytes;
  final int stackSizeBytes;

  /// Hard wall-clock budget for a single plugin call.
  final Duration evalTimeout;
  final Duration httpTimeout;
  final int maxConcurrentRequests;
  final int maxResponseBytes;
  final List<String> allowedSchemes;

  /// SSRF guard: plugins must not reach the LAN or device-local services.
  final List<String> blockedHosts;
  final bool allowInsecureHttp;
  final int maxRedirects;

  /// Validates a plugin-requested URL. Returns null when allowed, or a
  /// human-readable reason when blocked.
  String? validateUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return 'Invalid URL';
    if (!allowedSchemes.contains(uri.scheme)) {
      return 'Scheme "${uri.scheme}" is not permitted';
    }
    if (uri.scheme == 'http' && !allowInsecureHttp) {
      return 'Plain HTTP is disabled in settings';
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return 'Missing host';
    for (final blocked in blockedHosts) {
      if (blocked.contains('/')) {
        // CIDR-ish prefix guard for private ranges.
        final prefix = blocked.split('/').first;
        final octets = prefix.split('.').take(2).join('.');
        if (host.startsWith(octets)) return 'Private network access is blocked';
      } else if (host == blocked || host.endsWith('.$blocked')) {
        return 'Host "$host" is blocked';
      }
    }
    // Block obvious local hostnames.
    if (host.endsWith('.local') || host.endsWith('.internal')) {
      return 'Local network access is blocked';
    }
    return null;
  }

  JsSandboxPolicy copyWith({
    int? memoryLimitBytes,
    Duration? evalTimeout,
    Duration? httpTimeout,
    bool? allowInsecureHttp,
    int? maxConcurrentRequests,
  }) =>
      JsSandboxPolicy(
        memoryLimitBytes: memoryLimitBytes ?? this.memoryLimitBytes,
        stackSizeBytes: stackSizeBytes,
        evalTimeout: evalTimeout ?? this.evalTimeout,
        httpTimeout: httpTimeout ?? this.httpTimeout,
        maxConcurrentRequests: maxConcurrentRequests ?? this.maxConcurrentRequests,
        maxResponseBytes: maxResponseBytes,
        allowedSchemes: allowedSchemes,
        blockedHosts: blockedHosts,
        allowInsecureHttp: allowInsecureHttp ?? this.allowInsecureHttp,
        maxRedirects: maxRedirects,
      );
}
