import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../parser/vocab_parser.dart';

/// Data-access layer for [Word]s. Handles CRUD plus the specialised
/// queries the learning-queue service needs (due words, new words,
/// random-review candidates, search, favorites, stats aggregates...).
class WordRepository {
  final DatabaseHelper _dbHelper;
  WordRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Word?> _getByHanziPinyinDeck(String hanzi, String pinyin, int deckId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'words',
      where: 'hanzi = ? AND pinyin = ? AND deckId = ?',
      whereArgs: [hanzi, pinyin, deckId],
    );
    if (rows.isEmpty) return null;
    return Word.fromMap(rows.first);
  }

  /// Imports a batch of parsed entries into [deckId]. Words that already
  /// exist (matched by hanzi+pinyin within the same deck) are left
  /// completely untouched so their SRS history is preserved. Only truly
  /// new entries are inserted. Returns how many new words were added.
  Future<int> importEntries(List<ParsedEntry> entries, int deckId) async {
    final db = await _dbHelper.database;
    int addedCount = 0;

    await db.transaction((txn) async {
      for (final entry in entries) {
        final existingRows = await txn.query(
          'words',
          where: 'hanzi = ? AND pinyin = ? AND deckId = ?',
          whereArgs: [entry.hanzi, entry.pinyin, deckId],
        );
        if (existingRows.isNotEmpty) continue; // keep old SRS history intact

        final word = Word(
          hanzi: entry.hanzi,
          pinyin: entry.pinyin,
          meaning: entry.meaning,
          partOfSpeech: entry.partOfSpeech,
          deckId: deckId,
        );
        await txn.insert('words', word.toMap()..remove('id'));
        addedCount++;
      }
    });

    return addedCount;
  }

  Future<int> insertWord(Word word) async {
    final db = await _dbHelper.database;
    return db.insert('words', word.toMap()..remove('id'));
  }

  Future<void> updateWord(Word word) async {
    final db = await _dbHelper.database;
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deleteWord(int id) async {
    final db = await _dbHelper.database;
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Word>> getAllWords({List<int>? deckIds}) async {
    final db = await _dbHelper.database;
    if (deckIds == null || deckIds.isEmpty) {
      final rows = await db.query('words');
      return rows.map(Word.fromMap).toList();
    }
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query('words', where: 'deckId IN ($placeholders)', whereArgs: deckIds);
    return rows.map(Word.fromMap).toList();
  }

  /// Words whose `nextReview` has already passed (SM-2 "due" queue).
  Future<List<Word>> getDueWords(List<int> deckIds, DateTime now) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: 'deckId IN ($placeholders) AND reviewCount > 0 AND (nextReview IS NULL OR nextReview <= ?)',
      whereArgs: [...deckIds, now.toIso8601String()],
      orderBy: 'nextReview ASC',
    );
    return rows.map(Word.fromMap).toList();
  }

  /// Words that have never been reviewed at all yet.
  Future<List<Word>> getNewWords(List<int> deckIds, {int? limit}) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: 'deckId IN ($placeholders) AND reviewCount = 0',
      whereArgs: deckIds,
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(Word.fromMap).toList();
  }

  /// Every word that has been reviewed at least once - the pool that
  /// Random Review draws from once due+new words run out.
  Future<List<Word>> getLearnedWords(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: 'deckId IN ($placeholders) AND reviewCount > 0',
      whereArgs: deckIds,
    );
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> searchWords(String query, {List<int>? deckIds}) async {
    final db = await _dbHelper.database;
    final like = '%$query%';
    if (deckIds == null || deckIds.isEmpty) {
      final rows = await db.query(
        'words',
        where: 'hanzi LIKE ? OR pinyin LIKE ? OR meaning LIKE ?',
        whereArgs: [like, like, like],
      );
      return rows.map(Word.fromMap).toList();
    }
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: '(hanzi LIKE ? OR pinyin LIKE ? OR meaning LIKE ?) AND deckId IN ($placeholders)',
      whereArgs: [like, like, like, ...deckIds],
    );
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> getFavorites({List<int>? deckIds}) async {
    final db = await _dbHelper.database;
    if (deckIds == null || deckIds.isEmpty) {
      final rows = await db.query('words', where: 'isFavorite = 1');
      return rows.map(Word.fromMap).toList();
    }
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: 'isFavorite = 1 AND deckId IN ($placeholders)',
      whereArgs: deckIds,
    );
    return rows.map(Word.fromMap).toList();
  }

  Future<void> toggleFavorite(int wordId, bool value) async {
    final db = await _dbHelper.database;
    await db.update('words', {'isFavorite': value ? 1 : 0}, where: 'id = ?', whereArgs: [wordId]);
  }

  // ---------------- Stats helpers ----------------

  Future<int> countTotal(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final res = await db.rawQuery('SELECT COUNT(*) c FROM words WHERE deckId IN ($placeholders)', deckIds);
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> countLearned(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final res = await db.rawQuery(
      'SELECT COUNT(*) c FROM words WHERE deckId IN ($placeholders) AND reviewCount > 0',
      deckIds,
    );
    return (res.first['c'] as int?) ?? 0;
  }

  /// A word counts as "mastered/thuoc" once it has a comfortable ease
  /// factor and a run of consecutive correct answers.
  Future<int> countMastered(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final res = await db.rawQuery(
      'SELECT COUNT(*) c FROM words WHERE deckId IN ($placeholders) AND correctStreak >= 3 AND interval >= 21',
      deckIds,
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> countDueOn(List<int> deckIds, DateTime day) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final startOfDay = DateTime(day.year, day.month, day.day).toIso8601String();
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
    final res = await db.rawQuery(
      'SELECT COUNT(*) c FROM words WHERE deckId IN ($placeholders) AND reviewCount > 0 AND nextReview BETWEEN ? AND ?',
      [...deckIds, startOfDay, endOfDay],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> sumReviewCount(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(reviewCount),0) c FROM words WHERE deckId IN ($placeholders)',
      deckIds,
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> sumCorrectCount(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(correctCount),0) c FROM words WHERE deckId IN ($placeholders)',
      deckIds,
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<void> deleteAllForDecks(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    await db.delete('words', where: 'deckId IN ($placeholders)', whereArgs: deckIds);
  }

  /// Resets all SRS progress fields for the given decks back to their
  /// initial state, without deleting the words themselves.
  Future<void> resetProgress(List<int> deckIds) async {
    final db = await _dbHelper.database;
    final placeholders = List.filled(deckIds.length, '?').join(',');
    await db.update(
      'words',
      {
        'correctCount': 0,
        'wrongCount': 0,
        'reviewCount': 0,
        'correctStreak': 0,
        'easeFactor': 2.5,
        'interval': 0,
        'repetition': 0,
        'lastReview': null,
        'nextReview': null,
        'lastShown': null,
      },
      where: 'deckId IN ($placeholders)',
      whereArgs: deckIds,
    );
  }
}
