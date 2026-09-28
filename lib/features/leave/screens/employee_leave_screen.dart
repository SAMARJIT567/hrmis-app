// ============================================================
// 📁 lib/features/leave/screens/employee_leave_screen.dart
// ============================================================
// Leave Screen - NO BOTTOM NAVIGATION (Parent se milega)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../models/leave_model.dart';
import '../../attendance/providers/employee_attendance_provider.dart';


// ─── DATA MODELS ─────────────────────────────────────────────

class EmployeeLeaveRequest {
  final String id;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final double days;
  final String reason;
  final String status; // pending, approved, rejected, closed
  final String appliedOn;
  final String? medicalCertificate;
  final String? fitnessCertificate;
  final String? joiningDate;

  const EmployeeLeaveRequest({
    required this.id,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.appliedOn,
    this.medicalCertificate,
    this.fitnessCertificate,
    this.joiningDate,
  });

  EmployeeLeaveRequest copyWith({
    String? status,
    String? fitnessCertificate,
    String? joiningDate,
  }) {
    return EmployeeLeaveRequest(
      id: id,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      days: days,
      reason: reason,
      status: status ?? this.status,
      appliedOn: appliedOn,
      medicalCertificate: medicalCertificate,
      fitnessCertificate: fitnessCertificate ?? this.fitnessCertificate,
      joiningDate: joiningDate ?? this.joiningDate,
    );
  }
}

class LeaveBalance {
  final String type;
  final int total;
  final int used;
  final Color color;
  final IconData icon;

  int get remaining => total - used;

  const LeaveBalance({
    required this.type,
    required this.total,
    required this.used,
    required this.color,
    required this.icon,
  });
}

class WeekRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const WeekRange({
    required this.start,
    required this.end,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

// ─── STATE MANAGEMENT ────────────────────────────────────────


class EmployeeLeaveProvider extends ChangeNotifier {
  final AuthUser? user;
  List<EmployeeLeaveRequest> _requests = [];
  List<CompOffCredit> _globalCompOffReports = [];
  List<LeavePolicy> _globalPolicies = [];
  
  bool _isLoading = false;
  bool _isSubmitting = false;

  List<EmployeeLeaveRequest> get requests => _requests;
  List<CompOffCredit> get compOffCredits => _globalCompOffReports.where((r) => r.employeeId == user?.id).toList();
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;

  void updateGlobalPolicies(List<LeavePolicy> policies) {
    _globalPolicies = policies;
    notifyListeners();
  }

  List<LeaveBalance> get balances {
    final List<LeavePolicy> policiesToUse = _globalPolicies.isNotEmpty 
        ? _globalPolicies 
        : LeaveProvider().policies;

    return policiesToUse.map((policy) {
      int total = policy.totalDays;

      if (policy.id == 'CO') {
        total = policy.totalDays + compOffCredits.where((c) => c.status == 'approved').length;
      }

      return LeaveBalance(
        type: policy.title,
        total: total,
        used: policy.usedDays,
        color: Color(policy.colorValue),
        icon: AppHelpers.getLeaveIcon(policy.iconName),
      );
    }).toList();
  }

  int get pendingCount => _requests.where((r) => r.status == 'pending').length;
  int get approvedCount => _requests.where((r) => r.status == 'approved').length;
  int get rejectedCount => _requests.where((r) => r.status == 'rejected').length;

  bool get isCompOffLimitReached => compOffReportsThisMonth >= 2;

  int get compOffReportsThisMonth {
    final now = DateTime.now();
    final currentMonth = DateFormat('MMM').format(now);
    final currentYear = DateFormat('yyyy').format(now);
    
    int count = 0;
    for (var credit in compOffCredits) {
      if (credit.dutyDate.contains(currentMonth) && credit.dutyDate.contains(currentYear)) {
        count++;
      }
    }
    return count;
  }

  EmployeeLeaveProvider({this.user});

  void syncWithGlobal(LeaveProvider globalProvider) {
    if (user == null) return;
    
    _requests = globalProvider.allRequests
        .where((r) =>
            r.employeeId == user!.id ||
            (user!.empCode.isNotEmpty && r.employeeId == user!.empCode) ||
            r.employeeId.isEmpty ||
            user!.id.isEmpty)
        .map((r) => EmployeeLeaveRequest(
              id: r.id,
              leaveType: r.leaveType,
              fromDate: r.fromDate,
              toDate: r.toDate,
              days: r.days,
              reason: r.reason,
              status: r.status,
              appliedOn: r.appliedOn,
            ))
        .toList();
    
    _globalCompOffReports = globalProvider.compOffReports;
    _globalPolicies = globalProvider.policies;
    
    _isLoading = false;
    notifyListeners();
  }

  bool isSecondOrFourthSaturday(DateTime date) {
    if (date.weekday != DateTime.saturday) return false;
    int day = date.day;
    return (day >= 8 && day <= 14) || (day >= 22 && day <= 28);
  }

  double calculateCLDuration(DateTime start, DateTime end, {bool isHalfDay = false}) {
    if (isHalfDay) return 0.5;
    int count = 0;
    for (DateTime d = start; d.isBefore(end.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.sunday && !isSecondOrFourthSaturday(d)) {
        count++;
      }
    }
    return count.toDouble();
  }

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> applyLeave({
    required String leaveType, 
    required DateTime fromDate, 
    required DateTime toDate, 
    required String reason, 
    double? customDays,
    required LeaveProvider globalProvider,
  }) async {
    _isSubmitting = true;
    _lastErrorMessage = null;
    notifyListeners();

    final days = customDays ?? (toDate.difference(fromDate).inDays + 1).toDouble();
    final fromDateStr = DateFormat('yyyy-MM-dd').format(fromDate);
    final toDateStr = DateFormat('yyyy-MM-dd').format(toDate);

    final bool success = await globalProvider.applyLeave(
      leaveType: leaveType,
      fromDate: fromDateStr,
      toDate: toDateStr,
      reason: reason,
      days: days,
    );

    if (success) {
      syncWithGlobal(globalProvider);
    } else {
      _lastErrorMessage = globalProvider.lastErrorMessage;
    }
    
    _isSubmitting = false;
    notifyListeners();
    return success;
  }

  Future<bool> logHolidayDuty({
    required DateTime dutyDate, 
    required String reason, 
    required String attachment, 
    String? duration,
    required LeaveProvider globalProvider,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));

    final expiryDate = dutyDate.add(const Duration(days: 30));
    final newCredit = CompOffCredit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: user?.id ?? '',
      employeeName: user?.name ?? 'Employee',
      dutyDate: DateFormat('dd MMM yyyy').format(dutyDate),
      expiryDate: DateFormat('dd MMM yyyy').format(expiryDate),
      reason: reason,
      status: 'pending',
      attachment: attachment,
      duration: duration,
    );

    await globalProvider.addCompOffReport(newCredit);
    
    _isSubmitting = false;
    notifyListeners();
    return true;
  }

  Future<bool> submitJoiningReport({required String requestId, required String fitnessCertificate, required DateTime joiningDate}) async {
    _isSubmitting = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));

    // Closing locally is just for UI feedback
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        status: 'closed',
        fitnessCertificate: fitnessCertificate,
        joiningDate: DateFormat('dd MMM yyyy').format(joiningDate),
      );
    }

    _isSubmitting = false;
    notifyListeners();
    return true;
  }
}

// ─── UI SCREENS ──────────────────────────────────────────────

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({super.key});
  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> with WidgetsBindingObserver {
  String _filterType = 'monthly'; // 'weekly' | 'monthly' | 'yearly'
  late WeekRange _selectedWeek;
  late int _selectedMonth;
  late int _selectedYear;
  
  List<WeekRange> _weeksList = [];
  final List<int> _yearsList = [];
  final List<int> _monthsList = List.generate(12, (index) => index + 1);

  int _activeTab = 0; // 0 for Leaves, 1 for Attendance
  int _attendanceVisibleCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _weeksList = _getRecentWeeks();
    _selectedWeek = _weeksList.first;
    _selectedMonth = now.month;
    _selectedYear = now.year;
    
    // Populate last 3 years
    for (int y = now.year; y >= now.year - 2; y--) {
      _yearsList.add(y);
    }

    // Auto-refresh fresh leaves and logs from backend immediately on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
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
      // Auto-refresh when user switches back to app from browser/admin panel
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    try {
      final leaveProv = Provider.of<LeaveProvider>(context, listen: false);
      final attProv = Provider.of<EmployeeAttendanceProvider>(context, listen: false);
      await Future.wait([
        leaveProv.loadLeaves(),
        attProv.loadMyAttendance(),
      ]);
    } catch (_) {}
  }

  List<WeekRange> _getRecentWeeks() {
    final List<WeekRange> weeks = [];
    final now = DateTime.now();
    
    // Find the start of the current week (Sunday)
    DateTime currentSunday = now.subtract(Duration(days: now.weekday % 7));
    currentSunday = DateTime(currentSunday.year, currentSunday.month, currentSunday.day);

    for (int i = 0; i < 8; i++) {
      final start = currentSunday.subtract(Duration(days: i * 7));
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      String label = "";
      if (i == 0) {
        label = "This Week (${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)})";
      } else if (i == 1) {
        label = "Last Week (${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)})";
      } else {
        label = "${i} Weeks Ago (${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)})";
      }
      weeks.add(WeekRange(start: start, end: end, label: label));
    }
    return weeks;
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

  String _formatDisplayDate(String d) {
    if (d.isEmpty) return 'N/A';
    final dt = _parseAnyDate(d);
    if (dt != null) return DateFormat('dd MMM yyyy').format(dt);
    return d;
  }

  Map<String, DateTime> _getCurrentFilterRange() {
    DateTime start;
    DateTime end;
    
    if (_filterType == 'weekly') {
      start = _selectedWeek.start;
      end = _selectedWeek.end;
    } else if (_filterType == 'monthly') {
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    } else {
      start = DateTime(_selectedYear, 1, 1);
      end = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    }
    
    return {'start': start, 'end': end};
  }

  bool _isLeaveInPeriod(EmployeeLeaveRequest request, DateTime start, DateTime end) {
    final fromDate = _parseAnyDate(request.fromDate);
    final toDate = _parseAnyDate(request.toDate);
    if (fromDate == null || toDate == null) return false;
    
    return fromDate.isBefore(end.add(const Duration(days: 1))) &&
           toDate.isAfter(start.subtract(const Duration(days: 1)));
  }

  bool _isDutyReportInPeriod(CompOffCredit credit, DateTime start, DateTime end) {
    final dutyDate = _parseAnyDate(credit.dutyDate);
    if (dutyDate == null) return false;
    return dutyDate.isAfter(start.subtract(const Duration(days: 1))) &&
           dutyDate.isBefore(end.add(const Duration(days: 1)));
  }

  bool _isAttendanceInPeriod(EmployeeAttendanceRecord record, DateTime start, DateTime end) {
    final recordDate = _parseAnyDate(record.date);
    if (recordDate == null) return false;
    return recordDate.isAfter(start.subtract(const Duration(days: 1))) &&
           recordDate.isBefore(end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return MultiProvider(
      providers: [
        ChangeNotifierProxyProvider<LeaveProvider, EmployeeLeaveProvider>(
          create: (context) => EmployeeLeaveProvider(user: authProvider.currentUser),
          update: (context, leaveProv, employeeLeaveProv) {
            employeeLeaveProv!.syncWithGlobal(leaveProv);
            return employeeLeaveProv;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final employeeLeaveProv = Provider.of<EmployeeLeaveProvider>(context);
          final attendanceProv = Provider.of<EmployeeAttendanceProvider>(context);

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 10.r),
                      children: [
                        _buildLeaveBalanceCard(),
                        _buildActionButtons(context),
                        _buildFilterSection(context),
                        _buildPeriodInsightsCard(employeeLeaveProv, attendanceProv),
                        _buildTabSelector(),
                        _buildTabContent(context, employeeLeaveProv, attendanceProv),
                        SizedBox(height: 100.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top + 15.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18.sp),
              ),
            ),
            SizedBox(width: 15.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Management',
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Apply and track your leaves',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await _refreshData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Records synchronized with server', style: GoogleFonts.poppins(fontSize: 12.sp)),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: _headerIconBtn(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon) => Container(
    width: 38.w,
    height: 38.h,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10.r),
    ),
    child: Icon(icon, color: Colors.white, size: 19.sp),
  );

  Widget _buildLeaveBalanceCard() {
    return Consumer<EmployeeLeaveProvider>(
      builder: (context, provider, __) {
        if (provider.isLoading || provider.balances.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Leave Balances', style: GoogleFonts.poppins(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('${provider.balances.length} Types', style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            SizedBox(
              height: 155.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: provider.balances.length,
                itemBuilder: (context, index) {
                  final balance = provider.balances[index];
                  final progress = balance.total > 0 ? (balance.remaining / balance.total) : 0.0;
                  
                  return Container(
                    width: 130.w,
                    margin: EdgeInsets.only(right: 12.w, bottom: 10.h),
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: balance.color.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: balance.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(balance.icon, color: balance.color, size: 18.sp),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${balance.remaining}', style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.w800, color: balance.color, height: 1.1)),
                                Text('Days', style: GoogleFonts.poppins(fontSize: 8.sp, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(balance.type, style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 6.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6.r),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: balance.color.withOpacity(0.1),
                            color: balance.color,
                            minHeight: 5.h,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ${balance.total}', style: GoogleFonts.poppins(fontSize: 9.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                            Text('${(progress * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 9.sp, color: balance.color, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final provider = Provider.of<EmployeeLeaveProvider>(context, listen: false);
    return ElevatedButton.icon(
      onPressed: () => showModalBottomSheet(
        context: context, 
        isScrollControlled: true, 
        backgroundColor: Colors.transparent, 
        sheetAnimationStyle: AnimationStyle.noAnimation,
        builder: (ctx) => ChangeNotifierProvider.value(
          value: provider, 
          child: const LeaveApplySheet()
        )
      ),
      icon: Icon(Icons.add, size: 18.sp),
      label: Text('Apply Leave', style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, 
        foregroundColor: Colors.white, 
        minimumSize: Size(double.infinity, 48.h), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 16.h, bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2))
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendence Records',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Icon(Icons.tune_rounded, color: AppColors.primary, size: 18.sp),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildFilterTypeChip('weekly', 'Weekly'),
              SizedBox(width: 8.w),
              _buildFilterTypeChip('monthly', 'Monthly'),
              SizedBox(width: 8.w),
              _buildFilterTypeChip('yearly', 'Yearly'),
            ],
          ),
          SizedBox(height: 12.h),
          _buildPeriodSelector(),
        ],
      ),
    );
  }

  Widget _buildFilterTypeChip(String type, String label) {
    final isActive = _filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterType = type;
            _attendanceVisibleCount = 3;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isActive ? AppColors.primary : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    if (_filterType == 'weekly') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<WeekRange>(
            value: _selectedWeek,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20.sp),
            items: _weeksList.map((week) {
              return DropdownMenuItem<WeekRange>(
                value: week,
                child: Text(
                  week.label,
                  style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedWeek = val;
                  _attendanceVisibleCount = 3;
                });
              }
            },
          ),
        ),
      );
    } else if (_filterType == 'monthly') {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20.sp),
                  items: _monthsList.map((month) {
                    final monthName = DateFormat('MMMM').format(DateTime(2026, month, 1));
                    return DropdownMenuItem<int>(
                      value: month,
                      child: Text(
                        monthName,
                        style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = val;
                        _attendanceVisibleCount = 3;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20.sp),
                  items: _yearsList.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(
                        '$year',
                        style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                        _attendanceVisibleCount = 3;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedYear,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20.sp),
            items: _yearsList.map((year) {
              return DropdownMenuItem<int>(
                value: year,
                child: Text(
                  '$year',
                  style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedYear = val;
                  _attendanceVisibleCount = 3;
                });
              }
            },
          ),
        ),
      );
    }
  }

  Widget _buildPeriodInsightsCard(EmployeeLeaveProvider leaveProv, EmployeeAttendanceProvider attendanceProv) {
    final range = _getCurrentFilterRange();
    final start = range['start']!;
    final end = range['end']!;

    // 1. Leave requests in period
    final filteredRequests = leaveProv.requests.where((r) => _isLeaveInPeriod(r, start, end)).toList();
    final filteredCompOffs = leaveProv.compOffCredits.where((c) => _isDutyReportInPeriod(c, start, end)).toList();

    int pendingLeaves = filteredRequests.where((r) => r.status == 'pending').length;
    double totalLeaveDays = filteredRequests.where((r) => r.status == 'approved' || r.status == 'closed').fold(0.0, (sum, r) => sum + r.days);

    // 2. Attendance records in period
    final filteredAttendance = attendanceProv.records.where((r) => _isAttendanceInPeriod(r, start, end)).toList();
    
    // Deduplicate by unique calendar date so multiple punches in a single day count as 1 day
    final Set<String> uniquePresentDates = {};
    final Set<String> uniqueLateDates = {};
    final Set<String> uniqueAttendanceDates = {};

    for (var r in filteredAttendance) {
      final rDate = _parseAnyDate(r.date);
      if (rDate == null) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(rDate);
      final s = r.status.toLowerCase().trim();

      uniqueAttendanceDates.add(dateKey);

      if (s == 'present' || s == 'late' || s == 'late in' || 
          s == 'half day' || s == 'tour' || s == 'early out') {
        uniquePresentDates.add(dateKey);
      }
      if (s == 'late' || s == 'late in') {
        uniqueLateDates.add(dateKey);
      }
    }

    int presentDays = uniquePresentDates.length;
    int lateDays = uniqueLateDates.length;

    // Calculate absent count precisely using unique calendar days
    int absentDays = 0;
    final now = DateTime.now();
    final todayNoTime = DateTime(now.year, now.month, now.day);
    
    DateTime calcEnd = end.isBefore(todayNoTime) ? end : todayNoTime;
    DateTime sDate = DateTime(start.year, start.month, start.day);
    DateTime eDate = DateTime(calcEnd.year, calcEnd.month, calcEnd.day);
    
    final weekendDay = attendanceProv.weekend.toLowerCase();
    
    for (DateTime d = sDate; d.isBefore(eDate.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      final dayOfWeek = DateFormat('EEEE').format(d).toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      
      final isWeekend = dayOfWeek == weekendDay;
      final isHoliday = attendanceProv.holidays.contains(dateStr);
      
      if (!isWeekend && !isHoliday) {
        final bool isPresentOrPunched = uniquePresentDates.contains(dateStr) || uniqueAttendanceDates.contains(dateStr);
        final bool isOnApprovedLeave = filteredRequests.any((req) {
          if (req.status != 'approved' && req.status != 'closed') return false;
          final f = _parseAnyDate(req.fromDate);
          final t = _parseAnyDate(req.toDate);
          if (f == null || t == null) return false;
          final dDay = DateTime(d.year, d.month, d.day);
          final fDay = DateTime(f.year, f.month, f.day);
          final tDay = DateTime(t.year, t.month, t.day);
          return (dDay.isAtSameMomentAs(fDay) || dDay.isAfter(fDay)) &&
                 (dDay.isAtSameMomentAs(tDay) || dDay.isBefore(tDay));
        });

        if (!isPresentOrPunched && !isOnApprovedLeave) {
          absentDays++;
        }
      }
    }

    String periodLabel = "";
    if (_filterType == 'weekly') {
      periodLabel = "Weekly Insights";
    } else if (_filterType == 'monthly') {
      periodLabel = "Insights for ${DateFormat('MMMM yyyy').format(start)}";
    } else {
      periodLabel = "Insights for $_selectedYear";
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                periodLabel,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _buildInsightRow(Icons.check_circle_rounded, 'Present', '$presentDays Days', AppColors.success),
                    SizedBox(height: 6.h),
                    _buildInsightRow(Icons.watch_later_rounded, 'Late In', '$lateDays Days', AppColors.warning),
                    SizedBox(height: 6.h),
                    _buildInsightRow(Icons.cancel_rounded, 'Absent', '$absentDays Days', AppColors.error),
                  ],
                ),
              ),
              Container(width: 1, height: 80.h, color: AppColors.border, margin: EdgeInsets.symmetric(horizontal: 12.w)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEAVES & DUTY',
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _buildInsightRow(Icons.card_travel_rounded, 'Approved', '${totalLeaveDays % 1 == 0 ? totalLeaveDays.toInt() : totalLeaveDays} Days', AppColors.success),
                    SizedBox(height: 6.h),
                    _buildInsightRow(Icons.pending_actions_rounded, 'Pending', '$pendingLeaves', AppColors.warning),
                    SizedBox(height: 6.h),
                    _buildInsightRow(Icons.info_outline_rounded, 'Comp-Offs', '${filteredCompOffs.length}', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }


  Widget _buildTabSelector() {
    return Container(
      margin: EdgeInsets.only(top: 8.h, bottom: 8.h),
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Leave History', Icons.event_note_rounded),
          _buildTabItem(1, 'Attendance Logs', Icons.fingerprint_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
            _attendanceVisibleCount = 3;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16.sp,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, EmployeeLeaveProvider leaveProv, EmployeeAttendanceProvider attendanceProv) {
    if (_activeTab == 0) {
      return _buildLeaveHistoryFiltered(context, leaveProv);
    } else {
      return _buildAttendanceLogsFiltered(context, attendanceProv);
    }
  }

  Widget _buildLeaveHistoryFiltered(BuildContext context, EmployeeLeaveProvider provider) {
    final range = _getCurrentFilterRange();
    final start = range['start']!;
    final end = range['end']!;

    final filteredRequests = provider.requests.where((r) => _isLeaveInPeriod(r, start, end)).toList();
    final filteredCompOffs = provider.compOffCredits.where((c) => _isDutyReportInPeriod(c, start, end)).toList();

    final allItems = [
      ...filteredRequests,
      ...filteredCompOffs,
    ];

    allItems.sort((a, b) {
      final idAStr = (a is EmployeeLeaveRequest) ? a.id : (a as CompOffCredit).id;
      final idBStr = (b is EmployeeLeaveRequest) ? b.id : (b as CompOffCredit).id;
      final idAVal = int.tryParse(idAStr) ?? 0;
      final idBVal = int.tryParse(idBStr) ?? 0;

      if (idAVal != 0 && idBVal != 0) {
        return idBVal.compareTo(idAVal);
      }
      return idBStr.compareTo(idAStr);
    });

    if (allItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: EmptyStateWidget(
          icon: Icons.event_busy_rounded,
          title: 'No Leave History',
          subtitle: 'No leave requests or duty reports found for the selected period.',
        ),
      );
    }

    return Column(
      children: allItems.map((item) {
        if (item is EmployeeLeaveRequest) {
          return _buildHistoryCard(context, item, provider);
        } else {
          return _buildDutyReportHistoryCard(context, item as CompOffCredit, provider);
        }
      }).toList(),
    );
  }

  Widget _buildAttendanceLogsFiltered(BuildContext context, EmployeeAttendanceProvider provider) {
    final range = _getCurrentFilterRange();
    final start = range['start']!;
    final end = range['end']!;

    final filteredAttendance = provider.records.where((r) => _isAttendanceInPeriod(r, start, end)).toList();

    if (filteredAttendance.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: EmptyStateWidget(
          icon: Icons.fingerprint_rounded,
          title: 'No Attendance Logs',
          subtitle: 'No attendance records found for the selected period.',
        ),
      );
    }

    // Pagination: display up to _attendanceVisibleCount
    final displayedAttendance = filteredAttendance.take(_attendanceVisibleCount).toList();
    final bool hasMore = filteredAttendance.length > _attendanceVisibleCount;

    return Column(
      children: [
        ...displayedAttendance.map((record) {
          Color statusColor = AppColors.error;
          final s = record.status.toLowerCase();
          if (s == 'present') {
            statusColor = AppColors.success;
          } else if (s == 'late' || s == 'late in') {
            statusColor = AppColors.warning;
          } else if (s == 'leave') {
            statusColor = Colors.purple;
          } else if (s == 'tour') {
            statusColor = Colors.indigo;
          } else if (s == 'half day') {
            statusColor = Colors.blue;
          }

          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4.w,
                  height: 40.h,
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2.r)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.date,
                        style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      if (record.checkIn != null)
                        Text(
                          'In: ${record.checkIn}  |  Out: ${record.checkOut ?? "Pending"}',
                          style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textTertiary),
                        )
                      else
                        Text(
                          'No punches logged',
                          style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textHint, fontStyle: FontStyle.italic),
                        ),
                      if (record.lateDuration != null && record.lateDuration!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            '⏰ Late by: ${record.lateDuration}',
                            style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.warning),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                      child: Text(
                        record.status,
                        style: GoogleFonts.poppins(fontSize: 10.sp, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                    ),
                    if (record.workHours != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        record.workHours!,
                        style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),

        if (hasMore) ...[
          SizedBox(height: 4.h),
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _attendanceVisibleCount += 3;
                });
              },
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View More',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ],
    );
  }


  Widget _buildDutyReportHistoryCard(BuildContext context, CompOffCredit report, EmployeeLeaveProvider provider) {
    final statusColor = report.status == 'approved' ? AppColors.success : report.status == 'pending' ? AppColors.warning : AppColors.error;
    final statusBg = report.status == 'approved' ? AppColors.successLight : report.status == 'pending' ? AppColors.warningLight : AppColors.errorLight;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.02), 
        borderRadius: BorderRadius.circular(12.r), 
        border: Border.all(color: Colors.orange.withOpacity(0.2))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('HOLIDAY DUTY REPORT', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.orange[800]))),
              Container(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12.r)), child: Text(report.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9.sp, fontWeight: FontWeight.w600, color: statusColor))),
            ],
          ),
          SizedBox(height: 8.h),
          Text('Duty Date: ${report.dutyDate}', style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          Text('Duration: ${report.duration ?? "N/A"}', style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textSecondary)),
          if (report.reason.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4.h), child: Text(report.reason, style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 14.sp, color: AppColors.error),
                    SizedBox(width: 4.w),
                    Expanded(child: Text(report.attachment, style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse('https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      AppHelpers.showError(context, 'Could not open PDF viewer');
                    }
                  }
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('View File', style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, EmployeeLeaveRequest request, EmployeeLeaveProvider provider) {
    final statusColor = request.status == 'approved' ? AppColors.success : request.status == 'pending' ? AppColors.warning : request.status == 'closed' ? Colors.blueGrey : AppColors.error;
    final statusBg = request.status == 'approved' ? AppColors.successLight : request.status == 'pending' ? AppColors.warningLight : request.status == 'closed' ? Colors.blueGrey.withOpacity(0.1) : AppColors.errorLight;

    bool needsJoiningReport = false;
    if (request.status == 'approved' && (request.leaveType == 'Commuted Leave' || request.leaveType == 'Half Pay Leave')) {
      try {
        final toDate = DateFormat('dd MMM yyyy').parse(request.toDate);
        if (DateTime.now().isAfter(toDate)) needsJoiningReport = true;
      } catch (_) {}
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(request.leaveType, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Container(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12.r)), child: Text(request.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9.sp, fontWeight: FontWeight.w600, color: statusColor))),
            ],
          ),
          SizedBox(height: 6.h),
          Text('${_formatDisplayDate(request.fromDate)} - ${_formatDisplayDate(request.toDate)} (${request.days % 1 == 0 ? request.days.toInt() : request.days} day${request.days > 1 ? 's' : ''})', style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textSecondary)),
          if (request.reason.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4.h), child: Text(request.reason, style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Applied on: ${request.appliedOn}', style: GoogleFonts.poppins(fontSize: 9.sp, color: AppColors.textHint)),
              if (needsJoiningReport)
                ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent, 
                    sheetAnimationStyle: AnimationStyle.noAnimation,
                    builder: (ctx) => ChangeNotifierProvider.value(value: provider, child: JoiningReportSheet(request: request)),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 12.w), minimumSize: Size(0, 26.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
                  child: Text('Submit Joining', style: GoogleFonts.poppins(fontSize: 9.sp, fontWeight: FontWeight.w600)),
                ),
              if (request.status == 'closed') Row(children: [Icon(Icons.check_circle_outline_rounded, color: Colors.blueGrey, size: 14.sp), SizedBox(width: 4.w), Text('Joined on: ${request.joiningDate}', style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.blueGrey, fontWeight: FontWeight.w500))]),
            ],
          ),
          SizedBox(height: 12.h),
          Center(
            child: SizedBox(
              width: 140.w,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  sheetAnimationStyle: AnimationStyle.noAnimation,
                  builder: (ctx) => _EmployeeLeaveDetailsSheet(request: request),
                ),
                icon: Icon(Icons.remove_red_eye_outlined, size: 14.sp, color: AppColors.primary),
                label: Text('View Details', style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BOTTOM SHEETS ───────────────────────────────────────────

class LeaveApplySheet extends StatefulWidget {
  const LeaveApplySheet({super.key});
  @override
  State<LeaveApplySheet> createState() => _LeaveApplySheetState();
}

class _LeaveApplySheetState extends State<LeaveApplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _selectedLeaveType;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _isHalfDay = false;
  bool _isToDateSelected = false;
  String _halfDaySession = 'Forenoon';
  bool _isMiscarriage = false;
  DateTime? _deliveryDate;
  String? _uploadedFileName;

  double _calculateCurrentDays(EmployeeLeaveProvider provider) {
    if (_selectedLeaveType == 'Casual Leave') return provider.calculateCLDuration(_fromDate, _toDate, isHalfDay: _isHalfDay);
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day);
    return _isHalfDay ? 0.5 : (to.difference(from).inDays + 1).toDouble();
  }

  String? _validateCasualLeaveRules(DateTime from, DateTime to, List<EmployeeLeaveRequest> requests, EmployeeLeaveProvider provider) {
    if (_selectedLeaveType != 'Casual Leave') return null;
    final days = provider.calculateCLDuration(from, to, isHalfDay: _isHalfDay);
    if (days > 5) return 'Casual Leave can only be applied for a maximum of 5 days as per Govt rules.';
    final dateFormat = DateFormat('dd MMM yyyy');
    for (var req in requests) {
      if ((req.status == 'approved' || req.status == 'pending') && (req.leaveType == 'Earned Leave' || req.leaveType == 'Commuted Leave' || req.leaveType == 'Half Pay Leave')) {
        try {
          final reqFrom = dateFormat.parse(req.fromDate);
          final reqTo = dateFormat.parse(req.toDate);
          if (dateFormat.format(from.subtract(const Duration(days: 1))) == dateFormat.format(reqTo) || dateFormat.format(to.add(const Duration(days: 1))) == dateFormat.format(reqFrom)) {
            return 'Casual Leave (CL) cannot be taken just before or after regular leave.';
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String? _validateHalfPayLeaveRules(DateTime from, DateTime to, AuthUser? user, List<LeaveBalance> balances, List<EmployeeLeaveRequest> requests) {
    if (_selectedLeaveType != 'Half Pay Leave') return null;
    
    // Check for adjacent Casual Leave
    final dateFormat = DateFormat('dd MMM yyyy');
    for (var req in requests) {
      if ((req.status == 'approved' || req.status == 'pending') && req.leaveType == 'Casual Leave') {
        try {
          final reqFrom = dateFormat.parse(req.fromDate);
          final reqTo = dateFormat.parse(req.toDate);
          if (dateFormat.format(from.subtract(const Duration(days: 1))) == dateFormat.format(reqTo) || 
              dateFormat.format(to.add(const Duration(days: 1))) == dateFormat.format(reqFrom)) {
            return 'Regular Leave (HPL) cannot be taken just before or after Casual Leave (CL).';
          }
        } catch (_) {}
      }
    }

    final days = (to.difference(from).inDays + 1).toDouble();
    final hplBalance = balances.firstWhere((b) => b.type == 'Half Pay Leave');
    if (hplBalance.remaining < days) return 'Insufficient Half Pay Leave (HPL) balance.';
    return null;
  }

  String? _validateCommutedLeaveRules(DateTime from, DateTime to, AuthUser? user, List<LeaveBalance> balances, List<EmployeeLeaveRequest> requests) {
    if (_selectedLeaveType != 'Commuted Leave') return null;

    // Check for adjacent Casual Leave
    final dateFormat = DateFormat('dd MMM yyyy');
    for (var req in requests) {
      if ((req.status == 'approved' || req.status == 'pending') && req.leaveType == 'Casual Leave') {
        try {
          final reqFrom = dateFormat.parse(req.fromDate);
          final reqTo = dateFormat.parse(req.toDate);
          if (dateFormat.format(from.subtract(const Duration(days: 1))) == dateFormat.format(reqTo) || 
              dateFormat.format(to.add(const Duration(days: 1))) == dateFormat.format(reqFrom)) {
            return 'Commuted Leave cannot be taken just before or after Casual Leave (CL).';
          }
        } catch (_) {}
      }
    }

    final days = (to.difference(from).inDays + 1).toDouble();
    final hplBalance = balances.firstWhere((b) => b.type == 'Half Pay Leave');
    if (hplBalance.remaining < (days * 2)) return 'Insufficient HPL balance (Needs 2 HPL for 1 Commuted Day).';
    return null;
  }

  String? _validateMaternityLeaveRules(AuthUser? user) {
    if (_selectedLeaveType != 'Maternity Leave') return null;
    if (user == null || user.gender != 'Female') return 'Applicable for Female employees only.';
    if ((user.survivingChildren ?? 0) >= 2 && !_isMiscarriage) return 'Maternity Leave is only for the first two surviving children.';
    return null;
  }

  String? _validatePaternityLeaveRules(DateTime start, AuthUser? user) {
    if (_selectedLeaveType != 'Paternity Leave') return null;
    if (user == null || user.gender != 'Male') return 'Applicable for Male employees only.';
    if ((user.survivingChildren ?? 0) >= 2) return 'Paternity Leave is only for the first two surviving children.';
    if (_deliveryDate == null) return 'Please select the Delivery Date.';
    final minDate = _deliveryDate!.subtract(const Duration(days: 15));
    final maxDate = _deliveryDate!.add(const Duration(days: 180));
    if (start.isBefore(minDate) || start.isAfter(maxDate)) return 'Paternity Leave must be taken within 15 days before or 6 months after delivery.';
    return null;
  }

  String? _validateCompensatoryLeaveRules(DateTime from, DateTime to, List<CompOffCredit> credits) {
    if (_selectedLeaveType != 'Compensatory Leave') return null;
    final days = (to.difference(from).inDays + 1).toDouble();
    if (days > 2) return 'Max 2 days of Compensatory Leave allowed at a time.';
    final dateFormat = DateFormat('dd MMM yyyy');
    bool hasValidCredit = credits.any((c) => c.status == 'approved' && !from.isAfter(dateFormat.parse(c.expiryDate)));
    if (!hasValidCredit) return 'No valid Compensatory credit found (Expiry 30 days).';
    return null;
  }

  String? _validateEarnedLeaveRules(DateTime from, DateTime to, AuthUser? user, List<EmployeeLeaveRequest> requests) {
    if (_selectedLeaveType != 'Earned Leave') return null;
    
    // Check for adjacent Casual Leave
    final dateFormat = DateFormat('dd MMM yyyy');
    for (var req in requests) {
      if ((req.status == 'approved' || req.status == 'pending') && req.leaveType == 'Casual Leave') {
        try {
          final reqFrom = dateFormat.parse(req.fromDate);
          final reqTo = dateFormat.parse(req.toDate);
          if (dateFormat.format(from.subtract(const Duration(days: 1))) == dateFormat.format(reqTo) || 
              dateFormat.format(to.add(const Duration(days: 1))) == dateFormat.format(reqFrom)) {
            return 'Earned Leave (EL) cannot be taken just before or after Casual Leave (CL).';
          }
        } catch (_) {}
      }
    }

    if (from.isBefore(DateTime.now().add(const Duration(days: 15)))) return 'Apply for EL at least 15 days in advance.';
    return null;
  }

  String? _validateActiveLeave(DateTime newFrom, DateTime newTo, List<EmployeeLeaveRequest> requests) {
    final dateFormat = DateFormat('dd MMM yyyy');
    
    // Normalize new dates (remove time)
    final nFrom = DateTime(newFrom.year, newFrom.month, newFrom.day);
    final nTo = DateTime(newTo.year, newTo.month, newTo.day);

    for (var req in requests) {
      if (req.status == 'pending' || req.status == 'approved') {
        try {
          final existingFrom = dateFormat.parse(req.fromDate);
          final existingTo = dateFormat.parse(req.toDate);
          
          final eFrom = DateTime(existingFrom.year, existingFrom.month, existingFrom.day);
          final eTo = DateTime(existingTo.year, existingTo.month, existingTo.day);

          // Overlap check: (StartA <= EndB) and (EndA >= StartB)
          if (!(nTo.isBefore(eFrom) || nFrom.isAfter(eTo))) {
            return 'Overlap Error: You already have a leave applied from ${req.fromDate} to ${req.toDate}. Please choose different dates.';
          }
        } catch (_) {}
      }
    }
    return null;
  }

  void _showPolicyAlert(BuildContext context, String message) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), 
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28.sp), SizedBox(width: 10.w), Text('Policy Alert', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.error))]), 
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14.sp)), 
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)))]
      )
    );
  }

  @override
  void dispose() { _reasonController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final globalLeaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    final provider = Provider.of<EmployeeLeaveProvider>(context);
    final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    List<String> leaveTypes = globalLeaveProvider.policies.map((p) => p.title).toList();
    if (authUser?.gender != 'Female') leaveTypes.removeWhere((t) => t.contains('Maternity'));
    if (authUser?.gender != 'Male') leaveTypes.removeWhere((t) => t.contains('Paternity'));
    if (_selectedLeaveType == null && leaveTypes.isNotEmpty) _selectedLeaveType = leaveTypes.first;

    return Container(
      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.75, maxHeight: MediaQuery.of(context).size.height * 0.95),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 30.h),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 20.h),
            Text('Apply for Leave', style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 20.h),
            if (provider.isLoading) const Center(child: CircularProgressIndicator())
            else Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildLeaveTypeDropdown(leaveTypes, globalLeaveProvider),
                  _buildRulesBox(),
                  if (_selectedLeaveType == 'Casual Leave') _buildHalfDayToggle(),
                  if (_selectedLeaveType == 'Maternity Leave') _buildMiscarriageToggle(),
                  if (_selectedLeaveType == 'Paternity Leave') _buildDeliveryDatePicker(),
                  if (_selectedLeaveType == 'Compensatory Leave') _buildLogDutyButton(provider),
                  Builder(
                    builder: (context) {
                      final hasPending = provider.compOffCredits.any((c) => c.status == 'pending');
                      final hasApproved = provider.compOffCredits.any((c) => c.status == 'approved');
                      bool isStep2Enabled = true;
                      
                      if (_selectedLeaveType == 'Compensatory Leave') {
                        isStep2Enabled = hasApproved && !hasPending;
                      }

                      return IgnorePointer(
                        ignoring: !isStep2Enabled,
                        child: Opacity(
                          opacity: isStep2Enabled ? 1.0 : 0.5,
                          child: Column(
                            children: [
                              if (_selectedLeaveType != 'Paternity Leave') _buildDatePickers(),
                              _buildUploadSection(),
                              _buildDurationDisplay(provider),
                              _buildReasonField(),
                              SizedBox(height: 24.h),
                              _buildSubmitButton(provider, globalLeaveProvider, isEnabled: isStep2Enabled),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown(List<String> leaveTypes, LeaveProvider global) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Leave Type', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      SizedBox(height: 6.h),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedLeaveType, isExpanded: true, items: leaveTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.poppins(fontSize: 14.sp, color: AppColors.textPrimary)))).toList(),
              onChanged: (value) => setState(() {
                _selectedLeaveType = value;
                _isMiscarriage = false;
                _isToDateSelected = (_selectedLeaveType == 'Maternity Leave' || _selectedLeaveType == 'Paternity Leave');
                if (_selectedLeaveType == 'Maternity Leave') _toDate = _fromDate.add(const Duration(days: 179));
                if (_selectedLeaveType == 'Paternity Leave') _toDate = _fromDate.add(const Duration(days: 14));
                if (_selectedLeaveType == 'Compensatory Leave' || _selectedLeaveType == 'Commuted Leave' || _selectedLeaveType == 'Half Pay Leave' || _selectedLeaveType == 'Earned Leave' || _selectedLeaveType == 'Maternity Leave' || _selectedLeaveType == 'Paternity Leave') {
                  _isHalfDay = false;
                }
              }),
          ),
        ),
      ),
    ]);
  }

  Widget _buildRulesBox() {
    String rules = '';
    Color color = AppColors.primary;
    if (_selectedLeaveType == 'Casual Leave') {
      rules = '• FREE DAYS: Sundays and 2nd/4th Saturdays are EXCLUDED (Cannot apply solely for weekend/holiday).\n• DURATION: Minimum 0.5 Day (Half Day), Maximum 5 Days per application.\n• NO SANDWICH: Weekend days falling within leave are not deducted from your balance.\n• RESTRICTION: Cannot be taken immediately before or after regular/medical leaves.';
    } else if (_selectedLeaveType == 'Earned Leave') {
      rules = '• SANDWICH RULE: Sundays and official holidays during your leave period ARE counted.\n• LIMIT: Maximum accumulation allowed is 300 days.\n• ADVANCE APPLICATION: Apply at least 15 days in advance.\n• ATTACHMENT: Supporting document/order mandatory as per Govt rule.';
      color = AppColors.success;
    } else if (_selectedLeaveType == 'Commuted Leave') {
      rules = '• NO BACKDATE: Backdated leave applications are not permitted.\n• CONVERSION: Full Salary during medical leave (Deducts 2 HPL days per 1 Commuted day).\n• CERTIFICATE: Medical Certificate is mandatory from Day 1.\n• JOINING: Fitness Certificate must be submitted upon joining.';
      color = AppColors.error;
    } else if (_selectedLeaveType == 'Half Pay Leave') {
      rules = '• NO BACKDATE: Backdated applications are not permitted.\n• SALARY: Half Pay (50% salary) for these days (1 Day leave = 1 HPL deduct).\n• RESTRICTION: Cannot be taken immediately before or after Casual Leave (CL).';
      color = AppColors.warning;
    } else if (_selectedLeaveType == 'Compensatory Leave') {
      rules = '• EARNING: Earned by performing duty on authorized Holidays/Sundays.\n• EXPIRY: Must be utilized within 30 days of duty.\n• LIMIT: Maximum 2 days allowed at a time. Full days only (No half day).';
      color = AppColors.warning;
    } else if (_selectedLeaveType == 'Maternity Leave') {
      rules = '• ELIGIBILITY: Female employees only (< 2 surviving children).\n• DURATION: Exactly 180 continuous calendar days (Sandwich rule applies).\n• MANDATORY: Medical/Birth Certificate required. Backdated entry not permitted.';
      color = AppColors.secondary;
    } else if (_selectedLeaveType == 'Paternity Leave') {
      rules = '• ELIGIBILITY: Male employees with < 2 surviving children.\n• DURATION: 15 continuous calendar days (Full Pay).\n• MANDATORY: Valid Birth Certificate is required.';
      color = AppColors.accent;
    }
    if (rules.isEmpty) return const SizedBox.shrink();
    return Container(margin: EdgeInsets.only(top: 12.h), padding: EdgeInsets.all(12.r), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: color.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.info_outline_rounded, color: color, size: 16.sp), SizedBox(width: 8.w), Text('$_selectedLeaveType Rules', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color))]), SizedBox(height: 4.h), Text(rules, style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textPrimary.withOpacity(0.8), height: 1.5))]));
  }

  Widget _buildHalfDayToggle() => Padding(padding: EdgeInsets.only(top: 12.h), child: Row(children: [SizedBox(height: 24.w, width: 24.w, child: Checkbox(value: _isHalfDay, activeColor: AppColors.primary, onChanged: (v) => setState(() { _isHalfDay = v ?? false; if (_isHalfDay) _toDate = _fromDate; }))), SizedBox(width: 8.w), Text('Half Day', style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w500)), if (_isHalfDay) ...[SizedBox(width: 20.w), Expanded(child: Container(padding: EdgeInsets.symmetric(horizontal: 10.w), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _halfDaySession, isDense: true, items: ['Forenoon', 'Afternoon'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 12.sp)))).toList(), onChanged: (v) => setState(() => _halfDaySession = v!)))))]]));
  Widget _buildMiscarriageToggle() => Padding(padding: EdgeInsets.only(top: 12.h), child: Row(children: [Checkbox(value: _isMiscarriage, activeColor: AppColors.secondary, onChanged: (v) => setState(() { _isMiscarriage = v ?? false; _toDate = _fromDate.add(Duration(days: _isMiscarriage ? 44 : 179)); })), SizedBox(width: 8.w), Text('Case of Miscarriage/Abortion (Max 45 Days)', style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w500))]));

  Widget _buildDeliveryDatePicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(height: 16.h), Text('Date of Delivery', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), SizedBox(height: 6.h), GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _deliveryDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 200)), lastDate: DateTime.now().add(const Duration(days: 30))); if (p != null) setState(() { _deliveryDate = p; _fromDate = p; _toDate = p.add(const Duration(days: 14)); _isToDateSelected = true; }); }, child: Container(padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.event_available_rounded, size: 18.sp, color: AppColors.accent), SizedBox(width: 12.w), Text(_deliveryDate == null ? 'Select Delivery Date' : DateFormat('dd MMM yyyy').format(_deliveryDate!), style: GoogleFonts.poppins(fontSize: 13.sp))])) )]);

  Widget _buildDatePickers() => Column(children: [
    SizedBox(height: 16.h),
    GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _fromDate, firstDate: (_selectedLeaveType == 'Commuted Leave' || _selectedLeaveType == 'Half Pay Leave') ? DateTime.now().subtract(const Duration(days: 90)) : DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (p != null) setState(() { _fromDate = p; if (_toDate.isBefore(p)) { _toDate = p; _isToDateSelected = false; } }); }, child: Container(padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.calendar_today, size: 18.sp, color: AppColors.primary), SizedBox(width: 12.w), Text('From: ${DateFormat('dd MMM yyyy').format(_fromDate)}', style: GoogleFonts.poppins(fontSize: 13.sp))]))),
    if (!_isHalfDay) ...[SizedBox(height: 12.h), GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _toDate, firstDate: _fromDate, lastDate: DateTime.now().add(const Duration(days: 365))); if (p != null) setState(() { _toDate = p; _isToDateSelected = true; }); }, child: Container(padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.calendar_today, size: 18.sp, color: AppColors.primary), SizedBox(width: 12.w), Text('To: ${DateFormat('dd MMM yyyy').format(_toDate)}', style: GoogleFonts.poppins(fontSize: 13.sp))])))]
  ]);

  Widget _buildUploadSection() {
    bool needed = (_selectedLeaveType == 'Commuted Leave' || _selectedLeaveType == 'Maternity Leave' || _selectedLeaveType == 'Paternity Leave');
    if (!needed) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 16.h),
      Text('Attachment (Mandatory)', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      SizedBox(height: 6.h),
      GestureDetector(onTap: () async { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']); if (r != null) setState(() => _uploadedFileName = r.files.first.name); }, child: Container(width: double.infinity, padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _uploadedFileName == null ? AppColors.error.withOpacity(0.5) : AppColors.success.withOpacity(0.5))), child: Row(children: [Icon(_uploadedFileName == null ? Icons.picture_as_pdf_outlined : Icons.check_circle_rounded, color: _uploadedFileName == null ? AppColors.error : AppColors.success, size: 20.sp), SizedBox(width: 12.w), Expanded(child: Text(_uploadedFileName ?? 'Upload PDF (Max 5MB)', style: GoogleFonts.poppins(fontSize: 13.sp, color: _uploadedFileName == null ? AppColors.textTertiary : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))]))),
    ]);
  }

  Widget _buildDurationDisplay(EmployeeLeaveProvider provider) {
    if (!_isHalfDay && !_isToDateSelected) return const SizedBox.shrink();
    final days = _calculateCurrentDays(provider);
    return Padding(padding: EdgeInsets.symmetric(vertical: 16.h), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('Total Duration: ', style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600)), Text('$days day${days != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.primary)), Text(' (Approx. ${(days * 8).toInt()} Hours)', style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.secondary))]), if (_selectedLeaveType == 'Casual Leave' && !_isHalfDay) Text('* Sundays & 2nd/4th Saturdays excluded.', style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.success, fontStyle: FontStyle.italic))]));
  }

  Widget _buildReasonField() => TextFormField(controller: _reasonController, maxLines: 2, decoration: InputDecoration(hintText: 'Reason for leave', filled: true, fillColor: AppColors.surfaceVariant, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary))), validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a valid reason' : null);

  Widget _buildLogDutyButton(EmployeeLeaveProvider provider) {
    final approvedCredits = provider.compOffCredits.where((c) => c.status == 'approved').toList();
    final pendingCredits = provider.compOffCredits.where((c) => c.status == 'pending').toList();
    final isLimitReached = provider.isCompOffLimitReached;
    final reportsDone = provider.compOffReportsThisMonth;
    final reportsRemaining = 2 - reportsDone;
    
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingCredits.isNotEmpty) ...[
            Text(
              'Pending for Review',
              style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.orange[800]),
            ),
            SizedBox(height: 8.h),
            ...pendingCredits.map((c) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.hourglass_top_rounded, color: Colors.orange[800], size: 14.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duty: ${c.dutyDate}', style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                        Text('Waiting for admin review...', style: GoogleFonts.poppins(fontSize: 9.sp, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8.r)),
                    child: Text('PENDING', style: GoogleFonts.poppins(fontSize: 8.sp, fontWeight: FontWeight.w700, color: Colors.orange[900])),
                  ),
                ],
              ),
            )).toList(),
            Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: Colors.orange[800], size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'your holiday report succsfulyy submited please waiting for admin rreview',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (approvedCredits.isNotEmpty) ...[
            Text(
              'Available Approved Credits',
              style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
            SizedBox(height: 8.h),
            ...approvedCredits.map((c) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.verified_rounded, color: AppColors.success, size: 14.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duty: ${c.dutyDate}${c.duration != null ? ' (${c.duration})' : ''}', style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                        Text(c.reason, style: GoogleFonts.poppins(fontSize: 9.sp, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Valid Until', style: GoogleFonts.poppins(fontSize: 8.sp, color: AppColors.textHint)),
                      Text(c.expiryDate, style: GoogleFonts.poppins(fontSize: 9.sp, fontWeight: FontWeight.w600, color: AppColors.error)),
                    ],
                  ),
                ],
              ),
            )).toList(),
            SizedBox(height: 8.h),
          ],
          Text(
            'Step 1: Credit your duty (if not listed above)',
            style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8.h),
          OutlinedButton.icon(
            onPressed: (isLimitReached || pendingCredits.isNotEmpty) ? null : () => showModalBottomSheet(
              context: context, 
              isScrollControlled: true, 
              backgroundColor: Colors.transparent, 
              sheetAnimationStyle: AnimationStyle.noAnimation,
              builder: (ctx) => ChangeNotifierProvider.value(
                value: provider, 
                child: const LogHolidayDutySheet()
              )
            ),
            icon: Icon(Icons.history_edu_rounded, size: 16.sp, color: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.grey : AppColors.primary),
            label: Text('Submit Holiday Duty Report', style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.grey : AppColors.primary,
              side: BorderSide(color: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.grey : AppColors.primary, width: 1.5),
              minimumSize: Size(double.infinity, 44.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              backgroundColor: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.grey.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10.h, left: 4.w),
            child: Row(
              children: [
                Icon(
                  (isLimitReached || pendingCredits.isNotEmpty) ? Icons.info_outline : Icons.tips_and_updates_outlined, 
                  size: 14.sp, 
                  color: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.red : AppColors.textTertiary
                ),
                SizedBox(width: 6.w),
                Text(
                  isLimitReached 
                    ? 'You completed 2 times holiday report for this month'
                    : pendingCredits.isNotEmpty 
                      ? 'Waiting for admin approval' 
                      : 'Note: Max 2 reports/month ($reportsRemaining remaining)',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp, 
                    color: (isLimitReached || pendingCredits.isNotEmpty) ? Colors.red : AppColors.textTertiary, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Step 2: Select the leave dates below',
            style: GoogleFonts.poppins(
              fontSize: 12.sp, 
              fontWeight: FontWeight.w600, 
              color: (_selectedLeaveType == 'Compensatory Leave' && (pendingCredits.isNotEmpty || approvedCredits.isEmpty))
                ? Colors.grey
                : AppColors.textSecondary
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(EmployeeLeaveProvider provider, LeaveProvider globalLeaveProvider, {bool isEnabled = true}) => SizedBox(
    width: double.infinity, 
    child: ElevatedButton(
      onPressed: (provider.isSubmitting || !isEnabled) ? null : () async {
        if (_formKey.currentState!.validate()) { 
          final days = _calculateCurrentDays(provider);
          final effectiveToDate = _isHalfDay ? _fromDate : _toDate;

          // 0. Zero Working Days / Holiday Check
          if (days <= 0) {
            _showPolicyAlert(
              context,
              _selectedLeaveType == 'Casual Leave'
                  ? 'The selected date falls on an official holiday or weekend (e.g., Sunday / 2nd or 4th Saturday).\n\nCasual Leave cannot be applied for 0 working days. Please select working days.'
                  : 'Selected date range results in 0 working days ($days days). Please choose valid dates.',
            );
            return;
          }

          // 1. Prohibit Backdating for strictly forward leaves
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final fromClean = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
          if ((_selectedLeaveType == 'Half Pay Leave' ||
                  _selectedLeaveType == 'Commuted Leave' ||
                  _selectedLeaveType == 'Maternity Leave') &&
              fromClean.isBefore(today)) {
            _showPolicyAlert(
              context,
              'Backdated leave applications are strictly not allowed for $_selectedLeaveType as per government rules.',
            );
            return;
          }

          // 2. Overlap Check
          final activeError = _validateActiveLeave(_fromDate, effectiveToDate, provider.requests);
          if (activeError != null) { _showPolicyAlert(context, activeError); return; }

          // 3. Casual Leave
          final clError = _validateCasualLeaveRules(_fromDate, effectiveToDate, provider.requests, provider);
          if (clError != null) { _showPolicyAlert(context, clError); return; }

          // 4. Commuted Leave
          final commError = _validateCommutedLeaveRules(_fromDate, effectiveToDate, provider.user, provider.balances, provider.requests);
          if (commError != null) { _showPolicyAlert(context, commError); return; }

          // 5. Half Pay Leave
          final hplError = _validateHalfPayLeaveRules(_fromDate, effectiveToDate, provider.user, provider.balances, provider.requests);
          if (hplError != null) { _showPolicyAlert(context, hplError); return; }

          // 6. Earned Leave
          final elError = _validateEarnedLeaveRules(_fromDate, effectiveToDate, provider.user, provider.requests);
          if (elError != null) { _showPolicyAlert(context, elError); return; }

          // 7. Maternity Leave
          final mlError = _validateMaternityLeaveRules(provider.user);
          if (mlError != null) { _showPolicyAlert(context, mlError); return; }

          // 8. Paternity Leave
          final plError = _validatePaternityLeaveRules(_fromDate, provider.user);
          if (plError != null) { _showPolicyAlert(context, plError); return; }

          // 9. Compensatory Leave
          final compError = _validateCompensatoryLeaveRules(_fromDate, effectiveToDate, provider.compOffCredits);
          if (compError != null) { _showPolicyAlert(context, compError); return; }

          // Attachment Check
          if ((_selectedLeaveType == 'Commuted Leave' || _selectedLeaveType == 'Maternity Leave' || _selectedLeaveType == 'Paternity Leave') && _uploadedFileName == null) { 
            _showPolicyAlert(context, 'Attachment is mandatory.'); 
            return; 
          } 

          final selectedPolicyId = globalLeaveProvider.policies.firstWhere(
            (p) => p.title == _selectedLeaveType || p.id == _selectedLeaveType,
            orElse: () => const LeavePolicy(id: 'CL', title: '', description: '', totalDays: 0, usedDays: 0, iconName: '', colorValue: 0),
          ).id;

          final success = await provider.applyLeave(
            leaveType: selectedPolicyId, 
            fromDate: _fromDate, 
            toDate: effectiveToDate, 
            reason: _reasonController.text.trim() +
                    (_isHalfDay ? ' (Half Day - $_halfDaySession)' : ''), 
            customDays: days,
            globalProvider: globalLeaveProvider,
          );

          if (success) { 
            if (mounted) {
              Navigator.pop(context); 
              AppHelpers.showSuccess(context, 'Leave application submitted successfully!');
            }
          } else {
            if (mounted) {
              String? rawError = provider.lastErrorMessage ?? globalLeaveProvider.lastErrorMessage;
              if (rawError != null) {
                if (rawError.contains('<html') ||
                    rawError.contains('<!DOCTYPE') ||
                    rawError.contains('<head') ||
                    rawError.contains('<body') ||
                    rawError.contains('redirecting')) {
                  rawError = 'A server or database issue occurred while submitting your leave application.';
                } else if (rawError.contains('<') && rawError.contains('>')) {
                  rawError = rawError.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
                }
              }

              final displayError = (rawError != null && rawError.trim().isNotEmpty)
                  ? (rawError.toLowerCase().contains('administrator')
                      ? rawError
                      : '$rawError\n\nPlease contact the Administrator if this issue persists.')
                  : 'Unable to submit leave application. Please check your leave balance or contact the Administrator.';

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showPolicyAlert(context, displayError);
                }
              });
            }
          } 
        } 
      }, 
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))), 
      child: provider.isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Submit Details', style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white))
    )
  );
}

class JoiningReportSheet extends StatefulWidget {
  final EmployeeLeaveRequest request;
  const JoiningReportSheet({super.key, required this.request});
  @override
  State<JoiningReportSheet> createState() => _JoiningReportSheetState();
}

class _JoiningReportSheetState extends State<JoiningReportSheet> {
  DateTime _joiningDate = DateTime.now();
  String? _fitnessFileName;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EmployeeLeaveProvider>(context, listen: false);
    return Container(
      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.5, maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 30.h),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 20.h),
            Text('Joining Report & Fitness', style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
            Text('Leave: ${widget.request.leaveType}', style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textSecondary)),
            SizedBox(height: 24.h),
            _buildDatePicker(),
            SizedBox(height: 20.h),
            _buildFilePicker(),
            SizedBox(height: 32.h),
            _buildSubmitButton(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Actual Joining Date', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), SizedBox(height: 8.h), GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _joiningDate, firstDate: DateFormat('dd MMM yyyy').parse(widget.request.toDate), lastDate: DateTime.now().add(const Duration(days: 7))); if (p != null) setState(() => _joiningDate = p); }, child: Container(padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.calendar_today_rounded, size: 18.sp, color: AppColors.primary), SizedBox(width: 12.w), Text(DateFormat('dd MMMM yyyy').format(_joiningDate), style: GoogleFonts.poppins(fontSize: 14.sp))])) )]);
  Widget _buildFilePicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Fitness Certificate', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), SizedBox(height: 8.h), GestureDetector(onTap: () async { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']); if (r != null) setState(() => _fitnessFileName = r.files.first.name); }, child: Container(width: double.infinity, padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _fitnessFileName == null ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3))), child: Row(children: [Icon(_fitnessFileName == null ? Icons.upload_file_rounded : Icons.check_circle_rounded, color: _fitnessFileName == null ? AppColors.error : AppColors.success, size: 20.sp), SizedBox(width: 12.w), Expanded(child: Text(_fitnessFileName ?? 'Upload Certificate', style: GoogleFonts.poppins(fontSize: 13.sp, color: _fitnessFileName == null ? AppColors.textTertiary : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))])) )]);
  Widget _buildSubmitButton(EmployeeLeaveProvider p) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isSubmitting ? null : () async { if (_fitnessFileName == null) { AppHelpers.showError(context, 'Upload certificate first'); return; } setState(() => _isSubmitting = true); if (await p.submitJoiningReport(requestId: widget.request.id, fitnessCertificate: _fitnessFileName!, joiningDate: _joiningDate)) { Navigator.pop(context); AppHelpers.showSuccess(context, 'Leave Closed!'); } }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text('Submit Joining Report', style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white))));
}

class LogHolidayDutySheet extends StatefulWidget {
  const LogHolidayDutySheet({super.key});
  @override
  State<LogHolidayDutySheet> createState() => _LogHolidayDutySheetState();
}

class _LogHolidayDutySheetState extends State<LogHolidayDutySheet> {
  DateTime _dutyDate = DateTime.now();
  final _reasonController = TextEditingController();
  String? _attachmentName;
  bool _isSubmitting = false;
  int _selectedHours = 8;
  int _selectedMinutes = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EmployeeLeaveProvider>(context, listen: false);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 30.h),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r))),
            SizedBox(height: 20.h),
            Text('Log Holiday Duty', style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 24.h),
            _buildDatePicker(),
            SizedBox(height: 16.h),
            _buildDurationPicker(),
            SizedBox(height: 16.h),
            _buildReasonField(),
            SizedBox(height: 16.h),
            _buildFilePicker(),
            SizedBox(height: 24.h),
            _buildSubmitButton(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() => GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _dutyDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now()); if (p != null) setState(() => _dutyDate = p); }, child: Container(padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.calendar_month_rounded, size: 18.sp, color: AppColors.primary), SizedBox(width: 12.w), Text('Date of Duty: ${DateFormat('dd MMM yyyy').format(_dutyDate)}', style: GoogleFonts.poppins(fontSize: 13.sp))])));

  Widget _buildDurationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Duration', style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedHours,
                    items: List.generate(13, (index) => DropdownMenuItem(value: index, child: Text('$index Hours', style: GoogleFonts.poppins(fontSize: 13.sp)))),
                    onChanged: (v) => setState(() => _selectedHours = v!),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMinutes,
                    items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('$m Minutes', style: GoogleFonts.poppins(fontSize: 13.sp)))).toList(),
                    onChanged: (v) => setState(() => _selectedMinutes = v!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonField() => TextFormField(controller: _reasonController, maxLines: 2, decoration: InputDecoration(hintText: 'Duty details...', filled: true, fillColor: AppColors.surfaceVariant, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary))));
  Widget _buildFilePicker() => GestureDetector(onTap: () async { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']); if (r != null) setState(() => _attachmentName = r.files.first.name); }, child: Container(width: double.infinity, padding: EdgeInsets.all(14.r), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _attachmentName == null ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3))), child: Row(children: [Icon(_attachmentName == null ? Icons.upload_file_rounded : Icons.check_circle_rounded, color: _attachmentName == null ? AppColors.error : AppColors.success, size: 20.sp), SizedBox(width: 12.w), Expanded(child: Text(_attachmentName ?? 'Attach Written Order (PDF)', style: GoogleFonts.poppins(fontSize: 13.sp, color: _attachmentName == null ? AppColors.textTertiary : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))])));
  Widget _buildSubmitButton(EmployeeLeaveProvider p) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isSubmitting ? null : () async { if (_attachmentName == null || _reasonController.text.isEmpty) { AppHelpers.showError(context, 'Missing details'); return; } setState(() => _isSubmitting = true); final durationStr = '${_selectedHours}h ${_selectedMinutes}m'; final globalProvider = Provider.of<LeaveProvider>(context, listen: false); if (await p.logHolidayDuty(dutyDate: _dutyDate, reason: _reasonController.text.trim(), attachment: _attachmentName!, duration: durationStr, globalProvider: globalProvider)) { Navigator.pop(context); AppHelpers.showSuccess(context, 'Duty Logged!'); } }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text('Submit Duty Report', style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white))));
}

class _EmployeeLeaveDetailsSheet extends StatelessWidget {
  final EmployeeLeaveRequest request;

  const _EmployeeLeaveDetailsSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final statusColor = request.status == 'approved' ? AppColors.success : request.status == 'pending' ? AppColors.warning : request.status == 'closed' ? Colors.blueGrey : AppColors.error;
    final statusBg = request.status == 'approved' ? AppColors.successLight : request.status == 'pending' ? AppColors.warningLight : request.status == 'closed' ? Colors.blueGrey.withOpacity(0.1) : AppColors.errorLight;

    return Container(
      padding: EdgeInsets.fromLTRB(20.r, 12.h, 20.r, MediaQuery.of(context).padding.bottom + 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leave Application',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _infoTile('Leave Type', request.leaveType, Icons.event_note_outlined),
          Row(
            children: [
              Expanded(child: _infoTile('From', _formatDate(request.fromDate), Icons.calendar_today_outlined)),
              Expanded(child: _infoTile('To', _formatDate(request.toDate), Icons.event_available_outlined)),
            ],
          ),
          _infoTile('Total Duration', '${request.days} Day${request.days > 1 ? 's' : ''}', Icons.timer_outlined),
          SizedBox(height: 12.h),
          Text(
            'Reason for Leave',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              request.reason,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Timeline',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          _timelineItem('Applied on', request.appliedOn, Icons.check_circle_outline, AppColors.primary),
          if (request.status != 'pending')
            _timelineItem(
              request.status == 'approved' || request.status == 'closed' ? 'Approved by Admin' : 'Rejected by Admin',
              'Action taken on Central Database',
              request.status == 'rejected' ? Icons.cancel_outlined : Icons.verified_user_outlined,
              statusColor,
            ),
          if (request.status == 'closed')
            _timelineItem('Joined on', request.joiningDate ?? 'N/A', Icons.home_work_outlined, Colors.blueGrey),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(0, 48.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  String _formatDate(String d) {
    if (d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return d;
    }
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textTertiary)),
                Text(value, style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
