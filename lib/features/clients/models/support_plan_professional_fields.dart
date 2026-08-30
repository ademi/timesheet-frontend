import 'package:flutter/material.dart';

/// Seven-field professional block (plan manager, SC, allied health).
class SupportPlanProfessionalFields {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController companyCtrl = TextEditingController();
  final TextEditingController abnAcnCtrl = TextEditingController();
  final TextEditingController orgIdCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();

  void clear() {
    nameCtrl.clear();
    companyCtrl.clear();
    abnAcnCtrl.clear();
    orgIdCtrl.clear();
    phoneCtrl.clear();
    emailCtrl.clear();
    addressCtrl.clear();
  }

  void dispose() {
    nameCtrl.dispose();
    companyCtrl.dispose();
    abnAcnCtrl.dispose();
    orgIdCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
  }
}
