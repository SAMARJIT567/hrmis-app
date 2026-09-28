// ============================================================
// 📁 lib/features/leave/screens/leave_balance_screen.dart
// ============================================================
// Screen to show and manage Leave Balance for all leave types.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../models/leave_model.dart';

class LeaveBalanceScreen extends StatelessWidget {
  const LeaveBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final leaveProv = context.watch<LeaveProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: const Color(0xFF1E3A8A), size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAdmin ? 'Manage Leave Policy' : 'Leave Balance',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E3A8A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Leave Allocation' : 'Available Leave Types',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaveProv.policies.length,
              itemBuilder: (context, index) {
                final policy = leaveProv.policies[index];
                return _buildLeaveCard(context, policy, isAdmin);
              },
            ),
            // Special case for LWP removed as requested
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeavePolicy policy, bool isAdmin) {
    final used = policy.usedDays;
    final total = policy.totalDays;
    final available = total - used;
    final progress = total > 0 ? used / total : 0.0;
    final color = Color(policy.colorValue);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r)),
                child: Icon(AppHelpers.getLeaveIcon(policy.iconName), color: color, size: 22.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy.title,
                      style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Annual Allocation: $total Days',
                      style: GoogleFonts.poppins(fontSize: 11.sp, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24.sp),
                  onPressed: () => _showEditDialog(context, policy),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$available',
                      style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w800, color: color),
                    ),
                    Text(
                      'Available',
                      style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 6.h,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Allocated', '$total'),
              _miniStat('Used', '$used'),
              _miniStat('Remaining', '$available', isBold: true, color: color),
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Instruction: ${policy.description}',
              style: GoogleFonts.poppins(
                fontSize: 9.sp,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textTertiary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.sp, 
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, 
            color: color ?? AppColors.textPrimary
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, LeavePolicy policy) {
    final controller = TextEditingController(text: policy.totalDays.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${policy.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set new annual allocation days:', style: GoogleFonts.poppins(fontSize: 13.sp)),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                suffixText: 'Days',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null) {
                context.read<LeaveProvider>().updatePolicy(policy.id, newValue);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
