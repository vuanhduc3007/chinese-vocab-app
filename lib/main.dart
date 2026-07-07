import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'repositories/word_repository.dart';
import 'repositories/deck_repository.dart';
import 'services/learning_queue_service.dart';
import 'services/tts_service.dart';
import 'services/daily_stats_service.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/deck_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChineseVocabApp());
}

class ChineseVocabApp extends StatelessWidget {
  const ChineseVocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ttsService = TtsService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Học từ vựng tiếng Trung Cloud',
            debugShowCheckedModeBanner: false,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.teal,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.teal,
              brightness: Brightness.dark,
            ),
            home: Consumer<app_auth.AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isAuthenticated) {
                  return _UserAppSession(ttsService: ttsService);
                }
                return const AuthScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

class _UserAppSession extends StatelessWidget {
  final TtsService ttsService;
  const _UserAppSession({required this.ttsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => WordRepository()),
        Provider(create: (_) => DeckRepository()),
        Provider(create: (_) => DailyStatsService()),
        Provider(create: (ctx) => LearningQueueService(wordRepository: ctx.read<WordRepository>())),
        ChangeNotifierProvider(
          create: (ctx) => DeckProvider(
            deckRepository: ctx.read<DeckRepository>(),
            wordRepository: ctx.read<WordRepository>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LearningProvider(
            wordRepository: ctx.read<WordRepository>(),
            queueService: ctx.read<LearningQueueService>(),
            ttsService: ttsService,
            dailyStatsService: ctx.read<DailyStatsService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StatsProvider(
            wordRepository: ctx.read<WordRepository>(),
            dailyStatsService: ctx.read<DailyStatsService>(),
          ),
        ),
      ],
      child: const HomeScreen(),
    );
  }
}
