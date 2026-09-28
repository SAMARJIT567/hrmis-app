// 📁 lib/features/auth/providers/auth_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String designation;
  final String empCode;
  final String? avatarUrl;
  final String? gender;
  final int? survivingChildren;
  final bool isActive;
  final String? joiningDate;
  final String? employeeType;
  final String? zoneIds;
  final String? noZoneRequired;
  final String? registeredDeviceId;
  final String? deviceName;
  final String? attendanceFlag;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.designation = '',
    this.empCode = '',
    this.avatarUrl,
    this.gender,
    this.survivingChildren,
    this.isActive = true,
    this.joiningDate,
    this.employeeType,
    this.zoneIds,
    this.noZoneRequired,
    this.registeredDeviceId,
    this.deviceName,
    this.attendanceFlag,
    this.rawData,
  });

  final Map<String, dynamic>? rawData;

  // Getters for Employee Details & Addresses directly from DB
  String? get mobileNumber => rawData?['mobile_number']?.toString();
  String? get alternateMobile => rawData?['alternate_mobile']?.toString();
  String? get dob => rawData?['dob']?.toString();
  String? get bloodGroup => rawData?['blood_group']?.toString();
  String? get guardianName => rawData?['guardian_name']?.toString() ?? rawData?['fathers_name']?.toString();
  String? get mothersName => rawData?['mothers_name']?.toString();
  String? get spouseName => rawData?['spouse_name']?.toString();
  String? get maritalStatus => rawData?['marital_status_id']?.toString();
  String? get nationality => rawData?['nationality']?.toString() ?? 'Indian';
  String? get religion => rawData?['religion_id']?.toString();
  String? get caste => rawData?['caste_id']?.toString();
  String? get personalFileNo => rawData?['personal_file_no']?.toString();
  String? get retirementDate => rawData?['date_of_retirement']?.toString();
  String? get bankAcNo => rawData?['bank_ac_no']?.toString();
  String? get bankIfscNo => rawData?['bank_ifsc_no']?.toString();
  String? get bankName => rawData?['bank_name']?.toString();
  String? get panNo => rawData?['pan_no']?.toString();
  String? get aadharNumber => rawData?['aadhar_number']?.toString();
  String? get pfNo => rawData?['pf_no']?.toString();
  String? get uanNo => rawData?['uan_no']?.toString();

  // Present Address getters
  String? get presentAddress1 => rawData?['present_address_1']?.toString();
  String? get presentAddress2 => rawData?['present_address_2']?.toString();
  String? get presentLandmark => rawData?['present_address_landmark']?.toString();
  String? get presentPs => rawData?['present_ps']?.toString();
  String? get presentPo => rawData?['present_po']?.toString();
  String? get presentCity => rawData?['present_city']?.toString();
  String? get presentDistrict => rawData?['present_district']?.toString();
  String? get presentState => rawData?['present_state']?.toString();
  String? get presentPin => rawData?['present_pin']?.toString();

  // Permanent Address getters
  String? get permanentAddress1 => rawData?['permanent_address_1']?.toString();
  String? get permanentAddress2 => rawData?['permanent_address_2']?.toString();
  String? get permanentAddress3 => rawData?['permanent_address_3']?.toString();
  String? get permanentLandmark => rawData?['permanent_address_landmark']?.toString();
  String? get permanentPs => rawData?['permanent_ps']?.toString();
  String? get permanentPo => rawData?['permanent_po']?.toString();
  String? get permanentCity => rawData?['permanent_city']?.toString();
  String? get permanentDistrict => rawData?['permanent_district']?.toString();
  String? get permanentState => rawData?['permanent_state']?.toString();
  String? get permanentPin => rawData?['permanent_pin']?.toString();

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    String resolvedRole = 'employee';
    if (json['role'] != null) {
      resolvedRole = json['role'].toString();
    } else {
      final roleIdsRaw = json['role_ids'];
      if (roleIdsRaw != null) {
        try {
          List<dynamic> parsedIds = [];
          if (roleIdsRaw is List) {
            parsedIds = roleIdsRaw;
          } else if (roleIdsRaw is String) {
            parsedIds = jsonDecode(roleIdsRaw) as List<dynamic>;
          }
          if (parsedIds.map((e) => e.toString()).contains('1')) {
            resolvedRole = 'admin';
          }
        } catch (e) {
          if (roleIdsRaw.toString().contains('"1"') || roleIdsRaw.toString().contains("'1'")) {
            resolvedRole = 'admin';
          }
        }
      }
    }

    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: resolvedRole,
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      empCode: json['emp_code'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['profile_path'],
      gender: json['gender'],
      survivingChildren: json['surviving_children'],
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == '1',
      joiningDate: json['joining_date'],
      employeeType: json['employee_type'] ?? json['appointment_type'],
      zoneIds: json['zone_ids']?.toString(),
      noZoneRequired: json['no_zone_required']?.toString(),
      registeredDeviceId: json['registered_device_id']?.toString(),
      deviceName: json['device_name']?.toString(),
      attendanceFlag: json['attendance_flag']?.toString(),
      rawData: json['raw_employee'] != null && json['raw_employee'] is Map
          ? Map<String, dynamic>.from(json['raw_employee'] as Map)
          : json,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'department': department,
    'designation': designation,
    'emp_code': empCode,
    'avatar_url': avatarUrl,
    'gender': gender,
    'surviving_children': survivingChildren,
    'is_active': isActive,
    'joining_date': joiningDate,
    'employee_type': employeeType,
    'zone_ids': zoneIds,
    'no_zone_required': noZoneRequired,
    'registered_device_id': registeredDeviceId,
    'device_name': deviceName,
    'attendance_flag': attendanceFlag,
    'raw_employee': rawData,
  };
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;
  String? _token;

  final ApiService _apiService = ApiService();

  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String? get token => _token;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isEmployee => _currentUser?.role == 'employee';

  AuthProvider() {
    _initApi();
    _checkSession();
  }

  void _initApi() {
    _apiService.init();
    ApiService.onUnauthorized = () {
      _clearSession();
    };
  }

  Timer? _deviceCheckTimer;

  void _startDeviceCheckTimer() {
    _deviceCheckTimer?.cancel();
    // Periodically sync profile from backend every 5 minutes if logged in
    _deviceCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isLoggedIn && !isAdmin) {
        fetchProfile(silent: true);
      }
    });
  }

  void _stopDeviceCheckTimer() {
    _deviceCheckTimer?.cancel();
    _deviceCheckTimer = null;
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userJson = prefs.getString('user_data');

    if (token != null && token.isNotEmpty && userJson != null) {
      try {
        _token = token;
        final Map<String, dynamic> data = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = AuthUser.fromJson(data);
        _isLoggedIn = true;
        fetchProfile(silent: true);
        _startDeviceCheckTimer();
        notifyListeners();
      } catch (e) {
        // Invalid stored data
        await _clearSession();
      }
    }
  }

  Future<void> _clearSession() async {
    _stopDeviceCheckTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    await prefs.remove('user_email');
    _token = null;
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // ─── LOGIN ──────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(
        email: email.trim(),
        password: password,
      );

      final token = response['token'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        _errorMessage = 'Invalid server response';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _token = token;
      _currentUser = AuthUser.fromJson(userData);
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_data', jsonEncode(userData));
      if (rememberMe) {
        await prefs.setString('user_email', email);
      }

      _isLoading = false;
      _errorMessage = null;
      fetchProfile(silent: true);
      _startDeviceCheckTimer();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── LOGOUT ─────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      // Optional: Call logout API
      // await _apiService.logout();
    } catch (e) {
      // Ignore errors on logout
    } finally {
      await _clearSession();
    }
  }

  // ─── Update Profile ───────────────────────────────────────────
  Future<void> updateCurrentUser({
    required String name,
    required String email,
    required String department,
    required String designation,
  }) async {
    if (_currentUser == null) return;

    // Update local
    _currentUser = AuthUser(
      id: _currentUser!.id,
      name: name,
      email: email,
      role: _currentUser!.role,
      department: department,
      designation: designation,
      empCode: _currentUser!.empCode,
      isActive: _currentUser!.isActive,
    );

    // Save to storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
    await prefs.setString('user_name_${_currentUser!.id}', name);
    await prefs.setString('user_email_${_currentUser!.id}', email);
    await prefs.setString('user_department_${_currentUser!.id}', department);
    await prefs.setString('user_designation_${_currentUser!.id}', designation);

    notifyListeners();
  }

  Future<void> updateProfileImage(String base64Image) async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_${_currentUser!.id}', base64Image);
    notifyListeners();
  }

  Future<String?> getProfileImage() async {
    if (_currentUser == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_${_currentUser!.id}');
  }

  Future<void> fetchProfile({bool silent = false}) async {
    if (_currentUser == null || isAdmin) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final response = await _apiService.getProfile();
      final userData = response['user'];
      final empData = response['employee'];

      if (userData != null) {
        final Map<String, dynamic> merged = Map<String, dynamic>.from(userData as Map<String, dynamic>);
        if (empData != null) {
          final empMap = empData as Map<String, dynamic>;
          merged['gender'] = empMap['gender'];
          merged['emp_code'] = empMap['code'] ?? userData['emp_code'];
          merged['mobile_number'] = empMap['mobile_number'];
          merged['surviving_children'] = empMap['surviving_children'];
          merged['joining_date'] = empMap['date_of_joining'] ?? empMap['datetime_of_joining'];
          merged['employee_type'] = empMap['appointment_type'];
          
          if (empMap['profile_path'] != null && empMap['profile_path'].toString().trim().isNotEmpty) {
            final path = empMap['profile_path'].toString().trim();
            final origin = _apiService.baseUrl.replaceAll(RegExp(r'/api/?$'), '').replaceAll(RegExp(r'/+$'), '');
            final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
            merged['avatar_url'] = path.startsWith('http') ? path : '$origin/$cleanPath';
          }

          if (empMap['first_name'] != null && empMap['first_name'].toString().trim().isNotEmpty) {
            final fName = empMap['first_name'].toString().trim();
            final lName = (empMap['last_name'] ?? '').toString().trim();
            final fullName = '$fName $lName'.trim();
            if (fullName.isNotEmpty) {
              merged['name'] = fullName;
            }
          }

          String? deptName;
          if (empMap['department'] != null) {
            deptName = empMap['department'] is Map
                ? empMap['department']['name']?.toString()
                : empMap['department'].toString();
          }
          String? desigName;
          if (empMap['designation'] != null) {
            desigName = empMap['designation'] is Map
                ? empMap['designation']['name']?.toString()
                : empMap['designation'].toString();
          }

          final deptId = empMap['department_id']?.toString();
          final desigId = empMap['designation_id']?.toString();

          if ((deptName == null || deptName.isEmpty || int.tryParse(deptName) != null) ||
              (desigName == null || desigName.isEmpty || int.tryParse(desigName) != null)) {
            try {
              final masterData = await _apiService.getMasterData();
              final departments = masterData['department'] as List<dynamic>?;
              final designations = masterData['designation'] as List<dynamic>?;

              if (deptId != null && departments != null) {
                final match = departments.firstWhere(
                  (d) => d['id']?.toString() == deptId,
                  orElse: () => null,
                );
                if (match != null && match['name'] != null) {
                  deptName = match['name'].toString();
                }
              }

              if (desigId != null && designations != null) {
                final match = designations.firstWhere(
                  (d) => d['id']?.toString() == desigId,
                  orElse: () => null,
                );
                if (match != null && match['name'] != null) {
                  desigName = match['name'].toString();
                }
              }
            } catch (e) {
              debugPrint('⚠️ Could not fetch master data for profile: $e');
            }
          }

          if (deptName != null && deptName.isNotEmpty) {
            merged['department'] = deptName;
          }
          if (desigName != null && desigName.isNotEmpty) {
            merged['designation'] = desigName;
          }
          merged['raw_employee'] = empMap;
        }
        
        _currentUser = AuthUser.fromJson(merged);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(merged));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile from backend: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}