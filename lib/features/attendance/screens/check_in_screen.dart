// ============================================================
// 📁 lib/features/attendance/screens/check_in_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/office_settings_provider.dart';
import '../providers/employee_attendance_provider.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final LocationService _locationService = LocationService();
  final ApiService _api = ApiService();
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  double? _latitude;
  double? _longitude;
  
  bool _isLoading = true;
  bool _isLocationError = false;
  String _locationStatus = 'Locking GPS signal...';
  bool _isSubmitting = false;
  bool _showShutterFlash = false;

  List<dynamic> _assignedZones = [];

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLocationError = false;
      _locationStatus = 'Initializing services...';
    });
    
    // 0. Load Office Settings from Backend
    try {
      await context.read<OfficeSettingsProvider>().fetchOfficeSettings();
    } catch (e) {
      debugPrint('❌ Failed to fetch office settings: $e');
    }
    
    // Load assigned zones
    try {
      final zoneResponse = await _api.getZones();
      if (zoneResponse.containsKey('zones')) {
        _assignedZones = zoneResponse['zones'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user zones: $e');
    }
    
    // 1. Camera Init
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras![0],
        );
        _cameraController = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Camera error: $e');
    }

    // 2. Location Lock
    await _fetchGPSCoordinates();
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchGPSCoordinates() async {
    try {
      if (mounted) {
        setState(() {
          _locationStatus = 'Searching GPS satellites...';
          _isLocationError = false;
        });
      }

      final servicesEnabled = await _locationService.checkLocationServices();
      if (!servicesEnabled) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location services disabled';
            _isLocationError = true;
          });
        }
        return;
      }

      final permissionGranted = await _locationService.requestPermission();
      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location permission denied';
            _isLocationError = true;
          });
        }
        return;
      }

      final locationData = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _latitude = locationData['latitude'] as double?;
          _longitude = locationData['longitude'] as double?;
          
          if (_latitude != null && _latitude != 0.0) {
            _locationStatus = 'GPS lock stable (3m accuracy)';
            _isLocationError = false;
          } else {
            _locationStatus = 'Failed to lock GPS signal';
            _isLocationError = true;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'GPS Error: $e';
          _isLocationError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  bool _isPointInPolygon(double latitude, double longitude, List<dynamic> vertices) {
    if (vertices.length < 3) return false;

    bool isInside = false;
    int j = vertices.length - 1;

    for (int i = 0; i < vertices.length; i++) {
      final pi = vertices[i];
      final pj = vertices[j];

      final latI = (pi['lat'] ?? pi['latitude'] ?? 0.0) as double;
      final lngI = (pi['lng'] ?? pi['longitude'] ?? 0.0) as double;

      final latJ = (pj['lat'] ?? pj['latitude'] ?? 0.0) as double;
      final lngJ = (pj['lng'] ?? pj['longitude'] ?? 0.0) as double;

      if ((lngI > longitude) != (lngJ > longitude) &&
          (latitude < (latJ - latI) * (longitude - lngI) / (lngJ - lngI) + latI)) {
        isInside = !isInside;
      }
      j = i;
    }

    return isInside;
  }

  Map<String, double> _getPolygonCenter(List<dynamic> vertices) {
    if (vertices.isEmpty) return {'latitude': 0.0, 'longitude': 0.0};
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (var v in vertices) {
      sumLat += (v['lat'] ?? v['latitude'] ?? 0.0) as double;
      sumLng += (v['lng'] ?? v['longitude'] ?? 0.0) as double;
    }
    return {
      'latitude': sumLat / vertices.length,
      'longitude': sumLng / vertices.length,
    };
  }

  List<dynamic> _parseCoordinates(dynamic coords) {
    if (coords == null) return [];
    if (coords is List) return coords;
    if (coords is String) {
      try {
        final decoded = json.decode(coords);
        if (decoded is List) return decoded;
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<OfficeSettingsProvider>().settings;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final bool noGeofenceRequired = user?.noZoneRequired?.toLowerCase() == 'yes' || !settings.isLocationTrackingEnabled;

    // Calculate distance and geofence status
    double distance = 0.0;
    bool isWithinGeofence = false;
    String activeOfficeName = 'Unknown Location';
    dynamic matchedZone;

    if (noGeofenceRequired) {
      isWithinGeofence = true;
      activeOfficeName = 'No Zone Required';
      if (_latitude != null && _longitude != null && _assignedZones.isNotEmpty) {
        // Fallback to closest zone for displaying on map visualizer
        double minDistance = double.infinity;
        for (var zone in _assignedZones) {
          final coords = _parseCoordinates(zone['coordinates']);
          final center = _getPolygonCenter(coords);
          final dist = _locationService.calculateDistance(
            lat1: _latitude!,
            lon1: _longitude!,
            lat2: center['latitude']!,
            lon2: center['longitude']!,
          ) * 1000;
          if (dist < minDistance) {
            minDistance = dist;
            matchedZone = zone;
            distance = dist;
          }
        }
      }
    } else {
      if (_latitude != null && _longitude != null) {
        double minDistance = double.infinity;
        for (var zone in _assignedZones) {
          final coords = _parseCoordinates(zone['coordinates']);
          final inside = _isPointInPolygon(_latitude!, _longitude!, coords);
          if (inside) {
            isWithinGeofence = true;
            activeOfficeName = zone['name'] ?? 'Assigned Location';
            matchedZone = zone;
            distance = 0.0;
            break;
          } else {
            final center = _getPolygonCenter(coords);
            final dist = _locationService.calculateDistance(
              lat1: _latitude!,
              lon1: _longitude!,
              lat2: center['latitude']!,
              lon2: center['longitude']!,
            ) * 1000;
            if (dist < minDistance) {
              minDistance = dist;
              activeOfficeName = zone['name'] ?? 'Assigned Location';
              matchedZone = zone;
              distance = dist;
            }
          }
        }

        if (!isWithinGeofence && _assignedZones.isNotEmpty) {
          activeOfficeName = 'Nearest: $activeOfficeName';
        } else if (_assignedZones.isEmpty) {
          activeOfficeName = 'No Locations Assigned';
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56.w,
                  height: 56.h,
                  child: const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3.5,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Initializing Verification...',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Locking GPS signal & starting camera preview',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : Stack(
            children: [
              // 1. Full Screen Camera background
              Positioned.fill(
                child: _buildFullscreenCamera(),
              ),

              // 2. Dark Gradient Overlay (top and bottom shadows for text readability)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.25, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Floating AppBar Header (Overlaid)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Row(
                      children: [
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.white.withOpacity(0.2),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Check In',
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 40.w), // Balance back button
                      ],
                    ),
                  ),
                ),
              ),

              // Camera shutter flash pulse
              if (_showShutterFlash)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

              // 4. Overlaid Bottom Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOfficeInfoCard(activeOfficeName),
                        SizedBox(height: 10.h),
                        _buildLocationStatusCard(activeOfficeName, distance, isWithinGeofence, matchedZone),
                        SizedBox(height: 14.h),
                        _buildSubmitButton(isWithinGeofence, matchedZone),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Full Screen Glassmorphic Submitting Loader Overlay
              if (_isSubmitting)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: Colors.black.withOpacity(0.65),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 56.w,
                                height: 56.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3.5,
                                ),
                              ),
                              SizedBox(height: 28.h),
                              Text(
                                'Verifying Coordinates...',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                'Please wait while we log your attendance',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildFullscreenCamera() {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 48),
              SizedBox(height: 12),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final previewSize = _cameraController!.value.previewSize;
    if (previewSize == null) {
      return Container(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildOfficeInfoCard(String officeName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withOpacity(0.3), // Translucent indigo
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.business_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  officeName,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5.sp, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8.r)),
                child: Text('GPS LOCK', style: GoogleFonts.poppins(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard(String officeName, double distance, bool isWithinGeofence, dynamic matchedZone) {
    final bool isLocking = _latitude == null;

    double officeLat = 0.0;
    double officeLng = 0.0;
    if (matchedZone != null) {
      final coords = _parseCoordinates(matchedZone['coordinates']);
      final center = _getPolygonCenter(coords);
      officeLat = center['latitude'] ?? 0.0;
      officeLng = center['longitude'] ?? 0.0;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4), // Glassmorphic white
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verification Status',
                    style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  SizedBox(
                    height: 24.h,
                    width: 24.w,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 18.sp),
                      onPressed: _fetchGPSCoordinates,
                    ),
                  )
                ],
              ),
              SizedBox(height: 6.h),

              if (isLocking)
                LocationPulseAnimation(isScanning: isLocking && !_isLocationError)
              else ...[
                MiniMapVisualizer(
                  latitude: _latitude!,
                  longitude: _longitude!,
                  officeLatitude: officeLat,
                  officeLongitude: officeLng,
                  distanceMeters: distance,
                  allowedRadiusMeters: 200.0,
                ),
                SizedBox(height: 8.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pin_drop_rounded, size: 12.sp, color: Colors.white70),
                    SizedBox(width: 4.w),
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(6)}  |  Lon: ${_longitude!.toStringAsFixed(6)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                if (!isWithinGeofence)
                  Container(
                    margin: EdgeInsets.only(top: 8.h),
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F), // Red background
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFB71C1C)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16.sp),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'You are currently outside the authorized office location. Please move within the office premises to check in.',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              SizedBox(height: 6.h),
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _isLocationError
                        ? const Color(0xFFD32F2F) // Red background for error
                        : (isLocking
                            ? Colors.white.withOpacity(0.15) // Translucent grey for searching
                            : const Color(0xFF2E7D32)), // Green background for stable
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: _isLocationError
                          ? const Color(0xFFB71C1C)
                          : (isLocking
                              ? Colors.white.withOpacity(0.25)
                              : const Color(0xFF1B5E20)),
                    ),
                  ),
                  child: Text(
                    _locationStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isWithinGeofence, dynamic matchedZone) {
    final bool hasLock = _latitude != null && _longitude != null;

    if (!hasLock) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(Icons.gps_off_rounded, size: 18.sp, color: Colors.white70),
          label: Text(
            _isLocationError ? 'Location Access Required' : 'Locking GPS signal...',
            style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white70)
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[400],
            disabledBackgroundColor: Colors.grey[400],
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            elevation: 0,
          ),
        ),
      );
    }

    if (!isWithinGeofence) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _fetchGPSCoordinates, // Allow re-fetching to check updated location
          icon: Icon(Icons.location_off_rounded, size: 18.sp, color: Colors.white),
          label: Text(
            'You are not in office location',
            style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white)
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F), // Red background
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            elevation: 0,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isSubmitting) ? null : () async {
          setState(() => _isSubmitting = true);

          try {
            XFile? capturedFile;

            if (_isCameraInitialized && _cameraController != null) {
              try {
                // Shutter flash visual pulse
                if (mounted) {
                  setState(() => _showShutterFlash = true);
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (mounted) setState(() => _showShutterFlash = false);
                }
                capturedFile = await _cameraController!.takePicture();
              } catch (e) {
                debugPrint('❌ Inline capture failed, launching native camera picker: $e');
              }
            }

            if (capturedFile == null) {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.camera,
                preferredCameraDevice: CameraDevice.front,
                imageQuality: 100,
              );
              if (pickedFile != null) {
                capturedFile = XFile(pickedFile.path);
              }
            }

            if (capturedFile == null) {
              setState(() => _isSubmitting = false);
              return;
            }

            if (!mounted) return;
            final zoneIdVal = matchedZone != null ? matchedZone['id'].toString() : '1';
            final success = await context.read<EmployeeAttendanceProvider>().checkIn(
              latitude: _latitude!,
              longitude: _longitude!,
              imagePath: capturedFile.path,
              zoneId: zoneIdVal,
            );

            if (success && mounted) {
              AppHelpers.showSuccess(context, 'Attendance marked successfully!');
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              AppHelpers.showError(context, e.toString());
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
        icon: _isSubmitting
          ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(Icons.camera_alt_rounded, size: 20.sp),
        label: Text(
          _isSubmitting ? 'Submitting Attendance...' : 'Capture & Check In',
          style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981), // Emerald green
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          elevation: 2,
        ),
      ),
    );
  }
}

class LocationPulseAnimation extends StatefulWidget {
  final bool isScanning;
  const LocationPulseAnimation({super.key, required this.isScanning});

  @override
  State<LocationPulseAnimation> createState() => _LocationPulseAnimationState();
}

class _LocationPulseAnimationState extends State<LocationPulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(LocationPulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 100.h,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isScanning)
                ...List.generate(3, (index) {
                  final double delay = index * 0.33;
                  final double progress = (_controller.value - delay + 1.0) % 1.0;
                  return Container(
                    width: 140.r * progress,
                    height: 140.r * progress,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity((1.0 - progress) * 0.3),
                    ),
                  );
                }),
              Container(
                width: 60.r,
                height: 60.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF2962FF), Color(0xFF1A237E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withOpacity(0.3),
                      blurRadius: 10.r,
                      spreadRadius: 1.r,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isScanning ? Icons.gps_fixed : Icons.location_on,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MiniMapVisualizer extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double officeLatitude;
  final double officeLongitude;
  final double distanceMeters;
  final double allowedRadiusMeters;

  const MiniMapVisualizer({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWithin = distanceMeters <= allowedRadiusMeters;

    // Visual positioning adjustments inside the compact card
    double userDx = 12.w;
    double userDy = -6.h;

    if (!isWithin) {
      userDx = 50.w;
      userDy = 20.h;
    }

    return Container(
      height: 110.h, // Compact height
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.r),
        child: Stack(
          children: [
            // 1. Grid & Street Background Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _MapGridPainter(),
              ),
            ),

            // 2. Allowed radius geofence circle (Office centered)
            Center(
              child: Container(
                width: 60.r,
                height: 60.r,
                decoration: BoxDecoration(
                  color: const Color(0x1500C853),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x6000C853),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // 3. Office Marker (Center)
            Center(
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: const BoxDecoration(
                  color: Color(0xFF2962FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
              ),
            ),

            // 4. Connective dotted line if outside geofence
            if (!isWithin)
              Center(
                child: CustomPaint(
                  painter: _DottedLinePainter(
                    endPoint: Offset(userDx, userDy),
                  ),
                ),
              ),

            // 5. User Marker
            Center(
              child: Transform.translate(
                offset: Offset(userDx, userDy),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        color: isWithin ? const Color(0xFF00C853) : const Color(0xFFFF3D00),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isWithin ? const Color(0xFF00C853) : const Color(0xFFFF3D00)).withOpacity(0.4),
                            blurRadius: 4.r,
                            spreadRadius: 1.r,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_pin_circle_rounded,
                        color: Colors.white,
                        size: 13.sp,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        isWithin ? 'You' : '${distanceMeters.toStringAsFixed(0)}m away',
                        style: GoogleFonts.poppins(
                          fontSize: 6.5.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }
    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }

    // Draw street network (roads)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Path definitions for abstract roads
    final roads = [
      Path()
        ..moveTo(0, size.height * 0.45)
        ..lineTo(size.width, size.height * 0.55),
      Path()
        ..moveTo(size.width * 0.35, 0)
        ..quadraticBezierTo(
            size.width * 0.45, size.height * 0.5, size.width * 0.25, size.height)
    ];

    for (final road in roads) {
      canvas.drawPath(road, roadBorderPaint);
      canvas.drawPath(road, roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
  final Offset endPoint;
  _DottedLinePainter({required this.endPoint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF3D00)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3.0;
    const double dashSpace = 3.0;

    double distance = endPoint.distance;
    Offset direction = endPoint / distance;

    double currentDist = 0.0;
    while (currentDist < distance) {
      Offset p1 = direction * currentDist;
      currentDist = (currentDist + dashWidth).clamp(0, distance);
      Offset p2 = direction * currentDist;
      canvas.drawLine(p1, p2, paint);
      currentDist += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
