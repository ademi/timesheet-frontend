class SetPinRequestModel {
  const SetPinRequestModel({
    required this.employeeId,
    required this.pin,
    required this.confirmPin,
  });

  final String employeeId;
  final String pin;
  final String confirmPin;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'pin': pin,
        'confirm_pin': confirmPin,
      };
}
