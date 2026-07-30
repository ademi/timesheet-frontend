import 'package:get_storage/get_storage.dart';

class OnboardingProgressSnapshot {
  const OnboardingProgressSnapshot({
    this.acceptedDocVersions = const {},
    this.acknowledgedNoticeVersions = const {},
    this.consentedTypes = const {},
    this.platformComplete = false,
  });

  const OnboardingProgressSnapshot.empty() : this();

  final Map<String, String> acceptedDocVersions;
  final Map<String, String> acknowledgedNoticeVersions;
  final Set<String> consentedTypes;
  final bool platformComplete;

  OnboardingProgressSnapshot copyWith({
    Map<String, String>? acceptedDocVersions,
    Map<String, String>? acknowledgedNoticeVersions,
    Set<String>? consentedTypes,
    bool? platformComplete,
  }) {
    return OnboardingProgressSnapshot(
      acceptedDocVersions: acceptedDocVersions ?? this.acceptedDocVersions,
      acknowledgedNoticeVersions:
          acknowledgedNoticeVersions ?? this.acknowledgedNoticeVersions,
      consentedTypes: consentedTypes ?? this.consentedTypes,
      platformComplete: platformComplete ?? this.platformComplete,
    );
  }

  Map<String, dynamic> toJson() => {
    'accepted_doc_versions': acceptedDocVersions,
    'acknowledged_notice_versions': acknowledgedNoticeVersions,
    'consented_types': consentedTypes.toList(),
    'platform_complete': platformComplete,
  };

  factory OnboardingProgressSnapshot.fromJson(Map<dynamic, dynamic> json) {
    Map<String, String> stringMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return value.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    final consented = json['consented_types'];
    return OnboardingProgressSnapshot(
      acceptedDocVersions: stringMap('accepted_doc_versions'),
      acknowledgedNoticeVersions: stringMap('acknowledged_notice_versions'),
      consentedTypes:
          consented is Iterable
              ? consented.map((value) => value.toString()).toSet()
              : const {},
      platformComplete: json['platform_complete'] == true,
    );
  }
}

/// Local onboarding progress scoped to a single contractor identity.
class OnboardingProgressStore {
  OnboardingProgressStore({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  String _key(String contractorId) => 'onboarding_platform_v1_$contractorId';

  OnboardingProgressSnapshot load(String? contractorId) {
    if (contractorId == null || contractorId.isEmpty) {
      return const OnboardingProgressSnapshot.empty();
    }
    try {
      final value = _storage.read<dynamic>(_key(contractorId));
      if (value is Map) return OnboardingProgressSnapshot.fromJson(value);
    } catch (_) {
      // Storage may not be initialized during an early app lifecycle.
    }
    return const OnboardingProgressSnapshot.empty();
  }

  Future<void> save(
    String? contractorId,
    OnboardingProgressSnapshot snapshot,
  ) async {
    if (contractorId == null || contractorId.isEmpty) return;
    await _storage.write(_key(contractorId), snapshot.toJson());
  }

  bool isPlatformComplete(String? contractorId) =>
      load(contractorId).platformComplete;

  Future<void> markPlatformComplete(String? contractorId) async {
    await save(
      contractorId,
      load(contractorId).copyWith(platformComplete: true),
    );
  }

  Future<void> markCredentialsStepDone(String? contractorId) =>
      markPlatformComplete(contractorId);

  Future<void> markAcceptedDocument(
    String? contractorId, {
    required String docKey,
    required String version,
  }) async {
    final snapshot = load(contractorId);
    await save(
      contractorId,
      snapshot.copyWith(
        acceptedDocVersions: {...snapshot.acceptedDocVersions, docKey: version},
      ),
    );
  }

  Future<void> markNoticeAcknowledged(
    String? contractorId, {
    required String noticeKey,
    required String version,
  }) async {
    final snapshot = load(contractorId);
    await save(
      contractorId,
      snapshot.copyWith(
        acknowledgedNoticeVersions: {
          ...snapshot.acknowledgedNoticeVersions,
          noticeKey: version,
        },
      ),
    );
  }

  Future<void> markConsentRecorded(
    String? contractorId,
    String credentialType,
  ) async {
    final snapshot = load(contractorId);
    await save(
      contractorId,
      snapshot.copyWith(
        consentedTypes: {...snapshot.consentedTypes, credentialType},
      ),
    );
  }
}
