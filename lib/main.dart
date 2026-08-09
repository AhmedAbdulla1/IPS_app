import 'package:pathfinder/utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// أضف هذه الـ imports الجديدة
import 'features/navigation/data/datasources/supabase_navigation_datasource.dart';
import 'features/navigation/data/repositories/navigation_repository_impl.dart';
import 'features/navigation/domain/repositories/navigation_repository.dart';
import 'features/navigation/domain/usecases/find_path_usecase.dart';

import 'controllers/beacon_controller.dart';
import 'controllers/compass_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/permission_controller.dart';
import 'core/localization/app_translations.dart';
import 'core/localization/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme_controller.dart';

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
    // CRITICAL: FlutterReactiveBle must be registered exactly ONCE and
    // shared by every controller that needs it. Previously
    // PermissionController and BeaconController each created their own
    // `FlutterReactiveBle()` instance. PermissionController subscribed to
    // its own instance's `statusStream` (required for the `.status`
    // getter to ever update off `BleStatus.unknown`), but BeaconController
    // never did on ITS instance -- so BeaconController's `_ble.status`
    // getter stayed stuck at `BleStatus.unknown` forever, and
    // `beaconInitPlatformState()`'s ready-check silently failed on every
    // call, permanently, and scanning never started even though
    // Bluetooth was demonstrably on and permissions were granted.
    //
    // Registering a single shared instance here means there is only ever
    // one `BleStatus` state machine for the whole app, and the one
    // subscription in PermissionController.onInit() is enough to keep it
    // live for every controller that reads it.
    print('[INIT] Registering SupabaseClient...');
    Get.put(Supabase.instance.client);

    print('[INIT] Registering FlutterReactiveBle...');
    Get.put(FlutterReactiveBle());

    print('[INIT] Registering PermissionController...');
    Get.put(PermissionController());
    print('[INIT] Registering CompassController...');
    Get.put(CompassController());
    print('[INIT] Registering NavigationController...');
    Get.put(NavigationController());
    print('[INIT] Registering BeaconController (dchs_flutter_beacon)...');
    Get.put(BeaconController());
    print('[INIT] Registering ThemeController...');
    final themeController = Get.put(ThemeController());
    await themeController.ensureLoaded();
    print('[INIT] Registering LocaleController...');
    final localeController = Get.put(LocaleController());
    await localeController.ensureLoaded();
    print('[INIT] Registering Supabase...');
    Get.put(Supabase.instance.client);
    print('[INIT] ✓ Supabase registered');

// ← أضف هذا الجزء الجديد:
    print('[INIT] Registering Navigation Services...');
    Get.put(SupabaseNavigationDataSource(Get.find<SupabaseClient>()));
    Get.put<NavigationRepository>(
      NavigationRepositoryImpl(Get.find<SupabaseNavigationDataSource>()),
    );
    Get.put(FindPathUseCase());
    print('[INIT] ✓ Navigation Services registered');

// والباقي زي ما هو...
    print('[INIT] Registering FlutterReactiveBle...');
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
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: Get.find<LocaleController>().locale.value,
      fallbackLocale: LocaleController.arabic,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: "Mulish",
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: kTextColor),
          bodyMedium: TextStyle(color: kTextColor),
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Or any appropriate dark color
        fontFamily: "Mulish",
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
