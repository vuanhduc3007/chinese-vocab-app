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
    final wordRepository = WordRepository();
    final deckRepository = DeckRepository();
    final dailyStatsService = DailyStatsService();
    final ttsService = TtsService();
    final queueService = LearningQueueService(wordRepository: wordRepository);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        Provider<WordRepository>.value(value: wordRepository),
        Provider<DeckRepository>.value(value: deckRepository),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DeckProvider(deckRepository: deckRepository, wordRepository: wordRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => LearningProvider(
            wordRepository: wordRepository,
            queueService: queueService,
            ttsService: ttsService,
            dailyStatsService: dailyStatsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StatsProvider(wordRepository: wordRepository, dailyStatsService: dailyStatsService),
        ),
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
                  // Lên lịch load dữ liệu khi user login thành công
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      context.read<DeckProvider>().load();
                    }
                  });
                  return const HomeScreen();
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
