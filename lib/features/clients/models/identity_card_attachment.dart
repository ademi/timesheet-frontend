import 'package:get/get.dart';

/// Local pick or server-linked document for an identity card requirement.
class PendingIdentityCardFile {
  const PendingIdentityCardFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final List<int> bytes;
  final String contentType;
}

class IdentityCardAttachment {
  final RxnString existingDocumentId = RxnString();
  final RxnString existingDocumentLabel = RxnString();
  final Rxn<PendingIdentityCardFile> pending = Rxn();

  bool get hasAttachment =>
      (existingDocumentId.value != null && existingDocumentId.value!.isNotEmpty) ||
      pending.value != null;

  void reset() {
    existingDocumentId.value = null;
    existingDocumentLabel.value = null;
    pending.value = null;
  }
}
