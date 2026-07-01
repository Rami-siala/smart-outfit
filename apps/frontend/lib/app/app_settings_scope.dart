import 'package:flutter/material.dart';

import 'app_settings_controller.dart';

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required super.child,
    required AppSettingsController controller,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found in context');
    return scope!.notifier!;
  }
}
