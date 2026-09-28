// ============================================================
// 📁 lib/features/profile/screens/edit_profile_screen.dart
// ============================================================
// Displays all employee profile details from database
// Includes Official, Personal, Contact, and Banking info
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Helper to convert base64 string to Uint8List
  Uint8List _base64ToBytes(String base64String) {
    try {
      final base64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return base64Decode(base64);
    } catch (e) {
      return Uint8List(0);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'NULL') return '—';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return raw.split(' ').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final profileProvider = context.watch<ProfileProvider>();
    final currentImage = profileProvider.profileImage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Profile Details',
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
          children: [
            // Top Profile Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfilePhoto(user, currentImage),
                  SizedBox(height: 12.h),
                  Text(
                    user?.name ?? 'Employee Name',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    user?.designation.isNotEmpty == true
                        ? user!.designation
                        : (user?.email ?? ''),
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      user?.department.isNotEmpty == true ? user!.department : 'Department',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Official & Employment Details
            _buildSectionCard(
              title: 'Official Information',
              icon: Icons.badge_outlined,
              iconColor: AppColors.primary,
              items: [
                _DetailRow('Employee Code', user?.empCode.isNotEmpty == true ? user!.empCode : user?.id),
                _DetailRow('Department', user?.department),
                _DetailRow('Designation', user?.designation),
                _DetailRow('Appointment Type', user?.employeeType ?? 'Permanent'),
                _DetailRow('Date of Joining', _formatDate(user?.joiningDate)),
                _DetailRow('Date of Retirement', _formatDate(user?.retirementDate)),
                _DetailRow('Personal File No', user?.personalFileNo),
              ],
            ),
            SizedBox(height: 16.h),

            // Personal Information
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline_rounded,
              iconColor: AppColors.secondary,
              items: [
                _DetailRow('Full Name', user?.name),
                _DetailRow('Father / Guardian', user?.guardianName),
                _DetailRow('Mother\'s Name', user?.mothersName),
                _DetailRow('Spouse Name', user?.spouseName),
                _DetailRow('Date of Birth', _formatDate(user?.dob)),
                _DetailRow('Gender', user?.gender),
                _DetailRow('Blood Group', user?.bloodGroup),
                _DetailRow('Nationality', user?.nationality),
                _DetailRow('Religion', user?.religion),
                _DetailRow('Caste', user?.caste),
              ],
            ),
            SizedBox(height: 16.h),

            // Contact Information
            _buildSectionCard(
              title: 'Contact Information',
              icon: Icons.contact_phone_outlined,
              iconColor: AppColors.success,
              items: [
                _DetailRow('Email Address', user?.email),
                _DetailRow('Mobile Number', user?.mobileNumber),
                _DetailRow('Alternate Mobile', user?.alternateMobile),
              ],
            ),
            SizedBox(height: 16.h),

            // Banking & Financial Details
            _buildSectionCard(
              title: 'Bank & Statutory Details',
              icon: Icons.account_balance_outlined,
              iconColor: AppColors.warning,
              items: [
                _DetailRow('Bank Account No', user?.bankAcNo),
                _DetailRow('Bank Name', user?.bankName),
                _DetailRow('Bank IFSC Code', user?.bankIfscNo),
                _DetailRow('PAN Number', user?.panNo),
                _DetailRow('Aadhar Number', user?.aadharNumber),
                _DetailRow('PF Account No', user?.pfNo),
                _DetailRow('UAN Number', user?.uanNo),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(AuthUser? user, String? imageBase64) {
    final avatarUrl = user?.avatarUrl?.trim();
    return Center(
      child: Container(
        width: 90.w,
        height: 90.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? Image.network(
                  avatarUrl.startsWith('http')
                      ? avatarUrl
                      : '${ApiService().baseUrl.replaceAll(RegExp(r'/api/?$'), '').replaceAll(RegExp(r'/+$'), '')}/${avatarUrl.replaceAll(RegExp(r'^/+'), '')}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => imageBase64 != null && imageBase64.isNotEmpty
                      ? Image.memory(
                          _base64ToBytes(imageBase64),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user),
                        )
                      : _buildAvatarPlaceholder(user),
                )
              : (imageBase64 != null && imageBase64.isNotEmpty)
                  ? Image.memory(
                      _base64ToBytes(imageBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user),
                    )
                  : _buildAvatarPlaceholder(user),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(AuthUser? user) {
    final initials = AppHelpers.getInitials(user?.name ?? 'U');
    return Container(
      width: 90.w,
      height: 90.h,
      color: Colors.transparent,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 30.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_DetailRow> items,
  }) {
    // Filter out rows with null/empty values
    final validItems = items.where((i) => i.value != null && i.value!.trim().isNotEmpty && i.value!.trim() != '—' && i.value!.trim() != 'NULL').toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
            child: Row(
              children: [
                Icon(icon, size: 18.sp, color: iconColor),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: validItems.isEmpty
                ? Text(
                    'No details recorded',
                    style: GoogleFonts.poppins(fontSize: 12.sp, color: AppColors.textTertiary),
                  )
                : Column(
                    children: List.generate(validItems.length, (idx) {
                      final item = validItems[idx];
                      return Padding(
                        padding: EdgeInsets.only(bottom: idx == validItems.length - 1 ? 0 : 10.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120.w,
                              child: Text(
                                item.label,
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
                                item.value ?? '—',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5.sp,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String? value;
  const _DetailRow(this.label, this.value);
}