// ============================================================
// 📁 lib/features/leave/models/leave_model.dart
// ─────────────────────────────────────────────────────────────
// Leave request data model.
// ============================================================

class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final double days;
  final String reason;
  final String status;
  final String appliedOn;
  final String? approvedBy;
  final String? remarks;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.appliedOn,
    this.approvedBy,
    this.remarks,
  });

  factory LeaveRequest.fromJson(
    Map<String, dynamic> json, {
    Map<String, String>? leaveTypeMap,
    String? defaultEmployeeName,
    String? defaultDepartment,
  }) {
    final fromDateStr = json['from_date']?.toString() ?? json['applied_from_date']?.toString() ?? '';
    final toDateStr = json['to_date']?.toString() ?? json['applied_to_date']?.toString() ?? '';
    double calculatedDays = 1.0;
    try {
      if (fromDateStr.isNotEmpty && toDateStr.isNotEmpty) {
        final from = DateTime.parse(fromDateStr);
        final to = DateTime.parse(toDateStr);
        calculatedDays = to.difference(from).inDays + 1.0;
      }
    } catch (_) {}

    String resolvedStatus = json['status']?.toString().toLowerCase() ?? 'pending';
    if (resolvedStatus == 'approve' || resolvedStatus == 'approved') {
      resolvedStatus = 'approved';
    } else if (resolvedStatus == 'reject' || resolvedStatus == 'rejected') {
      resolvedStatus = 'rejected';
    } else if (resolvedStatus == 'submited' || resolvedStatus == 'submitted' || resolvedStatus == 'pending') {
      resolvedStatus = 'pending';
    } else if (resolvedStatus == 'closed') {
      resolvedStatus = 'closed';
    }

    // Default mapping matching GMDA leave_type_masters database
    const Map<String, String> defaultLeaveTypeMap = {
      '1': 'Casual Leave',
      '2': 'Earned Leave',
      '3': 'Half Pay Leave',
      '4': 'Commuted Leave',
      '9': 'Maternity Leave',
      '11': 'Child care Leave',
      '12': 'Matri Pitri Bandana',
      '13': 'Restricted Holiday',
      '14': 'Tour',
    };

    String resolvedLeaveType = 'Casual Leave';
    if (json['leave_type'] is Map && json['leave_type']['name'] != null) {
      resolvedLeaveType = json['leave_type']['name'].toString();
    } else {
      final typeId = json['leave_type_id']?.toString() ?? json['leave_type']?.toString();
      if (typeId != null && leaveTypeMap != null && leaveTypeMap.containsKey(typeId)) {
        resolvedLeaveType = leaveTypeMap[typeId]!;
      } else if (typeId != null && defaultLeaveTypeMap.containsKey(typeId)) {
        resolvedLeaveType = defaultLeaveTypeMap[typeId]!;
      } else if (json['leave_type_name'] != null) {
        resolvedLeaveType = json['leave_type_name'].toString();
      }
    }

    String resolvedEmpName = defaultEmployeeName ?? 'Employee';
    if (json['emp_info'] is Map && json['emp_info']['name'] != null) {
      resolvedEmpName = json['emp_info']['name'].toString();
    } else if (json['user'] is Map && json['user']['name'] != null) {
      resolvedEmpName = json['user']['name'].toString();
    } else if (json['emp_name'] != null) {
      resolvedEmpName = json['emp_name'].toString();
    }

    String resolvedDept = defaultDepartment ?? 'GMDA';
    if (json['emp_info'] is Map &&
        json['emp_info']['employee'] is Map &&
        json['emp_info']['employee']['department'] is Map) {
      resolvedDept = json['emp_info']['employee']['department']['name']?.toString() ?? resolvedDept;
    } else if (json['department'] != null) {
      resolvedDept = json['department'].toString();
    }

    String appliedOnStr = '';
    if (json['created_at'] != null) {
      final rawCreated = json['created_at'].toString();
      try {
        final dt = DateTime.parse(rawCreated);
        appliedOnStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
      } catch (_) {
        appliedOnStr = rawCreated.length >= 10 ? rawCreated.substring(0, 10) : rawCreated;
      }
    }

    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      employeeId: json['emp_id']?.toString() ?? json['emp_code']?.toString() ?? '',
      employeeName: resolvedEmpName,
      department: resolvedDept,
      leaveType: resolvedLeaveType,
      fromDate: fromDateStr,
      toDate: toDateStr,
      days: calculatedDays,
      reason: json['reason']?.toString() ?? '',
      status: resolvedStatus,
      appliedOn: appliedOnStr,
      approvedBy: json['approved_by']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }
}

class LeavePolicy {
  final String id;
  final String title;
  final String description;
  final int totalDays;
  final int usedDays;
  final String iconName;
  final int colorValue;

  const LeavePolicy({
    required this.id,
    required this.title,
    required this.description,
    required this.totalDays,
    this.usedDays = 0,
    required this.iconName,
    required this.colorValue,
  });

  LeavePolicy copyWith({int? totalDays, int? usedDays}) {
    return LeavePolicy(
      id: id,
      title: title,
      description: description,
      totalDays: totalDays ?? this.totalDays,
      usedDays: usedDays ?? this.usedDays,
      iconName: iconName,
      colorValue: colorValue,
    );
  }
}

class CompOffCredit {
  final String id;
  final String employeeId;
  final String employeeName;
  final String dutyDate;
  final String expiryDate;
  final String reason;
  final String status; // pending, approved, used, lapsed
  final String attachment;
  final String? duration;

  const CompOffCredit({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dutyDate,
    required this.expiryDate,
    required this.reason,
    required this.status,
    required this.attachment,
    this.duration,
  });

  CompOffCredit copyWith({String? status}) {
    return CompOffCredit(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      dutyDate: dutyDate,
      expiryDate: expiryDate,
      reason: reason,
      status: status ?? this.status,
      attachment: attachment,
      duration: duration,
    );
  }
}
