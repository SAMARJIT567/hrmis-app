// ============================================================
// main.dart — App Entry Point
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/attendance/providers/employee_attendance_provider.dart';
import 'features/leave/providers/leave_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/attendance/providers/office_settings_provider.dart';
import 'core/providers/navigation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const HRMISApp());
}

class HRMISApp extends StatelessWidget {
  const HRMISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => EmployeeAttendanceProvider()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => OfficeSettingsProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: const AppRoot(),
        );
      },
    );
  }
}
