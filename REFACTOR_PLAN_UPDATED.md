# خطة ريفاكتور Pathfinder — Clean Architecture

> ملف تتبّع حي. بيتحدّث أول ما أي مرحلة تخلص أو لو الكوته هتخلص عشان محدش يضيع تقدمه.
> **آخر تحديث:** المرحلة 2 اكتملت (Data Layer) — جاهز للمرحلة 3  
> 📄 **انظر `NAVIGATION_REFACTOR_STATUS.md` للتقرير الشامل والخطوات المقادمة المحددة بدقة**

---

## السياق

كان فيه خوارزمية A* شغالة في `lib/controllers/navigation_controller.dart` بس بتعتمد على:
- داتا وهمية مكتوبة يدوي (`fetchPoiNodes`/`fetchLocationInfo` في `beacon_controller.dart`)
- حقلين `nearestLift`/`nextLevelLift` على كل `POINode` بيتحطوا يدوي، والخوارزمية بتعمل "قفزة" خاصة بينهم بدل ما تعتبرهم جزء طبيعي من الـ graph
- ملاحظة مهمة اتكتشفت أثناء المراجعة: الداتا الوهمية نفسها كانت أصلاً بتمثّل الاتصال الرأسي (أسانسير/سلم) كـ edge عادي جوه `neighbourArray` (زي `NeighbourNode(nodeID: 10, levelNavigation: go_down)`) — يعني التمثيل الصح كان موجود جزئيًا، بس القفزة الخاصة بـ nearestLift كانت زيادة ومكررة.

**القرار:** إلغاء الـ special-case بالكامل. الأسانسير/السلم بقى مجرد edge عادي في الـ graph الموحّد (كل الأدوار مع بعض)، والداتا بتيجي من سوبابيز مش متكتوبة يدوي.

## الـ Architecture الجديد

```
lib/features/navigation/
├── domain/                          [Dart نقي — بدون Flutter/Supabase/GetX]
│   ├── entities/
│   │   ├── nav_node.dart            → NavNode (id, levelId, nameAr, nameEn, type, esp32Uuid, x, y)
│   │   ├── nav_edge.dart            → NavEdge (fromId, toId, distanceMeters, kind: walk|elevator|stairs, direction)
│   │   ├── nav_level.dart           → NavLevel (id, nameAr, nameEn, order)
│   │   ├── node_alias.dart          → NodeAlias (nodeId, text, lang)
│   │   ├── path_step.dart           → PathStep (مخرج A* — نقطة واحدة في المسار)
│   │   └── building_graph.dart      → BuildingGraph (nodes, levels, adjacency, aliases) + helpers
│   ├── repositories/
│   │   └── navigation_repository.dart   → abstract: loadGraph(), get cachedGraph
│   └── usecases/
│       ├── find_path_usecase.dart   → A* الموحّد الجديد (بيشتغل عبر كل الأدوار مرة واحدة)
│       ├── heading_calculator.dart  → حساب الاتجاه (heading) من إحداثيات x,y
│       └── path_not_found_exception.dart
├── data/
│   ├── models/                      → NodeModel, EdgeModel, LevelModel, ... (fromMap + toEntity)
│   ├── datasources/
│   │   └── supabase_navigation_datasource.dart
│   └── repositories/
│       └── navigation_repository_impl.dart   → بيبني الـ graph (edges + connector_stops كـ edges بين الأدوار)
└── (presentation موجودة بالفعل: controllers/views/widgets — هتتلمس بأقل قدر ممكن)
```

### قرار التوافق مع الكود الحالي
`NavigationScreenController` (الطبقة اللي الـ UI شغال عليها فعليًا: `idle_home_screen`, `active_navigation_screen`) **مش هتتغيّر خالص**. بدل كده:
- `BeaconController` هيجيب الداتا الحقيقية من الـ repository بدل الداتا الوهمية، وهيفضل يعرض نفس الـ `POINode`/`LocationInfo` API القديمة (نفس الأسماء والأنواع) عشان أي حاجة تانية بتعتمد عليه متتكسرش.
- `lib/controllers/navigation_controller.dart` (القديم) هيفضل بنفس الـ public API (`startNavigation`, `pathArray`, `levelNavigation`, `directionDegree`, ...) بس **جواه** هيستخدم `FindPathUseCase` الجديد بدل الخوارزمية القديمة. هيتحول لـ "adapter" بسيط.

---

## حالة التنفيذ

- [x] **المرحلة 0**: مراجعة السكيما + سوبابيز + الكود الحالي (خلصت في المحادثة السابقة)
- [x] **المرحلة 1**: Domain layer (entities + repository interface + usecases)
      - `nav_node.dart`, `nav_edge.dart`, `nav_level.dart`, `node_alias.dart`, `building_graph.dart`
      - `path_step.dart`, `navigation_repository.dart` (interface)
      - `heading_calculator.dart`, `path_not_found_exception.dart`, `find_path_usecase.dart` (A* الموحّد)
- [x] **المرحلة 2**: Data layer (models + datasource + repository impl) — **✅ اكتملت كاملة**
      - Models: `node_model.dart`, `level_model.dart`, `edge_model.dart`, `node_alias_model.dart`, `vertical_connector_model.dart` (+ `ConnectorStopModel`)
      - Datasource: `supabase_navigation_datasource.dart` (جميع 6 fetch methods)
      - Repository impl: `navigation_repository_impl.dart` (graph building + connector stops handling)
- [ ] **المرحلة 3**: تسجيل الـ repository في `main.dart` (DI عبر GetX) — ← **الخطوة التالية مباشرة**
- [ ] **المرحلة 4**: تعديل `BeaconController` — يحمّل الداتا الحقيقية بدل `fetchPoiNodes`/`fetchLocationInfo`
- [ ] **المرحلة 5**: تعديل `lib/controllers/navigation_controller.dart` — يستخدم `FindPathUseCase` بدل الخوارزمية القديمة
- [ ] **المرحلة 6**: تعديل نداء `startNavigation` في `NavigationScreenController` (هيبقى مش محتاج يبعت hashMap/priorityQueue)
- [ ] **المرحلة 7**: مراجعة نهائية — `flutter analyze` / التأكد من عدم كسر أي ملف بيستخدم `POINode`

---

## قرارات تصميمية مهمة (لو الكوته خلصت، دي أهم حاجة ترجعلها)

1. **heading**: بيتحسب من إحداثيات x,y وقت بناء المسار، مش مخزّن في الداتا بيز. المعادلة اتستنتجت من الداتا الوهمية القديمة:
   `heading = (atan2(dy, -dx) بالدرجات + 360) % 360` حيث `dx = xB - xA`, `dy = yB - yA`. (تم التحقق منها على 4 أمثلة من الداتا القديمة).

2. **nearestLift/nextLevelLift**: اتلغوا تمامًا كحقول. الاتصال الرأسي بقى edge عادي في الـ graph الموحّد (نوعه `elevator` أو `stairs`، واتجاهه `up`/`down`)، والـ A* الجديد بيلاقي المسار عبره تلقائيًا زي أي edge تاني.

3. **POINode.level (int)**: اتسابت زي ما هي (int) للتوافق مع باقي الكود، لكن مصدرها بقى `levels.level_order` من سوبابيز (مش نص levelId زي 'GF'/'F1' مباشرة). التحويل بيحصل في `BeaconController`/الـ mapper.

4. **الـ heuristic في الـ A***: لو النودتين في نفس الدور، بتستخدم المسافة الإقليدية العادية زي الأول. لو في أدوار مختلفة، بيتضاف penalty ثابت لكل فرق دور (`levelOrder` diff × قيمة تقريبية) عشان الـ heuristic يفضل معقول من غير ما يبقى مضلل. القيمة دي `_levelChangePenalty` في `find_path_usecase.dart` — قابلة للتعديل لاحقًا لو المسارات طلعت غريبة.

5. **الداتا لسه فاضية في سوبابيز** (الجداول اتعملت بس من غير صفوف — راجع محادثة سابقة). يعني بعد الريفاكتور، التطبيق هيشتغل لكن `poiList`/`locationList` هيكونوا فاضيين لحد ما تتحط الداتا الحقيقية. ده متوقع ومش خطأ.

---

## خطوات بعد الريفاكتور (مش دلوقتي)
- إدخال بيانات دور GF الحقيقية في سوبابيز (كانت جاهزة في `map_data_template.json`)
- اختبار A* على بيانات حقيقية بعد الإدخال
- التأكد من `flutter pub get` اتعمل بعد إضافة `supabase_flutter`/`flutter_dotenv`
