import 'package:eco_js_runtime/eco_js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security regression suite for the plugin SSRF guard.
///
/// The previous guard compared the first two octets of a network address as a
/// string, so 10.1.2.3 passed a 10.0.0.0/8 block and 172.16/12 was absent
/// entirely. These cases are the ones that actually leaked.
void main() {
  const policy = JsSandboxPolicy();

  group('IPv4 private and reserved ranges are blocked', () {
    const blocked = [
      '0.0.0.0', '0.1.2.3',
      '10.0.0.5', '10.1.2.3', '10.255.1.1', '10.255.255.255',
      '100.64.0.1', '100.127.255.254',
      '127.0.0.1', '127.1.2.3',
      '169.254.169.254', '169.254.1.1',
      '172.16.0.1', '172.20.5.5', '172.31.255.254',
      '192.0.0.1', '192.168.0.1', '192.168.1.50', '192.168.255.255',
      '198.18.0.1', '198.19.5.5',
      '224.0.0.1', '239.1.1.1',
      '240.0.0.1', '255.255.255.255',
    ];
    for (final ip in blocked) {
      test('$ip is refused', () {
        expect(policy.validateUrl('http://$ip/x'), isNotNull, reason: ip);
      });
    }
  });

  group('Public IPv4 is allowed', () {
    const allowed = [
      '8.8.8.8', '1.1.1.1', '93.184.216.34',
      '11.0.0.1', // just outside 10/8
      '100.63.255.255', // just below CGNAT
      '100.128.0.1', // just above CGNAT
      '172.15.255.255', // just below 172.16/12
      '172.32.0.1', // just above 172.16/12
      '192.169.1.1', // just outside 192.168/16
      '198.17.255.255', '198.20.0.1',
    ];
    for (final ip in allowed) {
      test('$ip is permitted', () {
        expect(policy.validateUrl('http://$ip/x'), isNull, reason: ip);
      });
    }
  });

  group('IPv6 literals', () {
    const blocked = [
      '[::1]', '[::]', '[fc00::1]', '[fd00::1]', '[fdff::1]',
      '[fe80::1]', '[feb0::1]', '[ff02::1]',
      '[::ffff:192.168.1.1]', '[::ffff:127.0.0.1]', '[::ffff:10.1.2.3]',
    ];
    for (final h in blocked) {
      test('$h is refused', () {
        expect(policy.validateUrl('http://$h/x'), isNotNull, reason: h);
      });
    }

    test('a public IPv6 address is permitted', () {
      expect(policy.validateUrl('http://[2606:4700:4700::1111]/x'), isNull);
    });

    test('a mapped public IPv4 is permitted', () {
      expect(policy.validateUrl('http://[::ffff:8.8.8.8]/x'), isNull);
    });
  });

  group('Obfuscated IPv4 forms are refused', () {
    // Some stacks read these as 127.0.0.1; a naive string check misses them.
    const forms = ['2130706433', '0x7f000001', '0177.0.0.1', '127.1'];
    for (final f in forms) {
      test('$f is refused', () {
        expect(policy.validateUrl('http://$f/x'), isNotNull, reason: f);
      });
    }
  });

  group('Hostnames and schemes', () {
    test('local and metadata names are refused', () {
      for (final h in [
        'localhost', 'printer.local', 'router.internal',
        'metadata.google.internal', 'metadata', 'sub.localhost',
      ]) {
        expect(policy.validateUrl('http://$h/x'), isNotNull, reason: h);
      }
    });

    test('non-http schemes are refused', () {
      for (final u in [
        'file:///etc/passwd', 'ftp://x.com/a', 'javascript:alert(1)',
        'data:text/html,hi', 'gopher://x.com/',
      ]) {
        expect(policy.validateUrl(u), isNotNull, reason: u);
      }
    });

    test('a normal public URL is permitted', () {
      expect(policy.validateUrl('https://example.com/path?q=1'), isNull);
    });

    test('plain HTTP can be disabled by policy', () {
      const strict = JsSandboxPolicy(allowInsecureHttp: false);
      expect(strict.validateUrl('http://example.com/x'), isNotNull);
      expect(strict.validateUrl('https://example.com/x'), isNull);
    });
  });

  group('IpGuard parsing', () {
    test('parses dotted quads correctly', () {
      expect(IpGuard.parseV4('0.0.0.0'), 0);
      expect(IpGuard.parseV4('255.255.255.255'), 0xFFFFFFFF);
      expect(IpGuard.parseV4('192.168.1.1'), 0xC0A80101);
    });

    test('rejects malformed and non-decimal octets', () {
      for (final bad in ['1.2.3', '1.2.3.4.5', '256.1.1.1', '-1.0.0.0', '010.0.0.1', '0x7f.0.0.1', 'a.b.c.d', '']) {
        expect(IpGuard.parseV4(bad), isNull, reason: bad);
      }
    });

    test('CIDR boundaries are exact', () {
      expect(IpGuard.isBlockedV4(IpGuard.parseV4('10.255.255.255')!), isTrue);
      expect(IpGuard.isBlockedV4(IpGuard.parseV4('11.0.0.0')!), isFalse);
      expect(IpGuard.isBlockedV4(IpGuard.parseV4('172.31.255.255')!), isTrue);
      expect(IpGuard.isBlockedV4(IpGuard.parseV4('172.32.0.0')!), isFalse);
    });
  });

  group('DNS-rebinding defence', () {
    test('a literal private address is refused without any lookup', () async {
      expect(await policy.validateUrlResolved('http://192.168.1.1/x'), isNotNull);
    });

    test('localhost is refused without any lookup', () async {
      expect(await policy.validateUrlResolved('http://localhost/x'), isNotNull);
    });

    test('resolution can be disabled for offline tests', () async {
      const offline = JsSandboxPolicy(resolveDns: false);
      // A public-looking name passes the literal checks and is not resolved.
      expect(await offline.validateUrlResolved('https://nonexistent.invalid/x'), isNull);
      // Private literals are still refused even with resolution off.
      expect(await offline.validateUrlResolved('http://10.1.2.3/x'), isNotNull);
    });
  });
}
