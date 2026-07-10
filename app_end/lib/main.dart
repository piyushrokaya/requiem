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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final accessibilitySettings = AccessibilitySettings();
  final interactionMode = InteractionModeController();
  // Load persisted preferences before the first frame so returning users
  // don't see defaults flash, and aren't asked to pick a mode again.
  await Future.wait([accessibilitySettings.load(), interactionMode.load()]);

  runApp(
    MyApp(
      accessibilitySettings: accessibilitySettings,
      interactionMode: interactionMode,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.accessibilitySettings,
    required this.interactionMode,
  });

  final AccessibilitySettings accessibilitySettings;
  final InteractionModeController interactionMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _devServerConfiguredThisRun = false;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.accessibilitySettings),
        ChangeNotifierProvider.value(value: widget.interactionMode),
        ChangeNotifierProvider(create: (_) => VoiceAssistantService()),
        Provider(create: (_) => NewsRepository()),
        Provider(create: (_) => CompareRepository()),
      ],
      child: Consumer<AccessibilitySettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Sanksep',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              highContrast: settings.highContrast,
              dyslexiaFriendly: settings.dyslexiaFriendly,
            ),
            darkTheme: buildAppDarkTheme(
              highContrast: settings.highContrast,
              dyslexiaFriendly: settings.dyslexiaFriendly,
            ),
            themeMode: ThemeMode.system,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
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
