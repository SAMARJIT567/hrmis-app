// ============================================================
// 📁 lib/features/attendance/models/attendance_model.dart
// ─────────────────────────────────────────────────────────────
// Attendance data model.
// ============================================================

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final String? workHours;
  final String? remarks;
  final String? checkInSelfie;
  final String? checkOutSelfie;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? employeeImage;
  final double? latitude;
  final double? longitude;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.workHours,
    this.remarks,
    this.checkInSelfie,
    this.checkOutSelfie,
    this.checkInLocation,
    this.checkOutLocation,
    this.employeeImage,
    this.latitude,
    this.longitude,
  });
}
