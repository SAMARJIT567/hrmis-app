# 🏢 AIDC HRMIS — Attendance Management System

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen.svg)]()
[![Backend](https://img.shields.io/badge/Backend-Laravel%20API-red.svg)](https://laravel.com)

A high-performance, cross-platform mobile application developed for **Assam Industrial Development Corporation (AIDC)**. Designed for employees to punch in/out with geofencing validation, track monthly attendance calendars, and manage leave applications seamlessly.

---

## 🌟 Key Features

- **📍 Smart Geofenced Punch In / Out**
  - Real-time GPS coordinate verification against designated office polygon & radial zones.
  - Multi-zone office support with intelligent distance calculations.
  - 10-second GPS lock timeout with indoor fallback (`getLastKnownPosition`) to prevent freezing inside buildings.

- **📸 Instant Camera Verification**
  - Ultra-smooth front-camera viewfinder (`ResolutionPreset.high`) with zero shutter lag.
  - Optimized compressed capture (< 1MB) for sub-second uploads over mobile networks.
  - Native fallbacks to ensure crash-free operation on both Android and iOS.

- **📅 Interactive Attendance Calendar**
  - Month-by-month calendar view with instant visual status indicators.
  - 100% color-synchronized with the backend (`style-attendance.css`):
    - 🟢 **Present:** `#059905` (Green)
    - 🔴 **Absent:** `#FC0000` (Red)
    - 🟣 **On Leave / Half Day / Tour:** `#AA7FE4` (Soft Purple)
    - 🟤 **Late In:** `#AD4E4E` (Muted Brick Red)
    - 🔵 **Early Out:** `#032EEC` (Deep Blue)
    - ⚪ **Holiday & Weekend:** Neutral Grey / Slate
  - Comprehensive monthly attendance summary (Total Days Present, Absent, Leaves, Late Ins, etc.).

- **🌴 Leave Management**
  - View real-time available leave balances (Casual Leave, Earned Leave, etc.).
  - Apply for leaves directly with date pickers, reason, and attachment uploads.
  - Track leave approval status (Pending, Approved, Rejected).

- **👤 Employee Profile**
  - Official details: Employee ID, Designation, Department, PF Account No, UAN No.
  - Profile photo viewer and updater.
  - Present and Permanent address review from database.

- **🎨 Premium UI & Cross-Platform Adaptability**
  - Base design scaling using `ScreenUtilInit` (`375 x 812`), guaranteeing proportional scaling on all phones (iPhone SE to iPhone 16 Pro Max, and all Android screen sizes).
  - Dynamic Island and Notch padding handling via `MediaQuery.padding.top`.
  - Poppins typography from Google Fonts with smooth rubber-band `BouncingScrollPhysics`.
  - Custom AIDC branded app launcher icons across all screen densities (`mipmap-anydpi-v26` adaptive).

---

## 🏗️ Project Architecture

```
lib/
├── app/
│   ├── app.dart                   # Root MaterialApp & routing definitions
│   └── theme.dart                 # Global ThemeData & Poppins styling
├── core/
│   ├── config/
│   │   └── app_config.dart        # API Base URLs & endpoints
│   ├── constants/
│   │   ├── app_colors.dart        # Unified color palette tokens
│   │   ├── app_dimensions.dart    # Padding & radius standards
│   │   └── app_strings.dart       # Localized string constants
│   ├── providers/
│   │   └── navigation_provider.dart
│   ├── services/
│   │   ├── api_service.dart       # Dio HTTP client with JWT interceptor
│   │   ├── device_info_service.dart# Android ID & iOS identifierForVendor
│   │   └── location_service.dart  # Geolocator service with timeouts
│   └── utils/
│       └── helpers.dart           # Formatting, initials, status badges
├── features/
│   ├── attendance/
│   │   ├── models/                # Attendance & OfficeSettings models
│   │   ├── providers/             # Attendance & Geofencing providers
│   │   └── screens/
│   │       ├── attendance_calendar_screen.dart # Color-synced Calendar
│   │       ├── check_in_screen.dart            # Live Camera & GPS verification
│   │       └── employee_attendance_screen.dart # Main Dashboard & sticky header
│   ├── auth/
│   │   ├── providers/             # AuthProvider & Session management
│   │   └── screens/
│   │       ├── login_screen.dart  # Branded login with building overlay
│   │       └── splash_screen.dart # Animated splash screen
│   ├── leave/
│   │   ├── models/                # LeaveRequest & LeaveBalance models
│   │   ├── providers/             # LeaveProvider
│   │   └── screens/
│   │       ├── employee_leave_screen.dart      # Leave apply & tracking
│   │       └── leave_balance_screen.dart       # Leave balances
│   └── profile/
│       ├── providers/             # ProfileProvider
│       └── screens/
│           ├── address_screen.dart             # Present & Permanent addresses
│           ├── edit_profile_screen.dart        # Profile editor
│           └── profile_screen.dart             # Profile dashboard
├── navigation/
│   └── main_navigation.dart       # Unified 3-tab bottom navigation
└── main.dart                      # App entry point & provider injection
```

---

## 🛠️ Tech Stack & Packages

| Package | Purpose |
| :--- | :--- |
| **`provider`** | Reactive state management & dependency injection |
| **`dio`** | HTTP network client with error handling & multipart uploads |
| **`flutter_screenutil`** | Adaptive screen sizing across all devices |
| **`google_fonts`** | Modern typography (Poppins) |
| **`camera`** | Direct camera stream control for selfie check-in |
| **`geolocator`** | GPS coordinate fetching and geofence distance calculation |
| **`image_picker`** | Native photo capture & gallery picker |
| **`table_calendar`** | Customizable attendance calendar grid |
| **`device_info_plus`** | Hardware & platform device identity extraction |
| **`shared_preferences`**| Local persistent storage for auth tokens & user session |
| **`flutter_launcher_icons`** | Automated launcher icon generation for Android & iOS |

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK:** `>= 3.3.0` (Recommended: `3.22.x` or newer)
- **Dart SDK:** `>= 3.3.0 < 4.0.0`
- **Android Studio / Xcode** for platform builds

### 2. Installation
Clone the repository:
```bash
git clone https://github.com/SAMARJIT567/hrmis-app.git
cd hrmis-app
```

Install all dependencies:
```bash
flutter pub get
```

### 3. Configure API URL
Open `lib/core/config/app_config.dart` and update the backend server IP/Domain:
```dart
class AppConfig {
  static String get apiBaseUrl => 'http://<YOUR_SERVER_IP>:8000/api';
  static String get leaveApiBaseUrl => 'http://<YOUR_SERVER_IP>:8001/api';
}
```

### 4. Run the Application
```bash
# Debug mode on connected device/emulator
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
```

### 5. Build for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS IPA (Requires macOS & Xcode)
flutter build ipa --release
```

---

## 🔒 Native Permissions Configured

### Android (`android/app/src/main/AndroidManifest.xml`)
- `android.permission.INTERNET`
- `android.permission.CAMERA`
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

### iOS (`ios/Runner/Info.plist`)
- `NSCameraUsageDescription` (Selfie check-in)
- `NSMicrophoneUsageDescription` (Camera framework requirement)
- `NSLocationWhenInUseUsageDescription` (Geofence radius validation)
- `NSLocationAlwaysAndWhenInUseUsageDescription` (Geofence radius validation)
- `NSPhotoLibraryUsageDescription` (Profile picture and leave document uploads)

---

## 🏢 Organization & Credits

- **Organization:** Assam Industrial Development Corporation (AIDC)
- **Technology Partner:** Web.com India Pvt. Ltd.
- **Repository:** [SAMARJIT567/hrmis-app](https://github.com/SAMARJIT567/hrmis-app)
