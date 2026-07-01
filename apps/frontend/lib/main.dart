import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_localizations.dart';
import 'app/app_settings_controller.dart';
import 'app/app_settings_scope.dart';
import 'app/app_theme.dart';
import 'screens/onboarding/onboarding_screen_1.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = AppSettingsController();
  await settingsController.load();

  runApp(
    AppSettingsScope(
      controller: settingsController,
      child: const SmartOutfitApp(),
    ),
  );
}

class SmartOutfitApp extends StatelessWidget {
  const SmartOutfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final settings = AppSettingsScope.of(context);
        final appTitle = AppLocalizations(settings.locale).t('appTitle');

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: appTitle,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const OnboardingScreen1(),
        );
      },
    );
  }
}
