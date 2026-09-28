// ============================================================
// 📁 lib/features/auth/screens/login_screen.dart
// ─────────────────────────────────────────────────────────────
// Professional login screen with form validation.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final bool _rememberMe = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        SizedBox(height: 48.h),
                        _buildLogoSection(),
                        SizedBox(height: 52.h),
                        _buildFormCard(),
                        SizedBox(height: 24.h),
                        _buildPoweredBy(),
                        SizedBox(height: 28.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (_, auth, __) {
              if (!auth.isLoading) return const SizedBox.shrink();
              return Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: Colors.white.withOpacity(0.85), // White glassmorphic overlay
                      child: Center(
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
                              'Logging in...',
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
                              'Please wait while we sync your profile settings',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return SizedBox(
      height: 320.h,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/aidc_building.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.80),
                    const Color(0xFF1E3A8A).withValues(alpha: 0.86),
                    const Color(0xFF0B192C).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 88.w,
          height: 88.h,
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Image.asset(
              'assets/images/aidc_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          AppStrings.appName,
          style: GoogleFonts.poppins(
            fontSize: 28.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          AppStrings.appFullName,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                AppStrings.welcomeBack,
                style: GoogleFonts.poppins(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Consumer<AuthProvider>(
              builder: (_, auth, __) {
                if (auth.errorMessage == null) return const SizedBox.shrink();
                return Container(
                  margin: EdgeInsets.only(bottom: 16.h),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFF8B4B4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: const Color(0xFFE53E3E), size: 22.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF9B2C2C),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 12.h),
            CustomTextField(
              label: 'Employee Code', hint: 'Enter employee code',
              controller: _emailCtrl,
              keyboardType: TextInputType.text,
              prefixIcon: Icons.person_outline_rounded,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return AppStrings.errorRequired;
                if (!val.contains('@') && val.trim().length < 3) {
                  return 'Please enter a valid email or employee code';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            CustomTextField(
              label: AppStrings.passwordLabel,
              hint: AppStrings.passwordHint,
              controller: _passwordCtrl,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (val) {
                if (val == null || val.isEmpty) return AppStrings.errorRequired;
                if (val.length < 6) return AppStrings.errorPassword;
                return null;
              },
            ),
            SizedBox(height: 20.h),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => CustomButton(
                label: AppStrings.loginButton,
                onPressed: auth.isLoading ? null : _handleLogin,
                isLoading: auth.isLoading,
                prefixIcon: Icons.login_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoweredBy() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32.w,
              height: 1.h,
              color: AppColors.border,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                'POWERED BY',
                style: GoogleFonts.poppins(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Container(
              width: 32.w,
              height: 1.h,
              color: AppColors.border,
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/webcom_logo.png',
            height: 32.h,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}