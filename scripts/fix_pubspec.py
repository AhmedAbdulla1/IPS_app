path = r"D:\IPS_app\ips_tester\pubspec.yaml"
content = """name: ips_tester
description: "A new Flutter project."
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  flutter_reactive_ble: ^5.4.0
  supabase_flutter: ^2.8.0
  permission_handler: ^13.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

dependency_overrides:
  permission_handler_android: 14.0.0

flutter:
  uses-material-design: true
"""

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Clean pubspec.yaml written successfully.")
