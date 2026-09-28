// 📁 lib/core/services/api_service.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'device_info_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static VoidCallback? onUnauthorized;

  late final Dio _dio;        // Client for HRMIS (Port 8000)
  late final Dio _leaveDio;   // Client for Leave (Port 8001)

  String? _customBaseUrl;

  String get baseUrl => _customBaseUrl ?? AppConfig.apiBaseUrl;
  String get leaveBaseUrl {
    if (_customBaseUrl != null) {
      return _getLeaveUrlFromMainUrl(_customBaseUrl!);
    }
    return AppConfig.leaveApiBaseUrl;
  }

  String _getLeaveUrlFromMainUrl(String mainUrl) {
    try {
      final uri = Uri.parse(mainUrl);
      if (uri.port == 8000) {
        return uri.replace(port: 8001).toString();
      }
      return mainUrl.replaceAll(':8000', ':8001');
    } catch (_) {
      return AppConfig.leaveApiBaseUrl;
    }
  }

  void updateBaseUrl(String newUrl) {
    _customBaseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
    
    final leaveUrl = _getLeaveUrlFromMainUrl(newUrl);
    _leaveDio.options.baseUrl = leaveUrl;
    
    log('Main API Base URL updated to: $newUrl');
    log('Leave API Base URL updated to: $leaveUrl');
  }

  void init() {
    // 1. Initialize Main Dio (Port 8000)
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 2. Initialize Leave Dio (Port 8001)
    _leaveDio = Dio(BaseOptions(
      baseUrl: leaveBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Load custom URL for main API if saved
    SharedPreferences.getInstance().then((prefs) {
      final savedUrl = prefs.getString('custom_api_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        updateBaseUrl(savedUrl);
      }
    }).catchError((e) {
      log('Error loading custom API URL: $e');
    });

    // Setup Interceptors for both
    _setupInterceptors(_dio);
    _setupInterceptors(_leaveDio);
  }

  void _setupInterceptors(Dio dioInstance) {
    // Logging Interceptor (Minimal to prevent lag)
    if (kDebugMode) {
      dioInstance.interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true, // Show only errors
      ));
    }

    // Token Interceptor
    dioInstance.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Accept'] = 'application/json';
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('jwt_token');
          await prefs.remove('user_data');
          onUnauthorized?.call();
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
        return handler.next(error);
      },
    ));
  }

  // ─── MAIN API METHODS (Port 8000) ──────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final deviceDetails = await DeviceInfoService.getDeviceDetails();
      final response = await _dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          'device_id': deviceDetails.deviceId,
          'device_name': deviceDetails.deviceName,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/profile');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMasterData() async {
    try {
      final response = await _dio.get('/get-master-data');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAttendance({String? month, String? year}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _leaveDio.get('/attendance', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> markAttendance({
    required String type,
    double? latitude,
    double? longitude,
    String? imagePath,
    String? zoneId,
  }) async {
    try {
      final deviceDetails = await DeviceInfoService.getDeviceDetails();
      final Map<String, dynamic> fields = {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toString().substring(0, 19),
        'zone_id': zoneId ?? '1',
        'device_id': deviceDetails.deviceId,
        'device_name': deviceDetails.deviceName,
        'imei': deviceDetails.deviceId,
        'status': 'verified',
      };

      FormData formData = FormData.fromMap(fields);

      if (imagePath != null && imagePath.isNotEmpty) {
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split('/').last,
          ),
        ));
      }

      final response = await _leaveDio.post(
        '/submit-attendance',
        data: formData,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getZones({bool all = false}) async {
    try {
      final response = await _leaveDio.get('/zones', queryParameters: all ? {'all': 'true'} : null);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> requestDeviceChange({required String reason}) async {
    try {
      final deviceDetails = await DeviceInfoService.getDeviceDetails();
      final response = await _dio.post(
        '/request-device-change',
        data: {
          'reason': reason,
          'new_device_id': deviceDetails.deviceId,
          'new_device_name': deviceDetails.deviceName,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── LEAVE API METHODS (Port 8001) ──────────────────────────────
  Future<Map<String, dynamic>> applyLeave({
    required String employeeId,
    required String leaveType,
    required String formDate,
    required String toDate,
    required String reason,
    double? days,
  }) async {
    try {
      final response = await _leaveDio.post(
        '/apply',
        data: {
          'employee_id': employeeId,
          'leave_type': leaveType,
          'form_date': formDate,
          'to_date': toDate,
          'reason': reason,
          'days': days,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {
        'status': 'error',
        'message': 'A server or database issue occurred. Please contact your system administrator.',
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getLeaveBalance() async {
    try {
      final response = await _leaveDio.get('/leave/balance');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getLeaves() async {
    try {
      final response = await _leaveDio.get('/leaves');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Error Handler ─────────────────────────────────────────────
  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      String? rawMsg;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error') && data['error'] != null) {
          rawMsg = data['error'].toString();
        } else if (data.containsKey('message') && data['message'] != null) {
          rawMsg = data['message'].toString();
        }
      } else if (data is String) {
        rawMsg = data;
      }

      final statusCode = e.response!.statusCode;
      if (_isDatabaseOrServerIssue(rawMsg ?? '', statusCode)) {
        return 'A required server or database component is missing. Please contact your system administrator.';
      }

      if (rawMsg != null && rawMsg.trim().isNotEmpty) {
        if (rawMsg.contains('<html') || rawMsg.contains('<!DOCTYPE') || rawMsg.contains('<body') || rawMsg.contains('<head')) {
          return 'A server or database issue occurred while processing your request. Please contact your system administrator.';
        }
        return rawMsg;
      }

      if (statusCode == 500) {
        return 'Internal server error occurred. Please contact your system administrator.';
      }
      return 'Server error ($statusCode). Please contact your system administrator.';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server. Please verify your connection or contact administrator.';
    } else {
      return 'An unexpected issue occurred. Please contact your system administrator.';
    }
  }

  bool _isDatabaseOrServerIssue(String msg, int? statusCode) {
    if (statusCode == 500) return true;
    final lower = msg.toLowerCase();
    return lower.contains('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<title>redirecting') ||
        lower.contains('sqlstate') ||
        lower.contains('queryexception') ||
        lower.contains('pdoexception') ||
        (lower.contains('table') && lower.contains('exist')) ||
        lower.contains('column not found') ||
        lower.contains('syntax error') ||
        lower.contains('access violation') ||
        (lower.contains('database') && lower.contains('error'));
  }
}