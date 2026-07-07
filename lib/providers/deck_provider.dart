import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../repositories/deck_repository.dart';
import '../repositories/word_repository.dart';
import '../parser/vocab_parser.dart';

/// Owns the list of decks and which ones are currently "active" (selected
/// for learning). Import logic (txt -> parser -> repository) is exposed
/// here so both the Deck screen and a possible future "open with .txt"
/// flow can reuse it.
class DeckProvider extends ChangeNotifier {
  final DeckRepository deckRepository;
  final WordRepository wordRepository;

  DeckProvider({required this.deckRepository, required this.wordRepository});

  List<Deck> decks = [];
  Set<String> activeDeckIds = {};
  bool isLoading = false;
  String? lastImportMessage;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    decks = await deckRepository.getAllDecks();
    if (activeDeckIds.isEmpty && decks.isNotEmpty) {
      // Default: learn across every deck that currently has words.
      activeDeckIds = decks.map((d) => d.id!).toSet();
    }

    isLoading = false;
    notifyListeners();
  }

  void toggleDeckActive(String deckId, bool active) {
    if (active) {
      activeDeckIds.add(deckId);
    } else {
      activeDeckIds.remove(deckId);
    }
    notifyListeners();
  }

  /// Parses [fileContent] and imports it into the deck named [deckName]
  /// (creating the deck if it doesn't exist yet). Existing words keep
  /// their full SRS history; only genuinely new entries are added.
  Future<int> importTxtIntoDeck({
    required String deckName,
    required String fileContent,
    String? sourceFileName,
  }) async {
    final invalidLines = <int>[];
    final entries = VocabParser.parseFile(
      fileContent,
      onInvalidLine: (lineNumber, raw) => invalidLines.add(lineNumber),
    );

    final deck = await deckRepository.getOrCreateDeck(deckName, sourceFileName: sourceFileName);
    if (sourceFileName != null) {
      await deckRepository.updateSourceFileName(deck.id!, sourceFileName);
    }

    final addedCount = await wordRepository.importEntries(entries, deck.id!);

    lastImportMessage = invalidLines.isEmpty
        ? 'Đã thêm $addedCount từ mới.'
        : 'Đã thêm $addedCount từ mới. Bỏ qua ${invalidLines.length} dòng không đúng định dạng.';

    activeDeckIds.add(deck.id!);
    await load();
    return addedCount;
  }

  Future<void> createEmptyDeck(String name) async {
    await deckRepository.getOrCreateDeck(name);
    await load();
  }

  Future<void> deleteDeck(String deckId) async {
    await deckRepository.deleteDeck(deckId);
    activeDeckIds.remove(deckId);
    await load();
  }

  Future<void> resetProgressForActiveDecks() async {
    await wordRepository.resetProgress(activeDeckIds.toList());
    notifyListeners();
  }

  Future<void> resetAllProgress() async {
    final allIds = decks.map((d) => d.id!).toList();
    await wordRepository.resetProgress(allIds);
    notifyListeners();
  }
}
