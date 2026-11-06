import 'dart:async';
import 'dart:io';

/// IP-range matching for the plugin SSRF guard.
///
/// The previous implementation compared the first two octets of a network
/// address as a string, which let `10.1.2.3` through a `10.0.0.0/8` block and
/// had no `172.16.0.0/12` entry at all. This does real integer CIDR matching.
abstract final class IpGuard {
  /// IPv4 ranges a plugin must never reach.
  static const List<(int, int)> _blockedV4Cidrs = [
    (0x00000000, 8), // "this network"
    (0x0A000000, 8), // private
    (0x64400000, 10), // CGNAT 100.64/10
    (0x7F000000, 8), // loopback
    (0xA9FE0000, 16), // link-local incl. cloud metadata
    (0xAC100000, 12), // private 172.16/12
    (0xC0000000, 24), // IETF protocol assignments
    (0xC0A80000, 16), // private 192.168/16
    (0xC6120000, 15), // benchmarking 198.18/15
    (0xE0000000, 4), // multicast
    (0xF0000000, 4), // reserved incl. broadcast
  ];

  /// Parses a dotted-quad into a 32-bit int, or null if it is not IPv4.
  static int? parseV4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;
    var value = 0;
    for (final p in parts) {
      if (p.isEmpty || p.length > 3) return null;
      final n = int.tryParse(p);
      // Reject non-decimal and leading-zero forms (010, 0x7f) that some
      // resolvers interpret as octal/hex and would bypass a naive check.
      if (n == null || n < 0 || n > 255) return null;
      if (p.length > 1 && p.startsWith('0')) return null;
      if (!p.codeUnits.every((c) => c >= 0x30 && c <= 0x39)) return null;
      value = (value << 8) | n;
    }
    return value;
  }

  static bool _inV4Cidr(int ip, int network, int bits) {
    if (bits == 0) return true;
    final mask = (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
    return (ip & mask) == (network & mask);
  }

  /// True when [ip] is an IPv4 address inside a blocked range.
  static bool isBlockedV4(int ip) =>
      _blockedV4Cidrs.any((c) => _inV4Cidr(ip, c.$1, c.$2));

  /// True when [host] is a literal IPv6 address that must not be reached:
  /// loopback, unspecified, ULA (fc00::/7), link-local (fe80::/10), or an
  /// IPv4-mapped address whose embedded IPv4 is itself blocked.
  static bool isBlockedV6Literal(String host) {
    final h = host.toLowerCase();
    if (!h.contains(':')) return false;

    // IPv4-mapped / -compatible, e.g. ::ffff:192.168.1.1
    final lastColon = h.lastIndexOf(':');
    final tail = h.substring(lastColon + 1);
    if (tail.contains('.')) {
      final v4 = parseV4(tail);
      if (v4 != null) return isBlockedV4(v4);
      return true; // malformed mapped form: refuse rather than guess
    }

    if (h == '::' || h == '::1') return true;

    final firstGroup = h.split(':').first;
    if (firstGroup.isEmpty) return true; // ::… handled above
    final head = int.tryParse(firstGroup, radix: 16);
    if (head == null) return true;
    if ((head & 0xFE00) == 0xFC00) return true; // fc00::/7 ULA
    if ((head & 0xFFC0) == 0xFE80) return true; // fe80::/10 link-local
    if ((head & 0xFF00) == 0xFF00) return true; // multicast
    return false;
  }

  /// Checks a host string that may be an IP literal. Returns a reason when
  /// blocked, null when the literal is public (or is a name, which needs DNS).
  static String? checkLiteral(String host) {
    final h = host.toLowerCase();
    final v4 = parseV4(h);
    if (v4 != null) {
      return isBlockedV4(v4) ? 'Private or reserved network access is blocked' : null;
    }
    if (h.contains(':')) {
      return isBlockedV6Literal(h)
          ? 'Private or reserved network access is blocked'
          : null;
    }
    // Decimal / hex single-integer forms of an IPv4 address (2130706433,
    // 0x7f000001). Some stacks accept these; treat them as hostile.
    final asInt = int.tryParse(h) ??
        (h.startsWith('0x') ? int.tryParse(h.substring(2), radix: 16) : null);
    if (asInt != null && asInt >= 0 && asInt <= 0xFFFFFFFF) {
      return isBlockedV4(asInt)
          ? 'Private or reserved network access is blocked'
          : 'Numeric host forms are not permitted';
    }

    // Any other all-numeric dotted form is an obfuscated or short IPv4 that
    // some resolvers still accept: octal (0177.0.0.1), hex (0x7f.0.0.1), or
    // short (127.1). parseV4 deliberately rejects them, so refuse here rather
    // than letting them through as if they were ordinary hostnames.
    if (RegExp(r'^[0-9a-fx.]+$').hasMatch(h) && h.contains('.')) {
      final labels = h.split('.');
      if (labels.every((l) =>
          l.isNotEmpty &&
          (int.tryParse(l) != null ||
              (l.startsWith('0x') && int.tryParse(l.substring(2), radix: 16) != null)))) {
        return 'Ambiguous numeric host forms are not permitted';
      }
    }
    return null;
  }

  /// Resolves [host] and checks every resulting address.
  ///
  /// This is the DNS-rebinding defence: a public name that resolves to
  /// 192.168.1.1 must be refused, not just a literal private IP. Returns a
  /// reason when blocked or unresolvable, null when every address is public.
  static Future<String?> checkResolved(String host) async {
    final literal = checkLiteral(host);
    if (literal != null) return literal;
    if (parseV4(host) != null || host.contains(':')) return null;

    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      if (addresses.isEmpty) return 'Host did not resolve';
      for (final a in addresses) {
        final r = checkLiteral(a.address);
        if (r != null) {
          return 'Host resolves to a private or reserved address';
        }
      }
      return null;
    } on SocketException {
      return 'Host did not resolve';
    } on TimeoutException {
      return 'Host lookup timed out';
    } catch (_) {
      // Fail closed: if we cannot verify the destination, do not connect.
      return 'Could not verify the host address';
    }
  }
}
