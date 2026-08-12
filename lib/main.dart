import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:pathfinder/core/theme/app_colors.dart';
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
import 'features/navigation/domain/usecases/find_path_usecase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  print('[INIT] Loading .env...');
  await dotenv.load(fileName: '.env');

  print('[INIT] Initializing Supabase...');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  print('[INIT] ✓ Supabase initialized');

  print('[INIT] Initializing services...');
  await Get.putAsync(() => InitializeService().init());
  print('[INIT] ✓ Services initialized');
  runApp(MyApp());
}

class InitializeService extends GetxService {
  Future<InitializeService> init() async {
    // ─────────────────────────────────────────────────────────────────
    // الترتيب مهم جداً: كل service يُسجَّل بعد كل ما يعتمد عليه.
    // ─────────────────────────────────────────────────────────────────

    // 1. SupabaseClient — مسجَّل مرة واحدة فقط (singleton)
    print('[INIT] Registering SupabaseClient...');
    Get.put(Supabase.instance.client);

    // 2. BLE — لا يعتمد على أي شيء
    print('[INIT] Registering FlutterReactiveBle...');
    Get.put(FlutterReactiveBle());

    // CRITICAL: FlutterReactiveBle must be registered exactly ONCE and
    // shared by every controller that needs it. Previously
    // PermissionController and BeaconController each created their own
    // `FlutterReactiveBle()` instance which caused BeaconController's
    // `_ble.status` getter to stay stuck at `BleStatus.unknown` forever.
    // A single shared instance here + one statusStream subscription in
    // PermissionController is enough for the whole app.

    // 3. Navigation data layer (Supabase → DataSource → Repository)
    //    يجب أن يكون قبل BeaconController لأنه يعتمد على NavigationRepository
    print('[INIT] Registering NavigationRepository...');
    Get.put(SupabaseNavigationDataSource(Get.find<SupabaseClient>()));
    Get.put<NavigationRepository>(
      NavigationRepositoryImpl(Get.find<SupabaseNavigationDataSource>()),
    );
    print('[INIT] ✓ NavigationRepository registered');

    // 3.1 محرك A* الموحّد (domain/usecases) — دلوقتي هو المحرك الفعلي اللي
    //     NavigationScreenController بيستخدمه لحساب المسار. كان قبل كده
    //     متعمله import بس من غير تسجيل، فمكانش بيتنفذ خالص والتنقل كان
    //     شغال فعليًا عن طريق NavigationController القديم (تحت) — سايبينه
    //     مسجّل برضه لأن شاشات قديمة تانية (calibration/onboarding) لسه
    //     ممكن تعتمد عليه، بس مش هو اللي بيحسب المسار في الشاشة الرئيسية
    //     بقى.
    print('[INIT] Registering FindPathUseCase...');
    Get.put(FindPathUseCase());

    // 4. باقي الـ controllers (البترتيب)
    print('[INIT] Registering PermissionController...');
    Get.put(PermissionController());
    print('[INIT] Registering CompassController...');
    Get.put(CompassController());
    print('[INIT] Registering NavigationController...');
    Get.put(NavigationController());

    // 5. BeaconController — يعتمد على NavigationRepository (✓ مسجّل فوق)
    print('[INIT] Registering BeaconController...');
    Get.put(BeaconController());

    // 6. UI-related services
    print('[INIT] Registering ThemeController...');
    final themeController = Get.put(ThemeController());
    await themeController.ensureLoaded();
    print('[INIT] Registering LocaleController...');
    final localeController = Get.put(LocaleController());
    await localeController.ensureLoaded();

    print('[INIT] ✓ All services initialized');
    return this;
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'مجلس النواب',
      debugShowCheckedModeBanner: false,
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
      home: const AppRouter(),
    );
  }
}
