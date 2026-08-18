// 📁 lib/features/auth/providers/auth_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/device_info_service.dart';

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
  });

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
      avatarUrl: json['avatar_url'],
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
  }

  Timer? _deviceCheckTimer;

  void _startDeviceCheckTimer() {
    _deviceCheckTimer?.cancel();
    _deviceCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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

    final trimmedEmail = email.trim().toLowerCase();
    final isAdmin = trimmedEmail.contains('admin') || trimmedEmail == 'demo@hrmis.com';

    if (isAdmin) {
      // Admin loads locally and runs on mock data
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for realistic UI feel
      _token = 'mock_jwt_token_for_demo';
      _currentUser = AuthUser(
        id: 'EMP001',
        name: 'Demo Admin',
        email: trimmedEmail,
        role: 'admin',
        department: 'Management',
        designation: 'Administrator',
        empCode: 'ADM001',
        isActive: true,
      );
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
      if (rememberMe) {
        await prefs.setString('user_email', email);
      }

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      // Employees authenticate using real API/Database credentials
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
        final registeredDeviceId = userData['registered_device_id']?.toString();
        final deviceDetails = await DeviceInfoService.getDeviceDetails();
        final currentDeviceId = deviceDetails.deviceId;
        final bypassRestriction = userData['bypass_device_restriction'] == 1 || userData['bypass_device_restriction'] == '1';

        // If Admin cleared registered_device_id OR device ID doesn't match current phone:
        if ((registeredDeviceId == null || registeredDeviceId != currentDeviceId) && !bypassRestriction) {
          debugPrint('🚨 Device unbound by Admin! Logging out with notification...');
          _stopDeviceCheckTimer();
          _errorMessage = "Administrator reset your device";
          await _clearSession();
          return;
        }

        final Map<String, dynamic> merged = Map<String, dynamic>.from(userData as Map<String, dynamic>);
        if (empData != null) {
          final empMap = empData as Map<String, dynamic>;
          merged['gender'] = empMap['gender'];
          merged['emp_code'] = empMap['code'] ?? userData['emp_code'];
          merged['mobile_number'] = empMap['mobile_number'];
          merged['surviving_children'] = empMap['surviving_children'];
          merged['joining_date'] = empMap['date_of_joining'] ?? empMap['datetime_of_joining'];
          merged['employee_type'] = empMap['appointment_type'];
          
          if (empMap['department'] != null) {
            merged['department'] = empMap['department']['name'];
          }
          if (empMap['designation'] != null) {
            merged['designation'] = empMap['designation']['name'];
          }
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