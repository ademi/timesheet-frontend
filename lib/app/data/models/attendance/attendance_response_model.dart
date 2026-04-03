import 'geofence_model.dart';

class AttendanceResponseModel {
  const AttendanceResponseModel({
    required this.timeEntryId,
    required this.employeeId,
    this.clockInAt,
    this.clockOutAt,
    required this.geofence,
  });

  final String timeEntryId;
  final String employeeId;
  final String? clockInAt;
  final String? clockOutAt;
  final GeofenceModel geofence;

  Map<String, dynamic> toJson() => {
        'time_entry_id': timeEntryId,
        'employee_id': employeeId,
        if (clockInAt != null) 'clock_in_at': clockInAt,
        if (clockOutAt != null) 'clock_out_at': clockOutAt,
        'geofence': geofence.toJson(),
      };

  factory AttendanceResponseModel.fromJson(Map<String, dynamic> json) {
    final geofenceRaw = json['geofence'];
    return AttendanceResponseModel(
      timeEntryId: json['time_entry_id'] as String,
      employeeId: json['employee_id'] as String,
      clockInAt: json['clock_in_at'] as String?,
      clockOutAt: json['clock_out_at'] as String?,
      geofence: geofenceRaw is Map<String, dynamic>
          ? GeofenceModel.fromJson(geofenceRaw)
          : const GeofenceModel(verdict: 'unknown'),
    );
  }
}
