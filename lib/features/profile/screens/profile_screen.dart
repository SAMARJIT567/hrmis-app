// ============================================================
// 📁 lib/features/profile/screens/profile_screen.dart
// ============================================================
// Role-based profile screen - Shows user info properly
// Employee can edit their profile
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leave/screens/employee_leave_screen.dart';
import '../../../core/services/api_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'address_screen.dart';
import 'edit_profile_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _profileImageBase64;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchProfile();
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = 'v2.0.1';
        });
      }
    }
  }

  void _loadProfileImage() async {
    final auth = context.read<AuthProvider>();
    final image = await auth.getProfileImage();
    if (mounted) {
      setState(() {
        _profileImageBase64 = image;
      });
    }
  }

  Widget _buildAvatarImage(AuthUser? user) {
    final avatarUrl = user?.avatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final fullUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : '${ApiService().baseUrl.replaceAll(RegExp(r'/api/?$'), '').replaceAll(RegExp(r'/+$'), '')}/${avatarUrl.replaceAll(RegExp(r'^/+'), '')}';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _profileImageBase64 != null && _profileImageBase64!.isNotEmpty
            ? Image.memory(
                _base64ToBytes(_profileImageBase64!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user),
              )
            : _buildAvatarPlaceholder(user),
      );
    }
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      return Image.memory(
        _base64ToBytes(_profileImageBase64!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user),
      );
    }
    return _buildAvatarPlaceholder(user);
  }

  // FIXED: Helper to convert base64 string to Uint8List
  Uint8List _base64ToBytes(String base64String) {
    try {
      // Remove data:image/jpeg;base64, prefix if present
      final base64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      // Decode base64 to Uint8List
      return base64Decode(base64);
    } catch (e) {
      // Return empty Uint8List if decoding fails
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, user),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD.w,
              vertical: AppDimensions.paddingMD.h,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildInfoCard(user),
                SizedBox(height: 20.h),

                 _sectionLabel('Account'),
                SizedBox(height: 8.h),
                _buildSettingsCard([
                  _SettingItem(
                    Icons.home_outlined,
                    'Address',
                    AppColors.primary,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddressScreen(user: user)),
                    ),
                  ),
                  _SettingItem(
                    Icons.person_outline_rounded,
                    'Edit Profile',
                    AppColors.secondary,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  _SettingItem(Icons.account_balance_wallet_outlined, 'Leave Balance', AppColors.success, () {
                    Navigator.pushNamed(context, '/leave-balance');
                  }),
                  _SettingItem(Icons.event_note_outlined, 'Leave Management', AppColors.primary, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeLeaveScreen()),
                    );
                  }),
                  _SettingItem(Icons.phonelink_setup_rounded, 'Request Device Change', AppColors.warning, () {
                    _showDeviceChangeDialog(context, user);
                  }),
                ]),
                SizedBox(height: 20.h),

                _buildLogoutButton(context, auth),
                SizedBox(height: 10.h),

                Center(
                  child: Text(
                    'AIDC HRMIS ${_appVersion.isNotEmpty ? _appVersion : 'v2.0.1'}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthUser? user) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          // Background Building Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/aidc_building.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Deep Dark Blue Gradient Overlay (High opacity for excellent profile and text visibility)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.88),
                    const Color(0xFF1E3A8A).withValues(alpha: 0.92),
                    const Color(0xFF0B192C).withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),
          // Header Content
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20.h,
              bottom: 32.h,
              left: AppDimensions.paddingMD.w,
              right: AppDimensions.paddingMD.w,
            ),
            child: Column(
              children: [
                Container(
                  width: 88.w,
                  height: 88.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                  ),
                  child: ClipOval(
                    child: _buildAvatarImage(user),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  user?.name ?? 'User Name',
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                SizedBox(height: 6.h),
                Text(
                  user?.designation.isNotEmpty == true ? user!.designation : (user?.email ?? 'user@company.com'),
                  style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.85)),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppHelpers.getDepartmentIcon(user?.department ?? ''), size: 14.sp, color: Colors.white70),
                      SizedBox(width: 6.w),
                      Text(
                        user?.department.isNotEmpty == true ? user!.department : 'General Department',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(AuthUser? user) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Text(
          AppHelpers.getInitials(user?.name ?? 'U'),
          style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInfoCard(AuthUser? user) {
    final employeeId = user?.empCode.isNotEmpty == true ? user!.empCode : (user?.id ?? 'N/A');
    
    String joiningDate = 'N/A';
    if (user?.joiningDate != null && user!.joiningDate!.isNotEmpty) {
      try {
        final parsed = DateTime.parse(user.joiningDate!);
        joiningDate = DateFormat('MMM yyyy').format(parsed);
      } catch (_) {
        joiningDate = user.joiningDate!;
      }
    }

    final empType = user?.employeeType ?? 'Permanent';

    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingMD.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG.r),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _InfoChip(Icons.badge_outlined, employeeId, 'Employee ID'),
          _InfoDivider(),
          _InfoChip(Icons.calendar_today, joiningDate, 'Joined'),
          _InfoDivider(),
          _InfoChip(Icons.work_outline, empType, 'Employee Type'),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {bool isAdminSection = false}) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: isAdminSection ? AppColors.primary : AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingsCard(List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG.r),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return _settingTile(items[i], i == items.length - 1);
        }),
      ),
    );
  }

  Widget _settingTile(_SettingItem item, bool isLast) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLG.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD.w, vertical: 14.h),
        decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10.r)),
              child: Icon(item.icon, size: 20.sp, color: item.color),
            ),
            SizedBox(width: 14.w),
            Expanded(child: Text(item.label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
            Icon(Icons.chevron_right, size: 20.sp, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            contentPadding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 10.h),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded, color: AppColors.error, size: 30.sp),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Confirm Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Are you sure you want to logout?\nYou will need to login again to access your account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actionsPadding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          context.read<NavigationProvider>().reset();
          await auth.logout();
          if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD.r),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.error, size: 20.sp),
            SizedBox(width: 8.w),
            Text('Logout', style: GoogleFonts.poppins(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.error)),
          ],
        ),
      ),
    );
  }

  void _showDeviceChangeDialog(BuildContext context, AuthUser? user) {
    final empCode = (user?.empCode.isNotEmpty == true) ? user!.empCode : (user?.id ?? 'N/A');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.warning,
                size: 36.sp,
              ),
            ),
            SizedBox(height: 16.h),

            // Title
            Text(
              'Contact Administrator',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),

            // Message
            Text(
              'For security and attendance verification, device registration cannot be changed directly from the mobile app.',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),

            // Info Box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 16.sp, color: AppColors.primary),
                      SizedBox(width: 6.w),
                      Text(
                        'Employee ID: $empCode',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Please contact your HR / System Administrator with your Employee ID to unbind or change your registered device.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5.sp,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _InfoChip(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20.sp, color: AppColors.primary),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.sp, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40.h, color: AppColors.border);
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SettingItem(this.icon, this.label, this.color, this.onTap);
}