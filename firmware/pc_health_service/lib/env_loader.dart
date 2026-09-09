/// تحميل بسيط لملف .env من غير أي package خارجي - مفيش داعي لتعقيد
/// زيادة في CLI بسيط. الصيغة المتوقعة: KEY=VALUE سطر لكل قيمة، والأسطر
/// اللي بتبدأ بـ# بتتجاهل.
library;

import 'dart:io';

Map<String, String> loadEnvFile(String path) {
  final env = <String, String>{};
  final file = File(path);
  if (!file.existsSync()) return env;

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final separatorIndex = line.indexOf('=');
    if (separatorIndex == -1) continue;

    final key = line.substring(0, separatorIndex).trim();
    final value = line.substring(separatorIndex + 1).trim();
    env[key] = value;
  }
  return env;
}
