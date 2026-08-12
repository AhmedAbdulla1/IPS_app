import 'package:get/get.dart';

/// جدول ترجمة التطبيق (عربي هو الأساسي/الافتراضي، فمفيش داعي لخريطة ar_EG —
/// أي نص عربي مكتوب في الكود هو نفسه الـ "key"، ولو مفيش ترجمة له في اللغة
/// الحالية، GetX بيرجع الـ key الأصلي زي ما هو).
///
/// عشان تضيف نص جديد قابل للترجمة:
/// 1) استخدم `'النص العربي'.tr` في الويدجت بدل ما تكتبه مباشر
/// 2) ضيف سطر هنا في en_US: 'النص العربي': 'English text'
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          // ---- App bar / شعار ----
          'مجلس النواب المصري': 'Egyptian Parliament',

          // ---- شريط البحث ----
          'ابحث عن مكتب أو قاعة...': 'Search for an office or hall...',
          'مفيش نتائج مطابقة': 'No matching results',

          // ---- تصنيفات الوجهات ----
          'القاعات': 'Halls',
          'المكاتب': 'Offices',
          'الخدمات': 'Services',
          'المرافق': 'Facilities',

          // ---- المرافق السريعة ----
          'دورات مياه': 'Restrooms',
          'مصاعد': 'Elevators',
          'مخارج': 'Exits',
          'كافيتيريا': 'Cafeteria',

          // ---- القاعات ----
          'قاعة المناقشات الرئيسية': 'Main Discussion Hall',
          'قاعة الجلسات العامة': 'General Sessions Hall',
          'قاعة اللجنة التشريعية': 'Legislative Committee Hall',

          // ---- المكاتب ----
          'مكتب رئيس المجلس': "Speaker's Office",
          'مكتب الأمانة العامة': 'General Secretariat Office',
          'مكتب العلاقات العامة': 'Public Relations Office',

          // ---- الخدمات ----
          'المكتبة': 'Library',
          'مكتب الاستعلامات': 'Information Desk',

          // ---- حالة الموقع الحالي ----
          'أنت الآن بالقرب من': 'You are currently at',
          'تم تحديد الموقع': 'Location determined',
          'جارِ تحديد الموقع...': 'Determining location...',
          'البهو الرئيسي': 'Main Lobby',

          // ---- الدور ----
          'الدور @n': 'Floor @n',

          // ---- زرار البدء ----
          'بدء التوجيه': 'Start Navigation',

          // ---- شاشة التوجيه النشط ----
          'إلى': 'To',
          'انعطف يمين': 'Turn right',
          'انعطف يسار': 'Turn left',
          'استمر دغري': 'Continue straight',
          'استمر مستقيم': 'Continue straight',
          'استدر للخلف': 'Turn back',
          'ارجع للخلف': 'Turn back',
          'استمر في هذا الاتجاه': 'Continue in this direction',
          'أنت على الطريق الصحيح': "You're on the right path",
          'حاول ترجع للمسار': 'Try to get back on route',
          'المسافة المتبقية': 'Remaining distance',
          'الدور القادم': 'Next floor',
          'إلغاء': 'Cancel navigation',
          'اصعد للدور التالي': 'Go up to the next floor',
          'خُد المصعد أو السلم لأعلى': 'Take the elevator or stairs up',
          'انزل للدور التالي': 'Go down to the next floor',
          'خُد المصعد أو السلم لأسفل': 'Take the elevator or stairs down',
          'لقد وصلت إلى وجهتك': "You've reached your destination",
          'يمكنك إلغاء الملاحة الآن': 'You can cancel navigation now',
          'جارِ تحديد المسار...': 'Calculating route...',
          'حافظ على تفعيل البلوتوث والموقع': 'Keep Bluetooth and location on',
          'جارِ تحديد موقعك...': 'Locating you...',
          'وصلت': 'Arrived',
          '@n خطوة متبقية': '@n steps remaining',
          'غير متاح حاليًا': 'Not available yet',
          'لسه بنحدد موقعك': 'Still locating you',
          'وجهة "@name" لسه مفيش لها نقطة في خريطة المبنى.':
              'The destination "@name" doesn\'t have a mapped point in the building yet.',
          'استنى لحظة لحد ما نلاقي أقرب نقطة ليك وحاول تاني.':
              'Please wait a moment while we find the nearest point to you, then try again.',

          // ---- بوب دورات المياه ----
          'اختر النوع': 'Choose type',
          'رجالي': "Men's",
          'حريمي': "Women's",
          'دورات مياه (رجالي)': "Men's Restroom",
          'دورات مياه (حريمي)': "Women's Restroom",

          // ---- الإعدادات ----
          'الإعدادات': 'Settings',
          'اللغة': 'Language',
          'العربية': 'Arabic',
          'الإنجليزية': 'English',
          'الوضع الليلي': 'Dark Mode',
          'تفعيل المظهر الداكن': 'Enable dark appearance',
          'إعداد البوصلة': 'Compass Calibration',
          'معايرة اتجاه البوصلة': 'Calibrate compass direction',

          // ---- صفحة الأذونات ----
          'السماح مطلوب': 'Permission Required',
          'يبدو أنك لم تسمح للتطبيق بالوصول المطلوب. لتتمكن من استخدام التوجيه داخل المبنى، يرجى تفعيل الصلاحية من إعدادات التطبيق.':
              "It looks like you didn't allow the required permission. Please enable it from the app settings to continue.",
          'فتح الإعدادات': 'Open Settings',
          'حاول مرة أخرى': 'Try Again',

          'البلوتوث متوقف': 'Bluetooth is Off',
          'قم بتشغيل البلوتوث للبحث عن إشارات التوجيه داخل المبنى.':
              'Turn on Bluetooth to search for indoor guidance signals.',
          'تشغيل البلوتوث': 'Turn On Bluetooth',

          'هناك أذونات مطلوبة': 'Permissions Required',
          'للاستمرار في استخدام التوجيه داخل المبني، يرجى تفعيل الأذونات التالية.':
              'To continue using indoor guidance, please enable the following permissions.',
          'البلوتوث': 'Bluetooth',
          'مفعّل': 'On',
          'متوقف': 'Off',
          'تشغيل': 'Turn On',
          'الموقع': 'Location',
          'غير مفعّلة': 'Not Enabled',

          'كل شيء جاهز': 'All Set',
          'تم تفعيل جميع الأذونات المطلوبة. يمكنك الآن استخدام التوجيه داخل المبنى.':
              'All required permissions are enabled. You can now use indoor guidance.',
          'ابدأ التوجيه': 'Start Navigation',

          'يرجى تفعيل الأذونات أعلاه.': 'Please allow the permissions above.',
        },
      };
}
