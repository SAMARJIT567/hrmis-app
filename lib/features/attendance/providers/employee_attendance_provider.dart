// ============================================================
// 📁 lib/features/attendance/providers/employee_attendance_provider.dart
// ============================================================
// Provider for managing individual employee attendance state
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';

class EmployeeAttendanceRecord {
  final String id;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final String? workHours;
  final String? lateDuration;
  final String? leaveType;
  final String? checkInSelfie;
  final double? latitude;
  final double? longitude;

  const EmployeeAttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.workHours,
    this.lateDuration,
    this.leaveType,
    this.checkInSelfie,
    this.latitude,
    this.longitude,
  });
}

class EmployeeAttendanceProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<EmployeeAttendanceRecord> _records = [];
  bool _isLoading = false;
  bool _isCheckedIn = false;
  String? _currentCheckInTime;
  String? _currentLateDuration;

  List<String> _holidays = [];
  String _weekend = 'Sunday';

  List<EmployeeAttendanceRecord> get records => _records;
  List<String> get holidays => _holidays;
  String get weekend => _weekend;
  bool get isLoading => _isLoading;
  bool get isCheckedIn => _isCheckedIn;
  String? get currentCheckInTime => _currentCheckInTime;
  String? get currentLateDuration => _currentLateDuration;

  bool _isSameDay(String dateStr, DateTime target) {
    try {
      DateTime parsed;
      if (dateStr.contains(RegExp(r'[a-zA-Z]'))) {
        parsed = DateFormat('dd MMM yyyy').parse(dateStr);
      } else {
        parsed = DateFormat('yyyy-MM-dd').parse(dateStr);
      }
      return parsed.year == target.year &&
             parsed.month == target.month &&
             parsed.day == target.day;
    } catch (_) {
      final ymd = DateFormat('yyyy-MM-dd').format(target);
      final dmy = DateFormat('dd MMM yyyy').format(target);
      return dateStr == ymd || dateStr == dmy;
    }
  }

  EmployeeAttendanceRecord? get todayRecord {
    final now = DateTime.now();
    for (final r in _records) {
      if (_isSameDay(r.date, now)) {
        return r;
      }
    }
    return null;
  }

  bool get isCompletedToday {
    final r = todayRecord;
    return r != null && r.checkIn != null && r.checkOut != null;
  }

  int get presentCount {
    final now = DateTime.now();
    final Set<String> uniquePresentDates = {};
    for (final r in _records) {
      try {
        DateTime recordDate;
        if (r.date.contains(RegExp(r'[a-zA-Z]'))) {
          recordDate = DateFormat('dd MMM yyyy').parse(r.date);
        } else {
          recordDate = DateFormat('yyyy-MM-dd').parse(r.date);
        }
        if (recordDate.month == now.month && recordDate.year == now.year) {
          final s = r.status.toLowerCase().trim();
          if (s == 'present' || s == 'late' || s == 'late in' || s == 'half day' || s == 'tour' || s == 'early out') {
            uniquePresentDates.add(DateFormat('yyyy-MM-dd').format(recordDate));
          }
        }
      } catch (_) {}
    }
    return uniquePresentDates.length;
  }

  int get absentCount {
    if (_records.isEmpty) return 0;
    
    DateTime? refDate;
    for (final r in _records) {
      try {
        if (r.date.contains(RegExp(r'[a-zA-Z]'))) {
          refDate = DateFormat('dd MMM yyyy').parse(r.date);
        } else {
          refDate = DateFormat('yyyy-MM-dd').parse(r.date);
        }
        break;
      } catch (_) {}
    }
    
    if (refDate == null) return 0;
    
    final year = refDate.year;
    final month = refDate.month;
    final now = DateTime.now();
    final bool isCurrentMonth = (now.month == month && now.year == year);
    
    final int endDay = isCurrentMonth ? now.day - 1 : DateTime(year, month + 1, 0).day;
    int workingDays = 0;
    
    for (int d = 1; d <= endDay; d++) {
      final date = DateTime(year, month, d);
      final dayOfWeek = DateFormat('EEEE').format(date);
      final isWeekend = dayOfWeek.toLowerCase() == weekend.toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isHoliday = holidays.contains(dateStr);
      
      if (!isWeekend && !isHoliday) {
        workingDays++;
      }
    }
    
    final Set<String> uniqueAttendedDates = {};
    for (final r in _records) {
      try {
        DateTime recordDate;
        if (r.date.contains(RegExp(r'[a-zA-Z]'))) {
          recordDate = DateFormat('dd MMM yyyy').parse(r.date);
        } else {
          recordDate = DateFormat('yyyy-MM-dd').parse(r.date);
        }
        if (recordDate.month == month && recordDate.year == year && recordDate.day <= endDay) {
          final s = r.status.toLowerCase().trim();
          if (s == 'present' || s == 'late' || s == 'late in' || s == 'half day' || s == 'tour' || s == 'early out' || s == 'leave' || s == 'on_leave') {
            uniqueAttendedDates.add(DateFormat('yyyy-MM-dd').format(recordDate));
          }
        }
      } catch (_) {}
    }

    final attendedDays = uniqueAttendedDates.length;
    final calculatedAbsent = workingDays - attendedDays;
    return calculatedAbsent > 0 ? calculatedAbsent : 0;
  }

  int get lateCount {
    final now = DateTime.now();
    final Set<String> uniqueLateDates = {};
    for (final r in _records) {
      try {
        DateTime recordDate;
        if (r.date.contains(RegExp(r'[a-zA-Z]'))) {
          recordDate = DateFormat('dd MMM yyyy').parse(r.date);
        } else {
          recordDate = DateFormat('yyyy-MM-dd').parse(r.date);
        }
        if (recordDate.month == now.month && recordDate.year == now.year) {
          final s = r.status.toLowerCase().trim();
          if (s == 'late' || s == 'late in') {
            uniqueLateDates.add(DateFormat('yyyy-MM-dd').format(recordDate));
          }
        }
      } catch (_) {}
    }
    return uniqueLateDates.length;
  }

  EmployeeAttendanceProvider() {
    loadMyAttendance();
  }

  Future<void> loadMyAttendance({String? month, String? year}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getAttendance(month: month, year: year);
        
        // Parse Employee-specific response from Laravel
        if (response['attendence'] != null) {
          final List<dynamic> list = response['attendence'];
          _records = list.map((json) {
            String rawStatus = json['status'] ?? 'present';
            String displayStatus = 'Present';
            final statusLower = rawStatus.toLowerCase();
            if (statusLower == 'not_in_time' || statusLower == 'late' || statusLower == 'late_in') {
              displayStatus = 'Late In';
            } else if (statusLower == 'absent') {
              displayStatus = 'Absent';
            } else if (statusLower == 'on_leave' || statusLower == 'leave') {
              displayStatus = 'Leave';
            } else if (statusLower == 'tour') {
              displayStatus = 'Tour';
            } else if (statusLower == 'half_day' || statusLower == 'halfday') {
              displayStatus = 'Half Day';
            } else if (statusLower == 'early_out') {
              displayStatus = 'Early Out';
            } else {
              displayStatus = 'Present';
            }

            // Parse work hours
            String? workHours;
            final wh = json['working_hour']?.toString();
            if (wh != null && wh.length >= 5) {
              try {
                final h = int.parse(wh.substring(0, 2));
                final m = int.parse(wh.substring(3, 5));
                workHours = '${h}h ${m}m';
              } catch (_) {}
            }

            // Parse check in and check out times
            String? checkIn;
            String? checkOut;
            if (json['in_time'] != null) {
              try {
                final dt = DateTime.parse(json['in_time']);
                checkIn = DateFormat('hh:mm a').format(dt);
              } catch (_) {
                checkIn = json['in_time'];
              }
            }
            if (json['out_time'] != null) {
              try {
                final dt = DateTime.parse(json['out_time']);
                checkOut = DateFormat('hh:mm a').format(dt);
              } catch (_) {
                checkOut = json['out_time'];
              }
            }

            final leaveTypeStr = json['leave_type']?['name']?.toString();

            return EmployeeAttendanceRecord(
              id: json['id']?.toString() ?? '',
              date: json['punch_date'] ?? '', // Laravel punch_date
              checkIn: checkIn,
              checkOut: checkOut,
              status: displayStatus,
              workHours: workHours,
              lateDuration: null,
              leaveType: leaveTypeStr,
              checkInSelfie: json['check_in_selfie'],
              latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
              longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
            );
          }).toList();

          _records.sort((a, b) {
            try {
              DateTime da;
              DateTime db;
              if (a.date.contains(RegExp(r'[a-zA-Z]'))) {
                da = DateFormat('dd MMM yyyy').parse(a.date);
              } else {
                da = DateFormat('yyyy-MM-dd').parse(a.date);
              }
              if (b.date.contains(RegExp(r'[a-zA-Z]'))) {
                db = DateFormat('dd MMM yyyy').parse(b.date);
              } else {
                db = DateFormat('yyyy-MM-dd').parse(b.date);
              }
              return db.compareTo(da);
            } catch (_) {
              return 0;
            }
          });

          // Parse holidays
          if (response['holiday'] != null) {
            _holidays = List<String>.from(response['holiday'].map((item) => item.toString()));
          } else {
            _holidays = [];
          }

          // Parse weekend
          _weekend = response['weekend']?.toString() ?? 'Sunday';
        } else if (response['status'] == 'success' && response['data'] != null) {
          // Fallback to Admin format if necessary
          final List<dynamic> data = response['data'];
          _records = data.map((json) {
            String rawStatus = json['status'] ?? 'Present';
            String displayStatus = 'Present';
            if (rawStatus.toLowerCase() == 'late') {
              displayStatus = 'Late';
            } else if (rawStatus.toLowerCase() == 'absent') {
              displayStatus = 'Absent';
            }

            return EmployeeAttendanceRecord(
              id: json['id']?.toString() ?? '',
              date: json['date'] ?? '',
              checkIn: json['check_in'],
              checkOut: json['check_out'],
              status: displayStatus,
              workHours: json['work_hours'],
              lateDuration: json['late_duration'],
            );
          }).toList();
          _holidays = [];
          _weekend = 'Sunday';
        } else {
          _records = [];
          _holidays = [];
          _weekend = 'Sunday';
        }
      } catch (e) {
        debugPrint('❌ Error loading attendance: $e');
        _records = [];
        _holidays = [];
        _weekend = 'Sunday';
      }

      _checkTodayAttendance();
      _isLoading = false;
      notifyListeners();
    }

  void _checkTodayAttendance() {
    final now = DateTime.now();
    final index = _records.indexWhere((r) => _isSameDay(r.date, now));
    if (index != -1) {
      final todayRecord = _records[index];
      _isCheckedIn = todayRecord.checkIn != null && todayRecord.checkOut == null;
      _currentCheckInTime = todayRecord.checkIn;
      _currentLateDuration = todayRecord.lateDuration;
    } else {
      _isCheckedIn = false;
      _currentCheckInTime = null;
      _currentLateDuration = null;
    }
  }

  String _calculateLateDuration(DateTime checkInTime) {
    final expectedTime = DateTime(checkInTime.year, checkInTime.month, checkInTime.day, 10, 0);
    if (checkInTime.isAfter(expectedTime)) {
      final difference = checkInTime.difference(expectedTime);
      final minutes = difference.inMinutes;
      if (minutes < 60) return '$minutes minutes';
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours hour${hours > 1 ? 's' : ''} ${mins > 0 ? '$mins minutes' : ''}';
    }
    return '';
  }

  Future<bool> checkIn({required double latitude, required double longitude, String? imagePath, String? zoneId}) async {
    if (_isCheckedIn) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.markAttendance(
        type: 'in',
        latitude: latitude,
        longitude: longitude,
        imagePath: imagePath,
        zoneId: zoneId,
      );

      final now = DateTime.now();
      final todayYmd = DateFormat('yyyy-MM-dd').format(now);
      
      final checkInTime = response['data'] != null && response['data']['check_in'] != null
          ? response['data']['check_in'] as String
          : DateFormat('hh:mm a').format(now);

      final rawStatus = response['data'] != null ? response['data']['status'] as String? : null;
      final isLate = rawStatus?.toLowerCase() == 'late' || (rawStatus == null && now.hour >= 10);
      final lateDuration = response['data'] != null ? response['data']['late_duration'] as String? : (isLate ? _calculateLateDuration(now) : null);

      _records.insert(0, EmployeeAttendanceRecord(
        id: response['data'] != null && response['data']['id'] != null
            ? response['data']['id'].toString()
            : DateTime.now().millisecondsSinceEpoch.toString(),
        date: todayYmd,
        checkIn: checkInTime,
        checkOut: null,
        status: isLate ? 'Late In' : 'Present',
        workHours: null,
        lateDuration: lateDuration,
      ));

      _isCheckedIn = true;
      _currentCheckInTime = checkInTime;
      _currentLateDuration = lateDuration;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> checkOut({required double latitude, required double longitude}) async {
    if (!_isCheckedIn) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.markAttendance(
        type: 'out',
        latitude: latitude,
        longitude: longitude,
      );

      final now = DateTime.now();
      
      final checkOutTime = response['data'] != null && response['data']['check_out'] != null
          ? response['data']['check_out'] as String
          : DateFormat('hh:mm a').format(now);

      final index = _records.indexWhere((r) => _isSameDay(r.date, now));
      if (index != -1) {
        final record = _records[index];
        String workHours = '8h 0m';
        if (response['data'] != null && response['data']['work_hours'] != null) {
          workHours = response['data']['work_hours'] as String;
        } else if (record.checkIn != null) {
          try {
            final checkInDt = DateFormat('hh:mm a').parse(record.checkIn!);
            final checkInFull = DateTime(now.year, now.month, now.day, checkInDt.hour, checkInDt.minute);
            final workDuration = now.difference(checkInFull);
            final hours = workDuration.inHours;
            final minutes = workDuration.inMinutes % 60;
            workHours = '${hours}h ${minutes}m';
          } catch (_) {}
        }

        _records[index] = EmployeeAttendanceRecord(
          id: record.id,
          date: record.date,
          checkIn: record.checkIn,
          checkOut: checkOutTime,
          status: record.status,
          workHours: workHours,
          lateDuration: record.lateDuration,
        );
      }

      _isCheckedIn = false;
      _currentCheckInTime = null;
      _currentLateDuration = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
