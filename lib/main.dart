import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/word_repository.dart';
import 'repositories/deck_repository.dart';
import 'services/learning_queue_service.dart';
import 'services/tts_service.dart';
import 'services/daily_stats_service.dart';
import 'providers/deck_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const ChineseVocabApp());
}

/// Root widget. Wires up the dependency graph (repositories -> services
/// -> providers) once at the top, then hands everything down via
/// `provider`. Nothing below this widget constructs its own repository
/// or service instances for shared state, which keeps a single source
/// of truth for the database connection and session-scoped queue state.
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
            title: 'Học từ vựng tiếng Trung',
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
