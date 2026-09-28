// ============================================================
// navigation/main_navigation.dart
// ============================================================
// 4 TABS: Dashboard, Calendar, Leave, Profile
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/attendance/screens/employee_attendance_screen.dart';
import '../features/attendance/screens/attendance_calendar_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../core/providers/navigation_provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final List<Widget> _screens;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();

    _screens = const [
      EmployeeAttendanceScreen(),
      AttendanceCalendarScreen(),
      ProfileScreen(),
    ];

    _navItems = const [
      _NavItem(icon: Icons.access_time_outlined, activeIcon: Icons.access_time_filled, label: 'Attendance'),
      _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Calendar'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final navProv = context.watch<NavigationProvider>();

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
    }

    int currentIndex = navProv.currentIndex;
    if (currentIndex >= _navItems.length) {
      currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navProv.setIndex(0);
      });
    }

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (currentIndex != 0) {
          navProv.setIndex(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: (index) {
            navProv.setIndex(index);
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w400),
          elevation: 8,
          items: _navItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item.icon, size: 22.sp),
              activeIcon: Icon(item.activeIcon, size: 22.sp),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}