/// SPKI SHA-256 pins for api.rostiq.co (F-fe-001).
///
/// Re-extract with openssl before rotating (see docs/certificate-pinning.md).
abstract final class CertPins {
  CertPins._();

  /// Leaf certificate SPKI.
  static const leaf = 'LKRRH8CV7K/ggPOakrjcP21xp8JY7oZGZ88nolF6cSA=';

  /// Intermediate CA SPKI (backup for Cloudflare / CA rotation).
  static const intermediate =
      'kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=';

  static const all = [leaf, intermediate];
}
