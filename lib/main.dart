import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';
import 'core/services/voice_assistant_service.dart';
import 'core/state/accessibility_settings.dart';
import 'core/state/interaction_mode.dart';
import 'features/onboarding/mode_selection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilitySettings()),
        ChangeNotifierProvider(create: (_) => InteractionModeController()),
        ChangeNotifierProvider(create: (_) => VoiceAssistantService()),
      ],
      child: Consumer<AccessibilitySettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Sanksep',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
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
            home: Consumer<InteractionModeController>(
              builder: (context, mode, _) {
                if (!mode.isChosen) return const ModeSelectionPage();
                return const AppShell();
              },
            ),
          );
        },
      ),
    );
  }
}
