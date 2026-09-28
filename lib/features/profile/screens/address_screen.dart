// ============================================================
// 📁 lib/features/profile/screens/address_screen.dart
// ============================================================
// Displays user's Present & Permanent Address from database
// Read-only: User can only view, cannot edit
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class AddressScreen extends StatelessWidget {
  final AuthUser? user;

  const AddressScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final hasPresent = (user?.presentAddress1?.isNotEmpty == true) ||
        (user?.presentCity?.isNotEmpty == true) ||
        (user?.presentState?.isNotEmpty == true);

    final hasPermanent = (user?.permanentAddress1?.isNotEmpty == true) ||
        (user?.permanentCity?.isNotEmpty == true) ||
        (user?.permanentState?.isNotEmpty == true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Address Details',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Present Address Card
            _buildAddressSection(
              title: 'Present Address',
              badgeText: 'Current Residence',
              icon: Icons.location_on_rounded,
              iconColor: AppColors.primary,
              hasData: hasPresent,
              children: [
                _buildAddressRow('Address Line 1', user?.presentAddress1),
                _buildAddressRow('Address Line 2', user?.presentAddress2),
                _buildAddressRow('Landmark', user?.presentLandmark),
                _buildAddressRow('Police Station', user?.presentPs),
                _buildAddressRow('Post Office', user?.presentPo),
                _buildAddressRow('City / Town', user?.presentCity),
                _buildAddressRow('District', user?.presentDistrict),
                _buildAddressRow('State', user?.presentState),
                _buildAddressRow('PIN Code', user?.presentPin),
              ],
            ),
            SizedBox(height: 20.h),

            // Permanent Address Card
            _buildAddressSection(
              title: 'Permanent Address',
              badgeText: 'Permanent Record',
              icon: Icons.home_work_rounded,
              iconColor: AppColors.secondary,
              hasData: hasPermanent,
              children: [
                _buildAddressRow('Address Line 1', user?.permanentAddress1),
                _buildAddressRow('Address Line 2', user?.permanentAddress2),
                _buildAddressRow('Address Line 3', user?.permanentAddress3),
                _buildAddressRow('Landmark', user?.permanentLandmark),
                _buildAddressRow('Police Station', user?.permanentPs),
                _buildAddressRow('Post Office', user?.permanentPo),
                _buildAddressRow('City / Town', user?.permanentCity),
                _buildAddressRow('District', user?.permanentDistrict),
                _buildAddressRow('State', user?.permanentState),
                _buildAddressRow('PIN Code', user?.permanentPin),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection({
    required String title,
    required String badgeText,
    required IconData icon,
    required Color iconColor,
    required bool hasData,
    required List<Widget> children,
  }) {
    // Filter non-null widgets
    final visibleChildren = children.where((w) => w is! SizedBox).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        badgeText,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content
          if (!hasData || visibleChildren.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.r),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 28.sp, color: AppColors.textTertiary),
                    SizedBox(height: 8.h),
                    Text(
                      'No address records available in database',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(children: visibleChildren),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'NULL') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value.trim(),
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
