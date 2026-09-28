// ============================================================
// 📁 lib/features/attendance/screens/employee_attendance_screen.dart
// ============================================================
// Dashboard Screen for Employees
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/employee_attendance_provider.dart';
import 'check_in_screen.dart';
import '../../leave/providers/leave_provider.dart';
import '../../leave/models/leave_model.dart';
import '../../leave/screens/employee_leave_screen.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> with WidgetsBindingObserver {
  late int _leaveFilterMonth;
  late int _leaveFilterYear;
  final List<int> _yearsList = [];
  bool _isLocationDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _leaveFilterMonth = now.month;
    _leaveFilterYear = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptLocation();
      context.read<LeaveProvider>().loadLeaves();
      context.read<EmployeeAttendanceProvider>().loadMyAttendance();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndPromptLocation();
    }
  }

  void _initializeYearsList(String? joiningDateStr) {
    if (_yearsList.isNotEmpty) return;
    
    final now = DateTime.now();
    int startYear = now.year - 2; // Default fallback: last 3 years
    
    if (joiningDateStr != null && joiningDateStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(joiningDateStr);
        startYear = parsed.year;
      } catch (_) {
        try {
          final parsed = DateFormat('dd MMM yyyy').parse(joiningDateStr);
          startYear = parsed.year;
        } catch (_) {}
      }
    }
    
    if (startYear > now.year) {
      startYear = now.year;
    }
    
    _yearsList.clear();
    for (int y = now.year; y >= startYear; y--) {
      _yearsList.add(y);
    }
    
    if (!_yearsList.contains(_leaveFilterYear)) {
      _leaveFilterYear = _yearsList.first;
    }
  }

  List<int> _getActiveMonths(String? joiningDateStr) {
    int joiningYear = 0;
    int joiningMonth = 1;
    
    if (joiningDateStr != null && joiningDateStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(joiningDateStr);
        joiningYear = parsed.year;
        joiningMonth = parsed.month;
      } catch (_) {
        try {
          final parsed = DateFormat('dd MMM yyyy').parse(joiningDateStr);
          joiningYear = parsed.year;
          joiningMonth = parsed.month;
        } catch (_) {}
      }
    }
    
    if (_leaveFilterYear == joiningYear) {
      return List.generate(12 - joiningMonth + 1, (index) => joiningMonth + index);
    }
    
    return List.generate(12, (index) => index + 1);
  }

  DateTime? _parseAnyDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains(RegExp(r'[a-zA-Z]'))) {
        return DateFormat('dd MMM yyyy').parse(dateStr);
      } else {
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      }
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    _initializeYearsList(user?.joiningDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildStickyHeader(user, context),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTodayCard(context),
                _buildQuickActions(context),
                _buildStatsRow(),
                _buildLeaveOverviewSection(context),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(AuthUser? user, BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 62.h;

    return SliverAppBar(
      expandedHeight: headerHeight,
      collapsedHeight: headerHeight,
      toolbarHeight: headerHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: null,
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome Back!', style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.white70)),
                            Text(user?.name ?? 'Employee', style: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18.r,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(AppHelpers.getInitials(user?.name ?? 'Employee'), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 8.r,
                              height: 8.r,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.5.r,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context) {
    return Consumer<EmployeeAttendanceProvider>(
      builder: (_, provider, __) {
        final authUser = context.watch<AuthProvider>().currentUser;
        final isHoldUser = authUser?.attendanceFlag?.toLowerCase() == 'hold';
        final today = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());

        return Container(
          margin: EdgeInsets.all(16.r),
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20.r)),
          child: Column(
            children: [
              Text(today, style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.white70)),
              SizedBox(height: 16.h),
              if (isHoldUser) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 24.sp),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              'Biometric Machine Attendance Only',
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'App attendance is disabled for your account. Please mark attendance using the office biometric fingerprint machine.',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else if (provider.isCompletedToday) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Today\'s Attendance Completed',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!provider.isCheckedIn) ...[
                _actionButton(
                  icon: Icons.login_rounded, 
                  label: 'Submit Attendance', 
                  color: AppColors.success, 
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckInScreen()),
                    );
                  },
                ),
              ]
              else
                _actionButton(
                  icon: Icons.logout_rounded, 
                  label: 'Punch Out', 
                  color: AppColors.error, 
                  onTap: () async {
                    // Show non-dismissible loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogCtx) => Center(
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          child: Padding(
                            padding: EdgeInsets.all(20.r),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                SizedBox(height: 16.h),
                                Text(
                                  'Locking GPS & Logging Out...',
                                  style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    try {
                      final locService = LocationService();
                      await locService.checkLocationServices();
                      await locService.requestPermission();
                      final locationData = await locService.getCurrentLocation();
                      final lat = locationData['latitude'] as double? ?? 0.0;
                      final lon = locationData['longitude'] as double? ?? 0.0;

                      final success = await provider.checkOut(
                        latitude: lat,
                        longitude: lon,
                      );

                      if (context.mounted) {
                        Navigator.pop(context); // Pop the loading dialog
                      }

                      if (success && context.mounted) {
                        AppHelpers.showSuccess(context, 'Logged Out Successfully!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Pop the loading dialog
                        AppHelpers.showError(context, e.toString());
                      }
                    }
                  }
                ),
              if (provider.isCheckedIn && provider.currentCheckInTime != null) ...[
                SizedBox(height: 12.h),
                Text('Logged in at: ${provider.currentCheckInTime}', style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.white70)),
                if (provider.currentLateDuration != null && provider.currentLateDuration!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12.r)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, color: AppColors.warning, size: 12.sp),
                        SizedBox(width: 4.w),
                        Text('Late by: ${provider.currentLateDuration}', style: GoogleFonts.poppins(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.warning)),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.r, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.read<NavigationProvider>().setIndex(1);
              },
              child: _quickActionCard(
                icon: Icons.calendar_month_rounded,
                title: 'View Attendance',
                subtitle: 'Tap to view calendar',
                color: AppColors.primary,
                bgColor: AppColors.primarySurface,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeLeaveScreen()),
                );
              },
              child: _quickActionCard(
                icon: Icons.event_note_rounded,
                title: 'Leave Management',
                subtitle: 'Tap to apply leave',
                color: AppColors.secondary,
                bgColor: AppColors.secondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14.r)),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(title, style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<EmployeeAttendanceProvider>(
      builder: (_, provider, __) {
        final now = DateTime.now();
        final Set<String> uniqueYearlyPresentDates = {};
        final Set<String> uniqueYearlyLateDates = {};

        for (final r in provider.records) {
          try {
            DateTime recordDate;
            if (r.date.contains(RegExp(r'[a-zA-Z]'))) {
              recordDate = DateFormat('dd MMM yyyy').parse(r.date);
            } else {
              recordDate = DateFormat('yyyy-MM-dd').parse(r.date);
            }
            if (recordDate.year == now.year) {
              final dateKey = DateFormat('yyyy-MM-dd').format(recordDate);
              final s = r.status.toLowerCase().trim();
              if (s == 'present' || s == 'late' || s == 'late in' || s == 'half day' || s == 'tour' || s == 'early out') {
                uniqueYearlyPresentDates.add(dateKey);
              }
              if (s == 'late' || s == 'late in') {
                uniqueYearlyLateDates.add(dateKey);
              }
            }
          } catch (_) {}
        }

        int yearlyPresent = uniqueYearlyPresentDates.length;
        int yearlyLate = uniqueYearlyLateDates.length;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.r),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              _statItem('Present (Yearly)', yearlyPresent, AppColors.success),
              _statDivider(),
              _statItem('Late (Yearly)', yearlyLate, AppColors.warning),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.w700, color: color)),
          SizedBox(height: 4.h),
          Text(label, style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 30.h, color: AppColors.border);





  Widget _buildLeaveOverviewSection(BuildContext context) {
    final leaveProv = context.watch<LeaveProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final activePolicies = leaveProv.policies.isNotEmpty
        ? leaveProv.policies
        : const [
            LeavePolicy(
              id: 'CL',
              title: 'Casual Leave',
              description: 'Assam Govt: 12 days/year.',
              totalDays: 12,
              iconName: 'event_note_rounded',
              colorValue: 0xFF1E40AF,
            ),
            LeavePolicy(
              id: 'EL',
              title: 'Earned Leave',
              description: 'Assam Govt Rules: 30 days/year.',
              totalDays: 30,
              iconName: 'beach_access_rounded',
              colorValue: 0xFF10B981,
            ),
            LeavePolicy(
              id: 'HPL',
              title: 'Half Pay Leave',
              description: 'Earned at 20 days/year.',
              totalDays: 20,
              iconName: 'history_edu_rounded',
              colorValue: 0xFFF59E0B,
            ),
            LeavePolicy(
              id: 'COL',
              title: 'Commuted Leave',
              description: 'Medical ground leave with Full Pay.',
              totalDays: 10,
              iconName: 'medical_services_outlined',
              colorValue: 0xFFEF4444,
            ),
          ];

    String formatDays(double value) {
      return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    }

    final myRequests = leaveProv.allRequests.where((r) => r.employeeId == user?.id).toList();
    final myCompOffs = leaveProv.compOffReports.where((c) => c.employeeId == user?.id && c.status == 'approved').toList();

    final activeMonths = _getActiveMonths(user?.joiningDate);
    if (!activeMonths.contains(_leaveFilterMonth)) {
      _leaveFilterMonth = activeMonths.first;
    }

    // 2. Calculate Total Allowed & Remaining (All policies combined) for the selected year
    double totalAllowed = 0;
    double totalUsed = 0;
    for (var p in activePolicies) {
      double allowed = p.totalDays.toDouble();
      if (p.id == 'CO') {
        allowed += myCompOffs.where((c) {
          final date = _parseAnyDate(c.dutyDate);
          return date != null && date.year == _leaveFilterYear;
        }).length;
      }
      totalAllowed += allowed;

      double usedInYear = 0.0;
      for (var r in myRequests) {
        final isTypeMatch = r.leaveType.toLowerCase() == p.title.toLowerCase() ||
                            r.leaveType.toLowerCase() == p.id.toLowerCase();
        if (isTypeMatch && (r.status == 'approved' || r.status == 'closed')) {
          final fromDate = _parseAnyDate(r.fromDate);
          if (fromDate != null && fromDate.year == _leaveFilterYear) {
            usedInYear += r.days;
          }
        }
      }
      totalUsed += usedInYear;
    }
    double totalRemaining = totalAllowed - totalUsed;
    if (totalRemaining < 0) totalRemaining = 0;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2))
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: My Leaves & Dropdowns
          Row(
            children: [
              Text(
                'My Leaves ($_leaveFilterYear)',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: 12.h),

          // Divider
          Container(height: 1, color: AppColors.border.withOpacity(0.5)),
          SizedBox(height: 12.h),

          // Title for detailed balances
          Text(
            'Leave Type Details',
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),

          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activePolicies.length,
            itemBuilder: (ctx, idx) {
              final policy = activePolicies[idx];
              
              double allowed = policy.totalDays.toDouble();
              if (policy.id == 'CO') {
                allowed += myCompOffs.where((c) {
                  final date = _parseAnyDate(c.dutyDate);
                  return date != null && date.year == _leaveFilterYear;
                }).length;
              }
              
              double usedInYear = 0.0;
              for (var r in myRequests) {
                final isTypeMatch = r.leaveType.toLowerCase() == policy.title.toLowerCase() ||
                                    r.leaveType.toLowerCase() == policy.id.toLowerCase();
                if (isTypeMatch && (r.status == 'approved' || r.status == 'closed')) {
                  final fromDate = _parseAnyDate(r.fromDate);
                  if (fromDate != null && fromDate.year == _leaveFilterYear) {
                    usedInYear += r.days;
                  }
                }
              }

              double remaining = allowed - usedInYear;
              if (remaining < 0) remaining = 0;

              final progress = allowed > 0 ? (remaining / allowed) : 0.0;
              final color = Color(policy.colorValue);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _showLeaveTypeDetails(
                    context: context,
                    policy: policy,
                    allowed: allowed,
                    used: usedInYear,
                    remaining: remaining,
                    myRequests: myRequests,
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              AppHelpers.getLeaveIcon(policy.iconName),
                              color: color,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  policy.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Total Allowed: ${formatDays(allowed)}  |  Used: ${formatDays(usedInYear)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.sp,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${formatDays(remaining)} Left',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: color.withOpacity(0.1),
                          color: color,
                          minHeight: 4.h,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  void _showLeaveTypeDetails({
    required BuildContext context,
    required LeavePolicy policy,
    required double allowed,
    required double used,
    required double remaining,
    required List<LeaveRequest> myRequests,
  }) {
    final color = Color(policy.colorValue);
    
    // Filter requests for this specific leave type in the current year
    final takenLeaves = myRequests.where((r) {
      final isTypeMatch = r.leaveType.toLowerCase() == policy.title.toLowerCase() ||
                          r.leaveType.toLowerCase() == policy.id.toLowerCase();
      final isApproved = r.status == 'approved' || r.status == 'closed';
      if (isTypeMatch && isApproved) {
        final fromDate = _parseAnyDate(r.fromDate);
        return fromDate != null && fromDate.year == _leaveFilterYear;
      }
      return false;
    }).toList();

    // Sort by fromDate descending (newest first)
    takenLeaves.sort((a, b) {
      final aDate = _parseAnyDate(a.fromDate) ?? DateTime.now();
      final bDate = _parseAnyDate(b.fromDate) ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    String formatDays(double value) {
      return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    }

    String formatDateWithDay(String dateStr) {
      final dt = _parseAnyDate(dateStr);
      if (dt == null) return dateStr;
      return DateFormat('dd MMM yyyy (EEEE)').format(dt);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, MediaQuery.of(context).padding.bottom + 20.h),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom sheet drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Header: Icon + Title + Close Button
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      AppHelpers.getLeaveIcon(policy.iconName),
                      color: color,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy.title,
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Current Year: $_leaveFilterYear',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Summary Section Card
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Allowed', formatDays(allowed), color),
                    Container(width: 1, height: 40.h, color: color.withOpacity(0.15)),
                    _buildSummaryItem('Used', formatDays(used), color),
                    Container(width: 1, height: 40.h, color: color.withOpacity(0.15)),
                    _buildSummaryItem('Remaining', formatDays(remaining), color, isHighlight: true),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Leaves History List
              Text(
                'Leaves Taken (${takenLeaves.length})',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),

              Expanded(
                child: takenLeaves.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48.sp, color: Colors.grey[300]),
                            SizedBox(height: 12.h),
                            Text(
                              'No leaves taken in $_leaveFilterYear',
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: takenLeaves.length,
                        itemBuilder: (context, index) {
                          final req = takenLeaves[index];
                          final isMultiDay = req.fromDate != req.toDate;
                          return Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(14.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadow.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isMultiDay ? 'Leave Duration' : 'Leave Date',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.sp,
                                              color: AppColors.textTertiary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          if (isMultiDay) ...[
                                            Text(
                                              'From: ${formatDateWithDay(req.fromDate)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              'To:     ${formatDateWithDay(req.toDate)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              formatDateWithDay(req.fromDate),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(100.r),
                                      ),
                                      child: Text(
                                        '${formatDays(req.days)} ${req.days == 1 ? "Day" : "Days"}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (req.reason.isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Divider(color: AppColors.border, height: 1),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Reason',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.sp,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    req.reason,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.sp,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color themeColor, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isHighlight ? 20.sp : 16.sp,
            fontWeight: FontWeight.w800,
            color: isHighlight ? themeColor : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _checkAndPromptLocation() async {
    if (_isLocationDialogShowing) return;

    // 1. Check & Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionRequiredDialog();
      }
      return; // Stop here if permission not granted
    }

    // 2. Check if location services (GPS) are enabled
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      if (mounted) {
        _showGpsRequiredDialog();
      }
    }
  }

  void _showPermissionRequiredDialog() {
    setState(() {
      _isLocationDialogShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.error, size: 24.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Permission Required',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16.sp),
                ),
              ),
            ],
          ),
          content: Text(
            'Location permission is required for attendance management. Please grant location access in App Settings.',
            style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setState(() {
                  _isLocationDialogShowing = false;
                });
                Navigator.pop(dialogCtx);
                await Geolocator.openAppSettings();
              },
              child: Text(
                'Open Settings',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGpsRequiredDialog() {
    setState(() {
      _isLocationDialogShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(Icons.gps_off_rounded, color: AppColors.warning, size: 24.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'GPS is Turned Off',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16.sp),
                ),
              ),
            ],
          ),
          content: Text(
            'Location services (GPS) must be enabled to check in/out and view attendance. Please turn on GPS.',
            style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setState(() {
                  _isLocationDialogShowing = false;
                });
                Navigator.pop(dialogCtx);
                await Geolocator.openLocationSettings();
              },
              child: Text(
                'Turn On GPS',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}
