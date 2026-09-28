// ============================================================
// 📁 lib/core/utils/helpers.dart
// ─────────────────────────────────────────────────────────────
// Utility functions and helpers used across the app.
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class AppHelpers {
  AppHelpers._();

  // ─── Date Formatters ──────────────────────────────────────────
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // ─── Greeting based on time of day ────────────────────────────
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  // ─── Avatar Initials ──────────────────────────────────────────
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '';
    final parts = name.trim().split(' ');
    final activeParts = parts.where((p) => p.isNotEmpty).toList();
    if (activeParts.isEmpty) return '';
    if (activeParts.length == 1) return activeParts[0][0].toUpperCase();
    return (activeParts[0][0] + activeParts.last[0]).toUpperCase();
  }

  // ─── Avatar Background Color ──────────────────────────────────
  static Color getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1E40AF),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
      const Color(0xFF65A30D),
      const Color(0xFFDB2777),
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  // ─── Leave Status Color ───────────────────────────────────────
  static Color getLeaveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.leaveApproved;
      case 'rejected':
        return AppColors.leaveRejected;
      default:
        return AppColors.leavePending;
    }
  }

  static Color getLeaveStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.successLight;
      case 'rejected':
        return AppColors.errorLight;
      default:
        return AppColors.warningLight;
    }
  }

  // ─── Attendance Status Color ──────────────────────────────────
  static Color getAttendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.attendancePresent;
      case 'absent':
        return AppColors.attendanceAbsent;
      case 'late':
        return AppColors.attendanceLate;
      case 'leave':
        return AppColors.attendanceLeave;
      default:
        return AppColors.textSecondary;
    }
  }

  // ─── SnackBar helpers ─────────────────────────────────────────
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Dialog for System / Database / Admin issues ──────────────
  static void showAdminContactDialog(
    BuildContext context, {
    String title = 'System Notice',
    String message = 'A required server configuration or database record is missing. Please contact your system administrator for assistance.',
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    final lower = message.toLowerCase();
    final bool isAdminIssue = lower.contains('contact your system administrator') ||
        lower.contains('contact administrator') ||
        lower.contains('sqlstate') ||
        lower.contains('base table or view not found') ||
        lower.contains('database') ||
        lower.contains('server error') ||
        lower.contains('queryexception') ||
        lower.contains('pdoexception') ||
        lower.contains('server or database component is missing');

    if (isAdminIssue) {
      showAdminContactDialog(
        context,
        title: 'Contact Administrator',
        message: 'A required server configuration or database component is missing. Please contact your system administrator for assistance.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Department Icon ──────────────────────────────────────────
  static IconData getDepartmentIcon(String department) {
    switch (department.toLowerCase()) {
      case 'engineering':
        return Icons.code_rounded;
      case 'design':
        return Icons.design_services_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'finance':
        return Icons.account_balance_rounded;
      case 'hr':
        return Icons.people_rounded;
      case 'sales':
        return Icons.trending_up_rounded;
      case 'operations':
        return Icons.settings_rounded;
      case 'legal':
        return Icons.gavel_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  // ─── Leave Icon ───────────────────────────────────────────────
  static IconData getLeaveIcon(String iconName) {
    switch (iconName) {
      case 'event_note_rounded':
        return Icons.event_note_rounded;
      case 'medical_services_outlined':
      case 'medical_services_rounded':
        return Icons.medical_services_rounded;
      case 'beach_access_rounded':
        return Icons.beach_access_rounded;
      case 'pregnant_woman_rounded':
        return Icons.pregnant_woman_rounded;
      case 'child_care_rounded':
        return Icons.child_care_rounded;
      case 'celebration_rounded':
        return Icons.celebration_rounded;
      case 'heart_broken_rounded':
        return Icons.heart_broken_rounded;
      case 'history_edu_rounded':
        return Icons.history_edu_rounded;
      default:
        return Icons.help_outline;
    }
  }
}