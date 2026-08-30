import 'package:flutter/material.dart';

class ContractorQualRow {
  ContractorQualRow({this.type = 'first_aid'});

  String type;
  final issueDateCtrl = TextEditingController();
  final expiryDateCtrl = TextEditingController();

  void dispose() {
    issueDateCtrl.dispose();
    expiryDateCtrl.dispose();
  }
}
