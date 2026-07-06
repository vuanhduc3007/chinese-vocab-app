import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/deck.dart';

/// Data-access layer for [Deck]s. Nothing above this layer (providers,
/// UI) ever touches SQL directly.
class DeckRepository {
  final DatabaseHelper _dbHelper;
  DeckRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Deck>> getAllDecks() async {
    final db = await _dbHelper.database;
    final rows = await db.query('decks', orderBy: 'id ASC');
    return rows.map(Deck.fromMap).toList();
  }

  Future<Deck?> getDeckByName(String name) async {
    final db = await _dbHelper.database;
    final rows = await db.query('decks', where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  Future<Deck?> getDeckById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('decks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  /// Creates the deck if it doesn't exist yet; otherwise returns the
  /// existing one. Deck names act as the natural unique key.
  Future<Deck> getOrCreateDeck(String name, {String? sourceFileName}) async {
    final existing = await getDeckByName(name);
    if (existing != null) return existing;

    final db = await _dbHelper.database;
    final id = await db.insert('decks', {
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'sourceFileName': sourceFileName,
    });
    return Deck(id: id, name: name, sourceFileName: sourceFileName);
  }

  Future<void> updateSourceFileName(int deckId, String fileName) async {
    final db = await _dbHelper.database;
    await db.update('decks', {'sourceFileName': fileName}, where: 'id = ?', whereArgs: [deckId]);
  }

  Future<void> deleteDeck(int deckId) async {
    final db = await _dbHelper.database;
    await db.delete('words', where: 'deckId = ?', whereArgs: [deckId]);
    await db.delete('decks', where: 'id = ?', whereArgs: [deckId]);
  }

  Future<int> wordCountForDeck(int deckId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE deckId = ?',
      [deckId],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
