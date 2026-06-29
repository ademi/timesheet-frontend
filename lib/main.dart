import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'app/data/datasources/remote/auth_remote_datasource.dart';
import 'app/routes/app_pages.dart';
import 'app/themes/app_colors.dart';
import 'core/network/api_client.dart';
import 'core/services/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web-only: use clean path URLs (no `#`) so browser history, refresh, and the
  // back/forward buttons reconcile with GetX routing predictably. No-op concept
  // on mobile, hence the kIsWeb guard.
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  await GetStorage.init();
  final tokenStorage = TokenStorage();
  await tokenStorage.loadFromStorage();
  Get.put<TokenStorage>(tokenStorage, permanent: true);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ShiftMateApp());
}

class ShiftMateApp extends StatefulWidget {
  const ShiftMateApp({super.key});

  @override
  State<ShiftMateApp> createState() => _ShiftMateAppState();
}

class _ShiftMateAppState extends State<ShiftMateApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshToken();
    }
  }

  Future<void> _maybeRefreshToken() async {
    if (!Get.isRegistered<TokenStorage>()) return;
    final tokenStorage = Get.find<TokenStorage>();
    if (!tokenStorage.needsProactiveRefresh()) return;
    final refreshToken = tokenStorage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;
    if (!Get.isRegistered<ApiClient>()) return;
    try {
      final client = Get.find<ApiClient>();
      final newTokens = await executeRefreshRequest(client.plainDio, refreshToken);
      await tokenStorage.persistTokens(
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
      );
    } catch (_) {
      // Next API call will use AuthInterceptor refresh-or-logout flow.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      ensureScreenSize: true,
      // `.sp` scales fonts by the window size relative to the 390x844 phone
      // design. On web the window is far larger than a phone, so the raw scale
      // grows well above 1 and every `.sp` font (app bar, buttons, inputs,
      // date picker) balloons. Allow shrinking on tiny phones, but never
      // enlarge beyond the design size on tablet/web.
      fontSizeResolver: (fontSize, instance) {
        final scale = instance.scaleText;
        return fontSize * (scale > 1 ? 1 : scale);
      },
      builder: (context, child) => GetMaterialApp(
        title: 'ShiftMate',
        debugShowCheckedModeBanner: false,
        theme: _appTheme(),
        // Registers session-scoped dependencies (auth graph incl. AuthController,
        // and GatewayController) at startup so they exist on every entry point —
        // notably a web refresh on a deep route, where the gateway/login route
        // bindings never run. Idempotent: skips anything already registered.
        initialBinding: InitialBinding(),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}

/// Global theme with phone-density sizing via screenutil.
/// Values match the previous hardcoded constants at the 390dp design width.
ThemeData _appTheme() {
  return ThemeData(
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textLight,
      primaryContainer: AppColors.primaryLight,
      secondary: AppColors.accent,
      onSecondary: AppColors.textLight,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.darkBrown,
      foregroundColor: AppColors.textLight,
      iconTheme: const IconThemeData(color: AppColors.textLight),
      actionsIconTheme: const IconThemeData(color: AppColors.textLight),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14.r,
        vertical: 12.r,
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16.sp,
        color: AppColors.textDark,
      ),
    ),
    useMaterial3: true,
  );
}
