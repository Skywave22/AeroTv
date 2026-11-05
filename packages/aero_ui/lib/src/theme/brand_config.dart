import 'package:flutter/material.dart';

/// Single source of truth for rebranding.
///
/// Change the values here (plus the Android flavor's `applicationId` and
/// launcher assets) to ship a differently-branded build. Nothing else in the
/// codebase hard-codes the product name.
class BrandConfig {
  const BrandConfig({
    this.appName = 'Aero TV',
    this.tagline = 'Your player. Your sources.',
    this.accent = const Color(0xFF7B5CFF),
    this.secondaryGlow = const Color(0xFF00C2A8),
    this.logoAsset,
    this.supportUrl = '',
    this.termsUrl = '',
    this.privacyUrl = '',
    this.dmcaContact = '',
  });

  final String appName;
  final String tagline;
  final Color accent;
  final Color secondaryGlow;
  final String? logoAsset;
  final String supportUrl;
  final String termsUrl;
  final String privacyUrl;
  final String dmcaContact;

  static const BrandConfig standard = BrandConfig();

  BrandConfig copyWith({
    String? appName,
    String? tagline,
    Color? accent,
    Color? secondaryGlow,
    String? logoAsset,
    String? supportUrl,
    String? termsUrl,
    String? privacyUrl,
    String? dmcaContact,
  }) =>
      BrandConfig(
        appName: appName ?? this.appName,
        tagline: tagline ?? this.tagline,
        accent: accent ?? this.accent,
        secondaryGlow: secondaryGlow ?? this.secondaryGlow,
        logoAsset: logoAsset ?? this.logoAsset,
        supportUrl: supportUrl ?? this.supportUrl,
        termsUrl: termsUrl ?? this.termsUrl,
        privacyUrl: privacyUrl ?? this.privacyUrl,
        dmcaContact: dmcaContact ?? this.dmcaContact,
      );
}
