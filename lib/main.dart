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
import 'core/services/session_service.dart';
import 'core/services/token_storage.dart';
import 'core/time/tenant_civil_time.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimezoneDatabaseInitialized();
  // Web-only: use clean path URLs (no `#`) so browser history, refresh, and the
  // back/forward buttons reconcile with GetX routing predictably.
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
  runApp(const RostiqApp());
}

class RostiqApp extends StatefulWidget {
  const RostiqApp({super.key});

  @override
  State<RostiqApp> createState() => _RostiqAppState();
}

class _RostiqAppState extends State<RostiqApp> with WidgetsBindingObserver {
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
      final newTokens =
          await executeRefreshRequest(client.plainDio, refreshToken);
      await tokenStorage.persistTokens(
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
      );
      if (Get.isRegistered<SessionService>()) {
        await Get.find<SessionService>().hydrateFromMeContext();
      }
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
      // grows well above 1 — never enlarge beyond the design size on tablet/web.
      fontSizeResolver: (fontSize, instance) {
        final scale = instance.scaleText;
        return fontSize * (scale > 1 ? 1 : scale);
      },
      builder: (context, child) => GetMaterialApp(
        title: 'Rostiq',
        debugShowCheckedModeBanner: false,
        theme: _appTheme(),
        initialBinding: InitialBinding(),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}

ThemeData _appTheme() {
  return ThemeData(
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.hover,
      secondary: AppColors.accent,
      onSecondary: AppColors.onPrimary,
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
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        textStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
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
