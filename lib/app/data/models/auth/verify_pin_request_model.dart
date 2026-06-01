class VerifyPinRequestModel {
  const VerifyPinRequestModel({required this.employeeId, required this.pin});

  final String employeeId;
  final String pin;

  Map<String, dynamic> toJson() => {'employee_id': employeeId, 'pin': pin};
}
