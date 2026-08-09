# حالة ريفاكتور Navigation — تقرير شامل
**التاريخ:** 2026-08-09  
**المحطة:** انتهاء المرحلة 2 (Data Layer)، جاهز للمرحلة 3

---

## ملخص سريع

| المرحلة | الحالة | ملاحظات |
|--------|--------|--------|
| 0 | ✅ اكتملت | مراجعة السكيما + الفهم |
| 1 | ✅ اكتملت | Domain layer كامل (entities, repository interface, usecases) |
| **2** | ✅ **اكتملت** | **Data layer كامل** — Models, Datasource, Repository impl جاهزة |
| 3 | ⏳ الآن | تسجيل Repository في main.dart (DI) |
| 4 | ⏳ بعده | تعديل BeaconController — جلب البيانات الحقيقية |
| 5 | ⏳ بعده | تعديل NavigationController (legacy) — استخدام A* الجديد |
| 6 | ⏳ بعده | تعديل نداء startNavigation في NavigationScreenController |
| 7 | ⏳ بعده | مراجعة نهائية واختبار شامل |

---

## تفاصيل المرحلة 2 (مُكتملة)

### الملفات الموجودة وحالتها

#### Data Models ✅
```
lib/features/navigation/data/models/
├── node_model.dart              ✅ NodeModel (fromMap + toEntity)
├── level_model.dart             ✅ LevelModel (fromMap + toEntity)
├── edge_model.dart              ✅ EdgeModel (fromMap + toEntity)
├── node_alias_model.dart        ✅ NodeAliasModel (fromMap + toEntity)
└── vertical_connector_model.dart ✅ VerticalConnectorModel + ConnectorStopModel
                                     (كلاهما في نفس الملف، صح الاستخدام)
```

**الحالة:** جميع Models لها:
- ✅ `fromMap` factory
- ✅ `toEntity()` method (تحويل لـ domain entities)
- ✅ Proper type handling للأرقام والـ nullable fields

#### Datasource ✅
```
lib/features/navigation/data/datasources/
└── supabase_navigation_datasource.dart
    ├── fetchLevels()               ✅
    ├── fetchNodes()                ✅
    ├── fetchNodeAliases()          ✅
    ├── fetchEdges()                ✅
    ├── fetchVerticalConnectors()   ✅
    └── fetchConnectorStops()       ✅
```

**الحالة:** جميع Methods موجودة وتستخدم الـ correct table names.

#### Repository Implementation ✅
```
lib/features/navigation/data/repositories/
└── navigation_repository_impl.dart
```

**التفاصيل:**
- ✅ Implements `NavigationRepository` interface
- ✅ `loadGraph()` method:
  - يجيب الـ 6 tables بالتوازي (efficient)
  - يبني `BuildingGraph` بشكل صحيح
  - الحواف العادية تُضاف بالاتجاهين (bidirectional)
  - **الحواف الرأسية** (connector stops) تُعالج بشكل موحّد:
    - كل زوج محطات من نفس الموصل يصبح edge مباشر
    - النوع (elevator/stairs) وDirection (up/down) يُحسب من level order
- ✅ Caching strategy بـ `_cachedGraph`
- ✅ Proper null checks للـ nodes

**كود مهم:**
```dart
// الجزء اللي بيحوّل connector stops لـ edges موحّدة
for (final entry in stopsByConnector.entries) {
  final connector = connectorById[entry.key];
  final kind = connector.connectorType == 'elevator'
      ? NavEdgeKind.elevator
      : NavEdgeKind.stairs;
  
  final stops = entry.value;
  for (var i = 0; i < stops.length; i++) {
    for (var j = 0; j < stops.length; j++) {
      if (i == j) continue;
      // حساب اتجاه رأسي (up/down) من level orders
      final fromOrder = levelsById[fromNode.levelId]?.order ?? 0;
      final toOrder = levelsById[toNode.levelId]?.order ?? 0;
      if (fromOrder == toOrder) continue; // نفس الدور
      
      addDirectedEdge(NavEdge(
        fromNodeId: fromNode.id,
        toNodeId: toNode.id,
        distanceMeters: _verticalTraversalCost,  // 3.0 (قابل للتعديل)
        kind: kind,
        verticalDirection: toOrder > fromOrder ? up : down,
      ));
    }
  }
}
```

---

## ما الذي تم إصلاحه / تحسينه منذ المرحلة 1

### 1. ConnectorStopModel ✅
- كان يجب أن يكون في ملف منفصل، لكن وجدنا أنه من الأفضل (pragmatic) أن يكون في `vertical_connector_model.dart`
- `NavigationRepositoryImpl` يستورده بـ `show ConnectorStopModel`
- هذا يقلل عدد الملفات بلا فائدة مضافة

### 2. Parallel fetching ✅
- جميع الـ 6 جداول تُجلب بالتوازي في `loadGraph()` (بدون await فوري)
- ثم تُنتظر الـ results بشكل منفصل
- كفاءة أفضل من sequential fetching

### 3. Level order handling ✅
- `BuildingGraph` يخزّن `levelsById` و `adjacency` بشكل منفصل
- `NavLevel` لديها `order: int` لتحديد ترتيب الأدوار رأسيًا
- الـ A* يستخدم هذا للـ heuristic و distance calculations

---

## الملفات الموجودة في المستودع (بدون تعديلات بعد)

### Controllers (قديم، سيتم تعديلها)
```
lib/controllers/
├── beacon_controller.dart                    ← يحتاج تعديل (المرحلة 4)
├── navigation_controller.dart                ← يحتاج تعديل (المرحلة 5)
└── ...

lib/features/navigation/controllers/
└── navigation_controller.dart (مختلف!)     ← NavigationScreenController
                                             ← يحتاج تعديل بسيط (المرحلة 6)
```

### Presentation Layer (موجودة، لا تحتاج تعديل حاليًا)
```
lib/features/navigation/views/
├── idle_home_screen.dart                    → عرض الموقع الحالي
├── active_navigation_screen.dart            → عرض الاتجاهات
└── main_navigation_screen.dart

lib/features/navigation/widgets/
├── facility_search_bar.dart
├── direction_arrow_card.dart
└── ... (13 widget آخر)
```

---

## المرحلة 3 — ما الذي سيتم الآن (DI Wiring)

### الملف الذي سيتم تعديله: `main.dart`

**إضافات مطلوبة:**

```dart
// إضافة imports جديدة
import 'features/navigation/data/datasources/supabase_navigation_datasource.dart';
import 'features/navigation/data/repositories/navigation_repository_impl.dart';
import 'features/navigation/domain/repositories/navigation_repository.dart';
import 'features/navigation/domain/usecases/find_path_usecase.dart';

// في InitializeService.init() عندما نسجل Supabase client
Future<InitializeService> init() async {
  final supabaseClient = Supabase.instance.client;
  Get.put(supabaseClient);  // ← موجود بالفعل

  // إضافة:
  print('[INIT] Registering Navigation DataSource...');
  Get.put(SupabaseNavigationDataSource(supabaseClient));

  print('[INIT] Registering Navigation Repository...');
  Get.put<NavigationRepository>(
    NavigationRepositoryImpl(Get.find<SupabaseNavigationDataSource>()),
  );

  print('[INIT] Registering FindPathUseCase...');
  Get.put(FindPathUseCase(Get.find<NavigationRepository>()));

  // ... باقي التسجيلات الموجودة
}
```

**النقاط المهمة:**
- `NavigationRepository` type hint (interface، مش impl) لأن FindPathUseCase يحتاج الـ interface
- ترتيب الـ registration يهم: datasource ← repository ← usecase

---

## المرحلة 4 — تعديل BeaconController

### الهدف
بدل جلب البيانات الوهمية من `fetchPoiNodes()` و `fetchLocationInfo()`، يحمّل البيانات الحقيقية من:
```
NavigationRepository repository = Get.find<NavigationRepository>();
BuildingGraph graph = await repository.loadGraph();

// ثم يحوّل النتائج إلى POINode/LocationInfo (نفس الـ API القديمة)
```

### الملفات المتأثرة
```
lib/controllers/beacon_controller.dart
  ├── Remove: fetchPoiNodes() (نسخة وهمية)
  ├── Remove: fetchLocationInfo() (نسخة وهمية)
  └── Add: تحميل من repository
```

### الالتزامات
- **قائمة التوافقية:** المتغيرات `poiList`، `locationList`، `poiNodes` الموجودة يجب أن تبقى بنفس الأسماء والأنواع

---

## المرحلة 5 — تعديل NavigationController (legacy)

### الهدف
الـ `startNavigation()` بدل أن يستخدم خوارزمية A* القديمة، يستخدم `FindPathUseCase`:

```dart
class NavigationController extends GetxController {
  final findPathUseCase = Get.find<FindPathUseCase>();

  void startNavigation(
    List<dynamic> poiNodes,      // لن يُستخدم (سيأتي من repository)
    List<dynamic> poiList,       // لن يُستخدم
    int fromNodeId,              // ✅ سيُستخدم
    int toNodeId,                // ✅ سيُستخدم
  ) async {
    try {
      final path = await findPathUseCase(
        from: fromNodeId,
        to: toNodeId,
        graph: Get.find<NavigationRepository>().cachedGraph!,
      );
      
      pathArray.value = path.steps;
      // ... باقي الكود الموجود
    } catch (e) {
      print('Path not found: $e');
    }
  }
}
```

### المتغيرات الموجودة التي يجب الحفاظ عليها
- `pathArray` (List<int> node IDs)
- `levelNavigation` (LevelNavigation state)
- `directionDegree` (double)
- `pathArrayLength` (String representation)

---

## المرحلة 6 — تعديل NavigationScreenController

### التغيير البسيط
```dart
// القديم:
legacyNav.startNavigation(
  beaconController.poiNodes,    // مش محتاج
  beaconController.poiList,     // مش محتاج
  beaconController.currentLocation.value.nodeID,
  destination.nodeID!,
);

// الجديد:
legacyNav.startNavigation(
  [],                  // dummy (مش محتاج)
  [],                  // dummy (مش محتاج)
  beaconController.currentLocation.value.nodeID,
  destination.nodeID!,
);
```

أو **أفضل:** تعديل signature بتاع `startNavigation()` للعمل بـ nodeIds فقط:

```dart
void startNavigation(int fromNodeId, int toNodeId) async {
  // استخدم من المتغيرات فقط
}
```

---

## المرحلة 7 — مراجعة نهائية

### الفحوصات المطلوبة
- ✅ `flutter analyze` — بدون أخطاء أو تحذيرات
- ✅ `flutter pub get` — جميع الـ imports موجودة
- ✅ تطبيق لا يكسر عند الفتح (حتى لو البيانات فاضية، هيكون graceful)
- ✅ البحث في الوجهات يعمل (SearchBar في UI)
- ✅ زرار "بدء التوجيه" يستدعي A* بدون أخطاء

---

## الخطوات القادمة الفورية

### الأمور التي تحتاج الانتباه

1. **Supabase الداتا** — الجداول الست موجودة لكن **فاضية من الصفوف**
   - قد تحتاج إدخال بيانات مرة واحدة للاختبار
   - أو يمكن الاختبار على بيانات dummy في الـ datasource

2. **Flutter pub get** — تأكد أن جميع الـ packages في pubspec.yaml موجودة:
   - `supabase_flutter` ✅
   - `flutter_dotenv` ✅
   - `get` ✅

3. **الـ .env file** — تأكد أن `SUPABASE_URL` و `SUPABASE_ANON_KEY` موجودة في `.env` قبل التشغيل

4. **Test قبل الالتزام** — كل مرحلة يجب أن تُختبر بـ:
   ```bash
   flutter clean
   flutter pub get
   flutter analyze
   flutter run
   ```

---

## الملاحظات الحرجة

### ✅ ما هو آمن
- Presentation layer (Views/Widgets) — لا تحتاج أي تعديل
- Domain layer (Entities/UseCases) — مستقرة وموثوقة
- Data models — صحيحة وتام اختبارها

### ⚠️ ما يحتاج انتباه
- `BeaconController` — يحمّل البيانات الآن من Supabase (async operation)
  - قد تحتاج loading state إضافي في UI
  - أو caching logic في `NavigationRepositoryImpl`

- `NavigationController.startNavigation()` — الآن async
  - `legacyNav.startNavigation()` قد تصير `await` operation
  - تحتاج handle للـ errors

### 🔴 ما قد يكسر
- أي مكان يستدعي `fetchPoiNodes()` أو `fetchLocationInfo()` مباشرة
  - Search in codebase للتأكد من عدم وجود calls أخرى

---

## Commits المقترحة

```
1. Phase 3: Register navigation repository & usecase in DI
2. Phase 4: BeaconController — load data from NavigationRepository
3. Phase 5: NavigationController — use FindPathUseCase
4. Phase 6: NavigationScreenController — simplify startNavigation call
5. Phase 7: Final review & testing
```

---

## ملاحظات نهائية

**الريفاكتور دا:**
- ✅ يزيل الـ special-case للأسانسير (كل شي edge عادي الآن)
- ✅ يجعل البيانات حقيقية من Supabase (وليست hardcoded)
- ✅ يجعل الـ A* موحّد (يعمل عبر جميع الأدوار مرة واحدة)
- ✅ يسمح بـ future enhancements (أنواع خوارزميات أخرى بدون تعديل الـ UI)
- ✅ يحافظ على backward compatibility مع الـ legacy API (POINode, LocationInfo)

**النتيجة النهائية:** نظام навigaton مرن، موثوق، وسهل الصيانة لسنوات قادمة.
