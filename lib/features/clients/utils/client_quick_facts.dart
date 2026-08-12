import '../controllers/requirement_draft.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';

class ClientQuickFacts {
  const ClientQuickFacts({
    required this.fullName,
    required this.status,
    this.dob,
    this.ndisNumber,
    this.email,
    this.phone,
    this.clientTypeName,
  });

  final String fullName;
  final String status;
  final String? dob;
  final String? ndisNumber;
  final String? email;
  final String? phone;
  final String? clientTypeName;
}

String? ndisFromDrafts(List<RequirementDraft> drafts) {
  for (final d in drafts) {
    if (d.requirement.requirementKey == 'ndis') {
      final v = d.fieldValueJson;
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
  }
  return null;
}

String? ndisFromFacts(List<ClientProfileFactOut> facts) {
  for (final f in facts) {
    if (f.requirementKey == 'ndis' && f.valueJson != null) {
      final s = f.valueJson.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

ClientQuickFacts buildQuickFacts({
  required ClientOut client,
  String? ndisNumber,
  String? clientTypeName,
}) {
  return ClientQuickFacts(
    fullName: client.fullName,
    status: client.status,
    dob: client.dob,
    ndisNumber: ndisNumber,
    email: client.email,
    phone: client.phone,
    clientTypeName: clientTypeName,
  );
}
