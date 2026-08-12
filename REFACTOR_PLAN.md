# خطة ريفاكتور Pathfinder — Clean Architecture

> ملف تتبّع حي. آخر تحديث: طبقة الـ Destinations + إصلاحات بيانات الدورين.

---

## الحالة الحالية (ملخّص سريع لو دخلت المحادثة دي تاني)

**الريفاكتور الأساسي (Clean Architecture) خلص بالكامل** من محادثة سابقة:
- Domain layer كامل: `NavNode`, `NavEdge`, `NavLevel`, `BuildingGraph`, `PathStep`, `FindPathUseCase` (A* موحّد عبر كل الأدوار)
- Data layer كامل: `SupabaseNavigationDataSource`, `NavigationRepositoryImpl`
- مسجّلين في `main.dart` (`NavigationRepository`, `FindPathUseCase`)
- `BeaconController` بيحمّل الداتا الحقيقية من الـ repository (مش mock) في `_loadNavigationData()`، وبيحوّلها لـ `POINode`/`LocationInfo` للتوافق مع باقي الكود القديم
- `NavigationScreenController` (الشاشة الرئيسية) بيستخدم `FindPathUseCase`/`NavigationRepository` مباشرة، **مش** بيعتمد على `lib/controllers/navigation_controller.dart` القديم خالص (القديم لسه موجود بس مش بيشتغل في الشاشة الرئيسية)

## الجلسة دي: طبقة الـ Destinations + مراجعة بيانات حقيقية

### المشكلة اللي ظهرت
بعد ما المستخدم حط بيانات حقيقية لدورين (رفع صورة الخريطة)، طلعت مشاكل:
1. **تكرار "سلم"**: نودتين بنفس الاسم في الدور الأول (103 و105) — كان لازم يكونوا سلم واحد بس
2. **السلم مش متسجل كـ vertical connector خالص** — الـ A* ماكانش بيقدر يستخدمه للتنقل بين الأدوار
3. **عقدة واحدة (بيكون واحد) بتمثّل مكانين منطقيين مختلفين** (زي node 108: "حمام رجالي" + "مكتب الأمين العام") — والبحث كان لازم يعرضهم كوجهتين منفصلتين
4. **عكس المشكلة**: عقدتين (106، 107 — مدخلين بيغطوا نفس المدخل الكبير) كانوا بيظهروا مرتين في نتائج البحث بنفس الاسم بالظبط — والمفروض يظهروا مرة واحدة
5. **دروب داون البحث بيعرض عربي دايمًا** حتى لو لغة التطبيق إنجليزي

### الحل: طبقة "Destinations" منفصلة عن العقد الفيزيائية
اتضح إن الافتراض الأساسي (عقدة = وجهة بحث واحدة، علاقة 1:1) غلط. اتعمل فصل حقيقي:
- **node** = نقطة فيزيائية (بيكون BLE + إحداثيات) — تفضل للـ routing/الـ graph
- **destination** = مكان منطقي قابل للبحث — ممكن يرتبط بعقدة أو أكتر (`destination_nodes`)، وعقدة واحدة ممكن تتربط بأكتر من وجهة

**تغييرات الداتا بيز (اتنفذت فعليًا على مشروع `dqnmxlljqiqgqmntzvcx`):**
- حذف node 105 (السلم المكرر) + إعادة ربط edges (104↔106 مباشرة)
- إضافة `vertical_connectors` صف جديد نوعه `stairs` + `connector_stops` لـ (103، L1) و(208، L2)
- **جدول `node_aliases` اتحذف بالكامل** — استُبدل بـ:
  - `destinations` (destination_id, name_ar, name_en)
  - `destination_nodes` (destination_id, node_id) — many-to-many
  - `destination_aliases` (destination_id, alias_text, lang)
- 10 وجهات اتزرعت: 108 اتقسمت لـ "حمام رجالي" + "مكتب الأمين العام" (نفس node_id)، 209 اتقسمت لـ "حمام رجالي" + "قاعة اجتماعات 5"، 206 اتقسمت لـ "قاعة اجتماعات 4" + "حمام نسائي"، 106+107 اتدمجوا في وجهة "مدخل البواب" واحدة (node_ids: [106,107])

**تغييرات الكود:**
- `domain/entities/destination.dart` (جديد) — كيان `Destination` بـ `nodeIds: List<int>` و`aliasesAr`/`aliasesEn`
- `BuildingGraph` بقى فيه `destinations: List<Destination>` بدل `aliasesByNode`/`NodeAlias` (اتشالوا تمامًا)
- `data/models/destination_model.dart` (جديد) + 3 `fetch*` methods جداد في `SupabaseNavigationDataSource`
- `NavigationRepositoryImpl.loadGraph()` بيجيب ويبني الـ destinations دلوقتي بدل node_aliases
- `NavigationScreenController._buildDestinationList()` بيبني القائمة من `graph.destinations` بدل `graph.allNodes`
- `BeaconController._convertGraphToLocationList()` نفس التغيير (للتوافق/الاتساق)
- **إصلاح باگ اللغة**: `search_dropdown_field.dart` كان بيعرض `item.nameAr.tr` دايمًا (النص العربي بس، والـ `.tr` مش بينفع لأسماء ديناميكية جايه من الداتا بيز أصلاً). اتصلح لـ `item.localizedName(isArabic)` + نفس الإصلاح لعنوان التصنيف (`entry.key.localizedLabel(isArabic)` بدل `arabicLabel.tr`)

### ملفات بقت orphaned (يدوي الحذف — الأداة معندهاش صلاحية حذف)
- `lib/features/navigation/domain/entities/node_alias.dart`
- `lib/features/navigation/data/models/node_alias_model.dart`

دول كانوا بيمثلوا `node_aliases` القديم، اللي اتحذف من الداتا بيز واتستبدل بـ `destinations`. الكود بقى مش بيستخدمهم خالص، آمن تمسحهم يدوي وقت ما تفتح المشروع.

---

## حالة التنفيذ (الصورة الكاملة)

- [x] المرحلة 0: مراجعة السكيما + سوبابيز + الكود الحالي
- [x] المرحلة 1: Domain layer
- [x] المرحلة 2: Data layer
- [x] المرحلة 3: تسجيل الـ repository في `main.dart`
- [x] المرحلة 4: `BeaconController` بيحمّل داتا حقيقية
- [x] المرحلة 5-6: `NavigationScreenController` بيستخدم `FindPathUseCase` مباشرة
- [x] **طبقة الـ Destinations** (الجلسة دي) — فصل الوجهات المنطقية عن العقد الفيزيائية
- [x] إصلاح تكرار السلم + إضافته كـ vertical connector
- [x] إصلاح باگ لغة الدروب داون
- [ ] **مراجعة نهائية**: `flutter analyze` / `flutter pub get` لسه ما اتعملوش فعليًا على جهاز المستخدم — لازم يتعملوا يدوي
- [ ] `lib/controllers/navigation_controller.dart` القديم لسه موجود بس مش مستخدم في الشاشة الرئيسية — قرار مستقبلي: نمسحه لو مفيش شاشة تانية (calibration/onboarding) بتعتمد عليه فعليًا

---

## قرارات تصميمية مهمة

1. **heading**: بيتحسب من إحداثيات x,y وقت بناء المسار (`heading_calculator.dart` في domain + نسخة مطابقة جوه `BeaconController._calculateHeading`). المعادلة: `heading = (atan2(dy, -dx) بالدرجات + 360) % 360`.

2. **nearestLift/nextLevelLift**: اتلغوا تمامًا. الاتصال الرأسي (أسانسير/سلم) بقى edge عادي بين أي دورين، والـ A* بيلاقيه تلقائيًا.

3. **POINode.level (int)**: مصدره `levels.level_order` من سوبابيز.

4. **heuristic الـ A***: نفس الدور = مسافة إقليدية عادية. أدوار مختلفة = + penalty ثابت لكل فرق دور (`_levelChangePenalty` في `find_path_usecase.dart`).

5. **تكلفة عبور الاتصال الرأسي**: قيمة تقديرية ثابتة `_verticalTraversalCost = 3.0` متر في `NavigationRepositoryImpl` — قابلة للتعديل.

6. **destinations vs nodes**: القاعدة العامة — أي مكان الناس بيدوروا عليه بالاسم لازم يكون له صف في `destinations`، مش بس في `nodes`. لو أضفت نقطة جديدة في `nodes` من غير ما تضيفها في `destinations` (+ `destination_nodes`)، هي مش هتظهر في نتائج البحث خالص (لكنها هتفضل شغالة في الـ graph نفسه لو حد وصلها كنقطة عبور).

---

## خطوات بعد كده
- `flutter pub get` (لو لسه ما اتعملش بعد إضافة `supabase_flutter`/`flutter_dotenv`)
- `flutter analyze` للتأكد إن مفيش أخطاء كومبايل بعد كل التعديلات دي
- حذف الملفين الـ orphaned يدويًا (`node_alias.dart`, `node_alias_model.dart`)
- اختبار A* فعليًا على الدورين الحقيقيين (تأكيد إن التنقل بالسلم شغال زي الأسانسير)
- استكمال باقي بيانات المبنى (لسه دورين بس من كذا دور)

---

## جلسة إضافية: الاختصارات السريعة (مصاعد/دورات مياه) بقت تشتغل فعليًا

### المشكلة
بعد كل الإصلاحات فوق، سؤال المستخدم كان: ليه لسه لما يدوس على أيقونات الاختصار السريع
(مصاعد/دورات مياه) في `idle_home_screen.dart` بيقوله "غير متاح حاليًا"، رغم إن الداتا
مرفوعة ومربوطة صح دلوقتي؟

السبب: `NavigationDestinationsData.quickShortcuts` كانت 4 كائنات **ثابتة (const)**
بـ `nodeID: null` دايمًا — أصلًا معمولة كـ placeholder لحد ما "تتضاف نقاط حقيقية"،
بس حتى بعد ما اتضافت الداتا، محدش وصّل الاختصارات بيها لأن الربط مش منطقي
يكون 1:1 (فيه أسانسيرين في المبنى دلوقتي مش واحد، وحمامين رجالي مختلفين).

### الحل: الاختصار بيدوّر على "أقرب وجهة حقيقية مطابقة" وقت الضغط
- عمود جديد `destinations.shortcut_type` (`elevator`, `restroom_male`,
  `restroom_female`) — اتحط تلقائيًا على الوجهات الموجودة فعلًا (الأسانسيرين،
  الحمامات الرجالي، الحمام النسائي). `exit`/`cafeteria` لسه من غير أي وجهة
  مطابقة في الداتا، فهيفضلوا يدّوا رسالة "غير متاح" — وده صح، مش باگ، لحد
  ما تتضاف نقاط مخارج/كافيتيريا فعلية.
- `Destination` (domain) و`BuildingDestination` (UI model) بقى فيهم
  `shortcutType` كمان.
- `NavigationScreenController.onShortcutTap`/`selectRestroomVariant` بقوا
  بيعملوا `_resolveNearestReachableDestination(shortcutType)`: بيجيبوا كل
  الوجهات المطابقة للنوع من `graph.destinations`، بيحسبوا طول المسار
  الفعلي لكل واحدة من موقع المستخدم (عن طريق A*)، ويختاروا الأقرب فعليًا
  (مش مجرد أقرب مسافة خط مستقيم). لو ولا وجهة قابلة للوصول، بترجع رسالة
  "غير متاح" بس بمعنى مختلف (مفيش نقطة قابلة للوصول من موقعك، مش إن المكان
  مش موجود خالص).

### ملاحظة مهمة: سؤال "تعذّر إيجاد مسار" في المحادثة
ده كان له سبب منطقي برضه: كان بيحصل قبل ما نصلح تكرار السلم (node 105) —
قبل الإصلاح، لو المستخدم كان واقف على عقدة في نص المسار المكرر، أو حصل أي
انقطاع في الـ graph بسبب التكرار، الـ A* كان ممكن يفشل. بعد إصلاح السلم
(دمج 103/105 + إضافته كـ vertical connector)، الجراف بقى متصل بالكامل بين
كل نقط الدورين، فالمفروض المشكلة دي متحلة تلقائيًا. لو استمرت تظهر، يبقى
محتاجين نتأكد إن `esp32_uuid` اتحط فعليًا للعقد (لسه كله `null` وقت آخر
مراجعة) — لأن من غيره، الموقع الحالي (`haveCurrentLocation`) مش هيتحدد
خالص، والمستخدم هياخد رسالة "لسه بنحدد موقعك" بدل "تعذّر إيجاد مسار".

