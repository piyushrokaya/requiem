import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';
import 'core/services/compare_repository.dart';
import 'core/services/news_repository.dart';
import 'core/services/voice_assistant_service.dart';
import 'core/state/accessibility_settings.dart';
import 'core/state/interaction_mode.dart';
import 'features/onboarding/dev_server_setup_page.dart';
import 'features/onboarding/mode_selection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _devServerConfiguredThisRun = false;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilitySettings()),
        ChangeNotifierProvider(create: (_) => InteractionModeController()),
        ChangeNotifierProvider(create: (_) => VoiceAssistantService()),
        Provider(create: (_) => NewsRepository()),
        Provider(create: (_) => CompareRepository()),
      ],
      child: Consumer<AccessibilitySettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Sanksep',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            darkTheme: buildAppDarkTheme(),
            themeMode: ThemeMode.system,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final scaler = settings.largeText
                  ? const TextScaler.linear(1.25)
                  : const TextScaler.linear(1.0);
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: scaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _devServerConfiguredThisRun
                ? Consumer<InteractionModeController>(
                    builder: (context, mode, _) {
                      if (!mode.isChosen) return const ModeSelectionPage();
                      return const AppShell();
                    },
                  )
                : DevServerSetupPage(
                    onConfigured: () {
                      setState(() => _devServerConfiguredThisRun = true);
                    },
                  ),
          );
        },
      ),
    );
  }
}
