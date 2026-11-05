import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:crypto/crypto.dart' as cr;

/// A downloaded JS plugin plus its manifest metadata.
///
/// The manifest shape differs per ecosystem; this holds the common denominator
/// and keeps the raw JSON so each adapter can read its own fields.
class JsPluginBundle {
  const JsPluginBundle({
    required this.sourceUrl,
    required this.code,
    required this.manifest,
    required this.sha256,
    this.fetchedAt,
  });

  final String sourceUrl;
  final String code;
  final Map<String, dynamic> manifest;
  final String sha256;
  final DateTime? fetchedAt;

  String get id =>
      (manifest['id'] ?? manifest['name'] ?? sourceUrl).toString();
  String get name =>
      (manifest['name'] ?? manifest['displayName'] ?? id).toString();
  String get version => (manifest['version'] ?? '0.0.0').toString();
  String? get description => manifest['description']?.toString();
  String? get logo => (manifest['logo'] ?? manifest['icon'])?.toString();

  /// Verifies a hash pin before the code is ever evaluated.
  bool matchesPin(String? expected) {
    if (expected == null || expected.isEmpty) return true;
    return sha256.toLowerCase() == expected.toLowerCase();
  }

  static String hashOf(String code) =>
      cr.sha256.convert(utf8.encode(code)).toString();

  Map<String, dynamic> toJson() => {
        'sourceUrl': sourceUrl,
        'code': code,
        'manifest': manifest,
        'sha256': sha256,
        if (fetchedAt != null) 'fetchedAt': fetchedAt!.toIso8601String(),
      };

  factory JsPluginBundle.fromJson(Map<String, dynamic> j) => JsPluginBundle(
        sourceUrl: (j['sourceUrl'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        manifest: Map<String, dynamic>.from(j['manifest'] as Map? ?? const {}),
        sha256: (j['sha256'] ?? '').toString(),
        fetchedAt: DateTime.tryParse(j['fetchedAt']?.toString() ?? ''),
      );
}

/// Raised when a bundle fails validation and must not be executed.
class BundleRejectedException extends AeroException {
  const BundleRejectedException(super.message);
}
