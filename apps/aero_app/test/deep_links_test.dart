import 'package:aero_app/src/services/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normaliseAddonLink', () {
    test('rewrites stremio:// to https and appends manifest.json', () {
      expect(
        DeepLinkService.normaliseAddonLink('stremio://addon.example/config'),
        'https://addon.example/config/manifest.json',
      );
    });

    test('does not double-append when the link already names the manifest', () {
      expect(
        DeepLinkService.normaliseAddonLink('stremio://addon.example/manifest.json'),
        'https://addon.example/manifest.json',
      );
    });

    test('handles a trailing slash', () {
      expect(
        DeepLinkService.normaliseAddonLink('stremio://addon.example/'),
        isNull,
        reason: 'a bare host is not an add-on',
      );
      expect(
        DeepLinkService.normaliseAddonLink('stremio://addon.example/config/'),
        'https://addon.example/config/manifest.json',
      );
    });

    test('accepts the app\'s own scheme', () {
      expect(
        DeepLinkService.normaliseAddonLink('aerotv://addon.example/config'),
        'https://addon.example/config/manifest.json',
      );
    });

    test('preserves a configuration token in the path', () {
      expect(
        DeepLinkService.normaliseAddonLink('stremio://addon.example/abc123/manifest.json'),
        'https://addon.example/abc123/manifest.json',
      );
    });

    test('rejects foreign schemes and malformed input', () {
      for (final bad in [
        null, '', '   ', 'https://addon.example/manifest.json',
        'javascript:alert(1)', 'file:///etc/passwd', 'intent://x',
        'stremio://localhost/manifest.json', 'stremio://', 'stremio:///path',
      ]) {
        expect(DeepLinkService.normaliseAddonLink(bad), isNull, reason: '$bad');
      }
    });
  });
}
