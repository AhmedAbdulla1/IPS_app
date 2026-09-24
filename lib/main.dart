import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/beacon_controller.dart';
import 'controllers/compass_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/permission_controller.dart';
import 'core/localization/app_translations.dart';
import 'core/localization/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme_controller.dart';
import 'features/navigation/data/datasources/supabase_navigation_datasource.dart';
import 'features/navigation/data/repositories/navigation_repository_impl.dart';
import 'features/navigation/domain/repositories/navigation_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/utils/app_logger.dart';

import 'features/navigation/domain/usecases/find_path_usecase.dart';

Future<void> main() async {
  // In Release mode, completely silence debugPrint and unhandled errors
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    FlutterError.onError = (FlutterErrorDetails details) {
      Sentry.captureException(details.exception, stackTrace: details.stack);
    };
  }

  // Intercept and silence GetX internal route/controller logs in Release mode
  Get.config(
    enableLog: !kReleaseMode,
    logWriterCallback: (String text, {bool isError = false}) {
      if (!kReleaseMode) {
        debugPrint(text);
      }
    },
  );

  // Intercept all print() calls across the app:
  // In Release mode: 100% silenced (zero console output).
  // In Debug mode: allowed for local developer debugging.
  runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

      AppLogger.info('[INIT] Loading .env...');
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        AppLogger.warn('[INIT] Could not load .env file: $e');
      }

      final sentryDsn = dotenv.env['SENTRY_DSN'] ??
          'https://4dc8dac85044ed98cee1457e3b18063d@o4512139271667712.ingest.de.sentry.io/4512139306729552';

      if (sentryDsn.trim().isNotEmpty) {
        AppLogger.info('[INIT] Initializing Sentry for crash reporting...');
        await SentryFlutter.init(
          (options) {
            options.dsn = sentryDsn.trim();
            options.tracesSampleRate = 1.0;
            options.sendDefaultPii = false;
            options.enableAutoPerformanceTracing = true;
            options.debug = false; // SILENCE all internal Sentry SDK logs
          },
          appRunner: () => _initAndRunApp(),
        );
      } else {
        AppLogger.info('[INIT] Sentry DSN not configured, running without crash reporting.');
        await _initAndRunApp();
      }
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        if (!kReleaseMode) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

Future<void> _initAndRunApp() async {
  if (kReleaseMode) {
    runZoned(
      () => _executeApp(),
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          // Zero console in Release mode
        },
      ),
    );
  } else {
    await _executeApp();
  }
}

Future<void> _executeApp() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
      'https://dqnmxlljqiqgqmntzvcx.supabase.co';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w';

  AppLogger.info('[INIT] Initializing Supabase...');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    debug: !kReleaseMode,
  );
  AppLogger.info('[INIT] ✓ Supabase initialized');

  AppLogger.info('[INIT] Initializing services...');
  await Get.putAsync(() => InitializeService().init());
  AppLogger.info('[INIT] ✓ Services initialized');

  runApp(const MyApp());
}

class InitializeService extends GetxService {
  Future<InitializeService> init() async {
    // ─────────────────────────────────────────────────────────────────
    // الترتيب مهم جداً: كل service يُسجَّل بعد كل ما يعتمد عليه.
    // ─────────────────────────────────────────────────────────────────

    // 1. SupabaseClient — مسجَّل مرة واحدة فقط (singleton)
    AppLogger.info('[INIT] Registering SupabaseClient...');
    Get.put(Supabase.instance.client);

    // 2. BLE — لا يعتمد على أي شيء
    AppLogger.info('[INIT] Registering FlutterReactiveBle...');
    final ble = FlutterReactiveBle();
    ble.logLevel = kReleaseMode ? LogLevel.none : LogLevel.verbose;
    Get.put(ble);

    // CRITICAL: FlutterReactiveBle must be registered exactly ONCE and
    // shared by every controller that needs it. Previously
    // PermissionController and BeaconController each created their own
    // `FlutterReactiveBle()` instance which caused BeaconController's
    // `_ble.status` getter to stay stuck at `BleStatus.unknown` forever.
    // A single shared instance here + one statusStream subscription in
    // PermissionController is enough for the whole app.

    // 3. Navigation data layer (Supabase → DataSource → Repository)
    //    يجب أن يكون قبل BeaconController لأنه يعتمد على NavigationRepository
    AppLogger.info('[INIT] Registering NavigationRepository...');
    Get.put(SupabaseNavigationDataSource(Get.find<SupabaseClient>()));
    Get.put<NavigationRepository>(
      NavigationRepositoryImpl(Get.find<SupabaseNavigationDataSource>()),
    );
    AppLogger.info('[INIT] ✓ NavigationRepository registered');

    // 3.1 محرك A* الموحّد (domain/usecases)
    AppLogger.info('[INIT] Registering FindPathUseCase...');
    Get.put(FindPathUseCase());

    // 4. باقي الـ controllers (البترتيب)
    AppLogger.info('[INIT] Registering PermissionController...');
    Get.put(PermissionController());
    AppLogger.info('[INIT] Registering CompassController...');
    Get.put(CompassController());
    AppLogger.info('[INIT] Registering NavigationController...');
    Get.put(NavigationController());

    // 5. BeaconController — يعتمد على NavigationRepository (✓ مسجّل فوق)
    AppLogger.info('[INIT] Registering BeaconController...');
    Get.put(BeaconController());

    // 6. UI-related services
    AppLogger.info('[INIT] Registering ThemeController...');
    final themeController = Get.put(ThemeController());
    await themeController.ensureLoaded();
    AppLogger.info('[INIT] Registering LocaleController...');
    final localeController = Get.put(LocaleController());
    await localeController.ensureLoaded();

    AppLogger.info('[INIT] ✓ All services initialized');
    return this;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'مجلس النواب',
      debugShowCheckedModeBanner: false,
      enableLog: !kReleaseMode,
      logWriterCallback: (String text, {bool isError = false}) {
        if (!kReleaseMode) {
          debugPrint(text);
        }
      },
      translations: AppTranslations(),
      locale: Get.find<LocaleController>().locale.value,
      fallbackLocale: LocaleController.arabic,
      theme: ThemeData(
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      home: const AppRouter(),
    );
  }
}
