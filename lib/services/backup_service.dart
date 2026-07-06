import 'dart:convert';
import '../models/word.dart';
import '../models/deck.dart';
import '../repositories/word_repository.dart';
import '../repositories/deck_repository.dart';
import 'backup_service_io.dart' if (dart.library.html) 'backup_service_web.dart' as platform;

class BackupService {
  final WordRepository wordRepository;
  final DeckRepository deckRepository;

  BackupService({required this.wordRepository, required this.deckRepository});

  Future<String> exportProgress() async {
    final decks = await deckRepository.getAllDecks();
    final words = await wordRepository.getAllWords();

    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'formatVersion': 1,
      'decks': decks.map((d) => d.toMap()).toList(),
      'words': words.map((w) => w.toMap()).toList(),
    };

    return platform.exportProgressFile(payload);
  }

  Future<int> importProgressFromJson(String jsonContent) async {
    final Map<String, dynamic> payload = jsonDecode(jsonContent) as Map<String, dynamic>;

    final deckMaps = (payload['decks'] as List).cast<Map<String, dynamic>>();
    final wordMaps = (payload['words'] as List).cast<Map<String, dynamic>>();

    final deckIdRemap = <int, int>{};
    for (final dMap in deckMaps) {
      final deck = Deck.fromMap(dMap);
      final resolved = await deckRepository.getOrCreateDeck(deck.name);
      if (deck.id != null && resolved.id != null) {
        deckIdRemap[deck.id!] = resolved.id!;
      }
    }

    int importedCount = 0;
    for (final wMap in wordMaps) {
      final imported = Word.fromMap(wMap);
      final newDeckId = deckIdRemap[imported.deckId];
      if (newDeckId == null) continue;

      final existing = await wordRepository.searchWords(imported.hanzi, deckIds: [newDeckId]);
      final match = existing.where((w) => w.hanzi == imported.hanzi && w.pinyin == imported.pinyin).toList();

      if (match.isEmpty) {
        await wordRepository.insertWord(imported.copyWith(deckId: newDeckId));
        importedCount++;
      } else if (imported.reviewCount > match.first.reviewCount) {
        await wordRepository.updateWord(imported.copyWith(id: match.first.id, deckId: newDeckId));
        importedCount++;
      }
    }

    return importedCount;
  }

  Future<String> backupDatabaseFile() async {
    return platform.backupDatabaseFileIo();
  }
}
