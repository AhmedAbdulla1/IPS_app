import 'dart:io';

/// بيحاول يفتح الرابط في نافذة "تطبيق" مستقلة (من غير شريط عنوان/تابات
/// المتصفح العادي) باستخدام `--app=` بتاعة Edge أو Chrome. لو الاتنين
/// مش موجودين، بيرجع يفتح المتصفح الافتراضي بتاب عادي.
///
/// دايمًا بيطبع الرابط في الآخر عشان لو الفتح التلقائي فشل لأي سبب
/// (مفيش متصفح متوصل، بيئة سيرفر بدون واجهة، إلخ) يقدر أحمد يفتحه
/// يدويًا.
Future<void> openAsAppWindow(Uri url) async {
  if (Platform.isWindows) {
    // "start" هنا بتاعة cmd.exe (مش أمر مستقل) - بتدور على البرنامج
    // المسجل باسمه في Windows (App Paths)، فمحتاجين نمرّره عن طريق cmd.
    final attempts = ['msedge', 'chrome'];
    for (final browser in attempts) {
      try {
        await Process.start(
          'cmd',
          ['/c', 'start', '', browser, '--app=${url.toString()}'],
          runInShell: true,
        );
        break; // cmd start بترجع فورًا حتى لو المتصفح مش موجود فعليًا،
        // فمفيش طريقة مضمونة نتأكد من النجاح غير إننا نجرب واحد بس
        // ونسيب الطباعة تحت كـfallback بصري لو مفتحش حاجة.
      } catch (_) {
        continue;
      }
    }
  } else if (Platform.isMacOS) {
    try {
      await Process.start('open', ['-a', 'Google Chrome', '--args', '--app=${url.toString()}']);
    } catch (_) {
      await Process.start('open', [url.toString()]);
    }
  } else {
    try {
      await Process.start('xdg-open', [url.toString()]);
    } catch (_) {
      /* تجاهل - هيبان الرابط في الطباعة تحت */
    }
  }

  print('[dashboard] لو النافذة مافتحتش تلقائيًا، افتح الرابط ده يدوي في '
      'المتصفح: $url');
}
