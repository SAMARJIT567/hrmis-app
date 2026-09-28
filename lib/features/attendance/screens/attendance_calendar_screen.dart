// ============================================================
// 📁 lib/features/attendance/screens/attendance_calendar_screen.dart
// ============================================================
// Calendar Screen - NO BOTTOM NAVIGATION (Parent se milega)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/employee_attendance_provider.dart';
import '../../leave/providers/leave_provider.dart';
import '../../../core/constants/app_colors.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeAttendanceProvider>().loadMyAttendance(
        month: DateFormat('MM').format(_currentMonth),
        year: DateFormat('yyyy').format(_currentMonth),
      );
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
    context.read<EmployeeAttendanceProvider>().loadMyAttendance(
      month: DateFormat('MM').format(newMonth),
      year: DateFormat('yyyy').format(newMonth),
    );
  }

  String? getStatusForDate(DateTime date, EmployeeAttendanceProvider attendanceProv, LeaveProvider leaveProv) {
    // 1. Check approved/pending leave applications from leave provider (can be past or future!)
    for (final req in leaveProv.allRequests) {
      if (req.status == 'approved' || req.status == 'pending') {
        try {
          DateTime fromDate;
          DateTime toDate;
          if (req.fromDate.contains(RegExp(r'[a-zA-Z]'))) {
            fromDate = DateFormat('dd MMM yyyy').parse(req.fromDate);
          } else {
            fromDate = DateFormat('yyyy-MM-dd').parse(req.fromDate);
          }
          if (req.toDate.contains(RegExp(r'[a-zA-Z]'))) {
            toDate = DateFormat('dd MMM yyyy').parse(req.toDate);
          } else {
            toDate = DateFormat('yyyy-MM-dd').parse(req.toDate);
          }

          // Normalize times
          final check = DateTime(date.year, date.month, date.day);
          final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
          final to = DateTime(toDate.year, toDate.month, toDate.day);

          if (!check.isBefore(from) && !check.isAfter(to)) {
            if (req.leaveType.toLowerCase().contains('tour')) {
              return 'Tour';
            }
            if (req.leaveType.toLowerCase().contains('half')) {
              return 'Half Day';
            }
            return 'Leave';
          }
        } catch (_) {}
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate.isAfter(todayDate)) return null;

    // Check records from provider
    for (final record in attendanceProv.records) {
      try {
        DateTime recordDate;
        if (record.date.contains(RegExp(r'[a-zA-Z]'))) {
          recordDate = DateFormat('dd MMM yyyy').parse(record.date);
        } else {
          recordDate = DateFormat('yyyy-MM-dd').parse(record.date);
        }

        if (recordDate.year == date.year &&
            recordDate.month == date.month &&
            recordDate.day == date.day) {
          return record.status;
        }
      } catch (_) {
        final keyYmd = DateFormat('yyyy-MM-dd').format(date);
        final keyDmy = DateFormat('dd MMM yyyy').format(date);
        if (record.date == keyYmd || record.date == keyDmy) {
          return record.status;
        }
      }
    }

    // Check holidays from Laravel
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (attendanceProv.holidays.contains(dateStr)) {
      return 'Holiday';
    }

    // Check weekend from Laravel
    final dayOfWeek = DateFormat('EEEE').format(date); // e.g. "Sunday"
    if (dayOfWeek.toLowerCase() == attendanceProv.weekend.toLowerCase()) {
      return 'Weekend';
    }

    return null;
  }

  Color getStatusColor(String? status) {
    if (status == null) return AppColors.border;
    switch (status) {
      case 'Present': return const Color(0xFF059905); // backend .present: rgba(5, 153, 5, 0.6)
      case 'Absent': return const Color(0xFFFC0000);  // backend .absent: rgba(252, 0, 0, 0.6)
      case 'Leave': return const Color(0xFFAA7FE4);   // backend .on_leave: rgba(170, 127, 228, 0.4)
      case 'Tour': return const Color(0xFFAA7FE4);    // backend .on_tour: rgba(170, 127, 228, 0.4)
      case 'Half Day': return const Color(0xFFAA7FE4);// backend .half_day: rgba(170, 127, 228, 0.4)
      case 'Late':
      case 'Late In': return const Color(0xFFAD4E4E); // backend .not_in_time: rgba(173, 78, 78, 0.4)
      case 'Early Out': return const Color(0xFF032EEC);// backend .early_out: rgba(3, 46, 236, 0.6)
      case 'Holiday': return const Color(0xFF7E7B7B); // backend .holiday: rgba(126, 123, 123, 0.1)
      case 'Weekend': return const Color(0xFF9E9E9E); // backend weekend/off
      default: return AppColors.textTertiary;
    }
  }

  String getStatusIcon(String? status) {
    if (status == null) return '-';
    switch (status) {
      case 'Present': return '✓';
      case 'Absent': return '✗';
      case 'Leave': return '🌴';
      case 'Holiday': return '🎉';
      case 'Late':
      case 'Late In': return '⏰';
      case 'Weekend': return 'WE';
      case 'Tour': return 'T';
      case 'Half Day': return 'hd';
      default: return '•';
    }
  }

  String getStatusDisplay(String? status) {
    if (status == null) return 'No Record';
    return status;
  }

  void _previousMonth() {
    _onMonthChanged(DateTime(_currentMonth.year, _currentMonth.month - 1));
  }

  void _nextMonth() {
    _onMonthChanged(DateTime(_currentMonth.year, _currentMonth.month + 1));
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProv = context.watch<EmployeeAttendanceProvider>();
    final leaveProv = context.watch<LeaveProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Attendance Calendar',
          style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [_buildMonthSelector()],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildLegend(),
            _buildCalendar(attendanceProv, leaveProv),
            _buildSummaryCards(attendanceProv, leaveProv),
            _buildSelectedDateInfo(attendanceProv, leaveProv),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: _previousMonth,
            iconSize: 24.sp,
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: _nextMonth,
            iconSize: 24.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final legendItems = [
      {'status': 'Present', 'color': getStatusColor('Present')},
      {'status': 'Absent', 'color': getStatusColor('Absent')},
      {'status': 'Leave', 'color': getStatusColor('Leave')},
      {'status': 'Late In', 'color': getStatusColor('Late In')},
      {'status': 'Half Day', 'color': getStatusColor('Half Day')},
      {'status': 'Tour', 'color': getStatusColor('Tour')},
      {'status': 'Holiday', 'color': getStatusColor('Holiday')},
      {'status': 'Weekend', 'color': getStatusColor('Weekend')},
    ];

    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.w,
        runSpacing: 4.h,
        children: legendItems.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.w, height: 8.h,
                decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle),
              ),
              SizedBox(width: 3.w),
              Text(
                item['status'] as String,
                style: GoogleFonts.poppins(fontSize: 9.sp, color: AppColors.textSecondary),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendar(EmployeeAttendanceProvider attendanceProv, LeaveProvider leaveProv) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _currentMonth,
        currentDay: DateTime.now(),
        headerVisible: false, // We use the month selector in the AppBar
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        daysOfWeekHeight: 28.h,
        rowHeight: 48.h,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDate, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _currentMonth = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _onMonthChanged(focusedDay);
        },
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.poppins(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
          weekendStyle: GoogleFonts.poppins(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
        calendarStyle: const CalendarStyle(
          isTodayHighlighted: false,
          outsideDaysVisible: false,
        ),
        calendarBuilders: CalendarBuilders(
          prioritizedBuilder: (context, day, focusedDay) {
            if (day.month != focusedDay.month) {
              return const SizedBox.shrink(); // Hide outside days
            }

            final date = DateTime(day.year, day.month, day.day);
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;
            final status = getStatusForDate(date, attendanceProv, leaveProv);

            final dayOfWeek = DateFormat('EEEE').format(date);
            final isWeekend = dayOfWeek.toLowerCase() == attendanceProv.weekend.toLowerCase();

            // Determine status display category
            String displayStatus = '';
            if (status != null) {
              displayStatus = status;
            } else if (isWeekend) {
              displayStatus = 'Weekend';
            } else if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
              displayStatus = 'Absent';
            }

            // Determine color and text color matching backend colors
            Color cellBgColor = Colors.grey.withValues(alpha: 0.12);
            Color textColor = AppColors.textPrimary;
            Border? border;

            if (displayStatus.isNotEmpty) {
              cellBgColor = getStatusColor(displayStatus);
              textColor = Colors.white;
            }

            if (isToday) {
              border = Border.all(color: Colors.redAccent, width: 2.r);
            }

            final record = _getRecordForDate(date, attendanceProv.records);
            String leaveTypeName = '';
            if (displayStatus == 'Leave') {
              if (record != null && record.leaveType != null) {
                leaveTypeName = record.leaveType!;
              } else {
                // Find in leave requests
                for (final req in leaveProv.allRequests) {
                  if (req.status == 'approved' || req.status == 'pending') {
                    try {
                      DateTime fromDate;
                      DateTime toDate;
                      if (req.fromDate.contains(RegExp(r'[a-zA-Z]'))) {
                        fromDate = DateFormat('dd MMM yyyy').parse(req.fromDate);
                      } else {
                        fromDate = DateFormat('yyyy-MM-dd').parse(req.fromDate);
                      }
                      if (req.toDate.contains(RegExp(r'[a-zA-Z]'))) {
                        toDate = DateFormat('dd MMM yyyy').parse(req.toDate);
                      } else {
                        toDate = DateFormat('yyyy-MM-dd').parse(req.toDate);
                      }
                      final check = DateTime(date.year, date.month, date.day);
                      final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
                      final to = DateTime(toDate.year, toDate.month, toDate.day);
                      if (!check.isBefore(from) && !check.isAfter(to)) {
                        leaveTypeName = req.leaveType;
                        break;
                      }
                    } catch (_) {}
                  }
                }
                if (leaveTypeName.isEmpty) {
                  leaveTypeName = 'Leave';
                }
              }
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30.w,
                    height: 30.h,
                    decoration: BoxDecoration(
                      color: cellBgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  if (leaveTypeName.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      leaveTypeName,
                      style: GoogleFonts.poppins(
                        fontSize: 7.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(EmployeeAttendanceProvider attendanceProv, LeaveProvider leaveProv) {
    int present = 0;
    int absent = 0;
    int leave = 0;
    int holiday = 0;
    int weekend = 0;
    int lateIn = 0;
    int tour = 0;
    int halfDay = 0;

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, i);


      final status = getStatusForDate(date, attendanceProv, leaveProv);
      final dayOfWeek = DateFormat('EEEE').format(date);
      final isWeekend = dayOfWeek.toLowerCase() == attendanceProv.weekend.toLowerCase();

      String displayStatus = '';
      if (status != null) {
        displayStatus = status;
      } else if (isWeekend) {
        displayStatus = 'Weekend';
      } else if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        displayStatus = 'Absent';
      }

      switch (displayStatus) {
        case 'Present': present++; break;
        case 'Absent': absent++; break;
        case 'Leave': leave++; break;
        case 'Holiday': holiday++; break;
        case 'Weekend': weekend++; break;
        case 'Late':
        case 'Late In': lateIn++; break;
        case 'Tour': tour++; break;
        case 'Half Day': halfDay++; break;
      }
    }

    final summaryItems = [
      {'label': 'Present', 'count': present, 'code': 'P', 'color': getStatusColor('Present')},
      {'label': 'Absent', 'count': absent, 'code': 'A', 'color': getStatusColor('Absent')},
      {'label': 'On Leave', 'count': leave, 'code': 'L', 'color': getStatusColor('Leave')},
      {'label': 'Weekend', 'count': weekend, 'code': 'WE', 'color': getStatusColor('Weekend')},
      {'label': 'Holiday', 'count': holiday, 'code': 'H', 'color': getStatusColor('Holiday')},
      {'label': 'Late In', 'count': lateIn, 'code': 'Late', 'color': getStatusColor('Late In')},
      {'label': 'Half Day', 'count': halfDay, 'code': 'HD', 'color': getStatusColor('Half Day')},
      {'label': 'Tour', 'count': tour, 'code': 'T', 'color': getStatusColor('Tour')},
    ];

    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Summary',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summaryItems.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1.h),
            itemBuilder: (context, index) {
              final item = summaryItems[index];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.h,
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: (item['color'] as Color).withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          item['code'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: item['color'] as Color,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${item['count']} Day(s)',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: item['color'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateInfo(EmployeeAttendanceProvider attendanceProv, LeaveProvider leaveProv) {
    final status = getStatusForDate(_selectedDate, attendanceProv, leaveProv);
    final statusColor = getStatusColor(status);
    final isFutureDate = _selectedDate.isAfter(DateTime.now()) && status != 'Leave';

    return Container(
      margin: EdgeInsets.fromLTRB(12.r, 0, 12.r, 16.r),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        gradient: isFutureDate ? null : AppColors.primaryGradient,
        color: isFutureDate ? AppColors.surfaceVariant : null,
        borderRadius: BorderRadius.circular(12.r),
        border: isFutureDate ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40.w, height: 40.h,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.r)),
            child: Center(
              child: Text('${_selectedDate.day}', style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(fontSize: 11.sp, color: isFutureDate ? AppColors.textSecondary : Colors.white70),
                ),
                Text(
                  isFutureDate ? 'Future Date - No Record' : 'Status: ${getStatusDisplay(status)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isFutureDate ? AppColors.textSecondary : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32.w, height: 32.h,
            decoration: BoxDecoration(
              color: isFutureDate ? AppColors.border : statusColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                getStatusIcon(isFutureDate ? null : status),
                style: TextStyle(fontSize: 16.sp, color: isFutureDate ? AppColors.textTertiary : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  EmployeeAttendanceRecord? _getRecordForDate(DateTime date, List<EmployeeAttendanceRecord> records) {
    for (final record in records) {
      try {
        DateTime recordDate;
        if (record.date.contains(RegExp(r'[a-zA-Z]'))) {
          recordDate = DateFormat('dd MMM yyyy').parse(record.date);
        } else {
          recordDate = DateFormat('yyyy-MM-dd').parse(record.date);
        }
        if (recordDate.year == date.year &&
            recordDate.month == date.month &&
            recordDate.day == date.day) {
          return record;
        }
      } catch (_) {}
    }
    return null;
  }
}