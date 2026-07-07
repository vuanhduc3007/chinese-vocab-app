import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../parser/vocab_parser.dart';

class WordRepository {
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  CollectionReference get _wordsRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('words');

  Future<Word?> _getByHanziPinyinDeck(String hanzi, String pinyin, String deckId) async {
    final snapshot = await _wordsRef
        .where('hanzi', isEqualTo: hanzi)
        .where('pinyin', isEqualTo: pinyin)
        .where('deckId', isEqualTo: deckId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Word.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
  }

  Future<int> importEntries(List<ParsedEntry> entries, String deckId) async {
    if (entries.isEmpty) return 0;
    
    // 1. Fetch all existing words for this deck to check for duplicates quickly
    final snapshot = await _wordsRef.where('deckId', isEqualTo: deckId).get();
    final existingWords = snapshot.docs.map((doc) => Word.fromMap(doc.data() as Map<String, dynamic>, doc.id));
    final existingSet = existingWords.map((w) => '${w.hanzi}|${w.pinyin}').toSet();

    // 2. Filter new entries
    final newEntries = entries.where((e) => !existingSet.contains('${e.hanzi}|${e.pinyin}')).toList();
    if (newEntries.isEmpty) return 0;

    int addedCount = 0;
    final db = FirebaseFirestore.instance;

    // 3. Batch insert (Firestore limit is 500 per batch)
    for (var chunk in _chunkList(newEntries, 450)) {
      final batch = db.batch();
      for (final entry in chunk) {
        final docRef = _wordsRef.doc();
        final word = Word(
          id: docRef.id,
          hanzi: entry.hanzi,
          pinyin: entry.pinyin,
          meaning: entry.meaning,
          partOfSpeech: entry.partOfSpeech,
          deckId: deckId,
        );
        batch.set(docRef, word.toMap());
        addedCount++;
      }
      await batch.commit();
    }

    return addedCount;
  }

  Future<void> insertWord(Word word) async {
    final docRef = _wordsRef.doc();
    await docRef.set(word.toMap());
  }

  Future<void> updateWord(Word word) async {
    if (word.id == null) return;
    await _wordsRef.doc(word.id).update(word.toMap());
  }

  Future<void> deleteWord(String id) async {
    await _wordsRef.doc(id).delete();
  }

  Future<List<Word>> getAllWords({List<String>? deckIds}) async {
    if (deckIds == null || deckIds.isEmpty) {
      final snapshot = await _wordsRef.get();
      return snapshot.docs.map((doc) => Word.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    }
    
    List<Word> allWords = [];
    for (var chunk in _chunkList(deckIds, 10)) {
      final snapshot = await _wordsRef.where('deckId', whereIn: chunk).get();
      allWords.addAll(snapshot.docs.map((doc) => Word.fromMap(doc.data() as Map<String, dynamic>, doc.id)));
    }
    return allWords;
  }

  Future<List<Word>> getDueWords(List<String> deckIds, DateTime now) async {
    if (deckIds.isEmpty) return [];
    final allWords = await getAllWords(deckIds: deckIds);
    final results = allWords.where((w) => 
      w.reviewCount > 0 && 
      (w.nextReview == null || w.nextReview!.isBefore(now) || w.nextReview!.isAtSameMomentAs(now))
    ).toList();
    
    results.sort((a, b) {
      if (a.nextReview == null && b.nextReview == null) return 0;
      if (a.nextReview == null) return -1;
      if (b.nextReview == null) return 1;
      return a.nextReview!.compareTo(b.nextReview!);
    });
    return results;
  }

  Future<List<Word>> getNewWords(List<String> deckIds, {int? limit}) async {
    if (deckIds.isEmpty) return [];
    final allWords = await getAllWords(deckIds: deckIds);
    final results = allWords.where((w) => w.reviewCount == 0).toList();
    
    results.sort((a, b) => a.createdDate.compareTo(b.createdDate));
    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  Future<List<Word>> getLearnedWords(List<String> deckIds) async {
    if (deckIds.isEmpty) return [];
    final allWords = await getAllWords(deckIds: deckIds);
    return allWords.where((w) => w.reviewCount > 0).toList();
  }

  Future<List<Word>> searchWords(String query, {List<String>? deckIds}) async {
    // Firestore doesn't support generic substring search like "LIKE %query%".
    // For a simple app, we can fetch all words in the decks and filter in memory.
    final allWords = await getAllWords(deckIds: deckIds);
    final q = query.toLowerCase();
    return allWords.where((w) => 
      w.hanzi.toLowerCase().contains(q) || 
      w.pinyin.toLowerCase().contains(q) || 
      w.meaning.toLowerCase().contains(q)
    ).toList();
  }

  Future<List<Word>> getFavorites({List<String>? deckIds}) async {
    final allWords = await getAllWords(deckIds: deckIds);
    return allWords.where((w) => w.isFavorite).toList();
  }

  Future<void> toggleFavorite(String wordId, bool value) async {
    await _wordsRef.doc(wordId).update({'isFavorite': value});
  }

  // ---------------- Stats helpers ----------------

  Future<int> countTotal(List<String> deckIds) async {
    if (deckIds.isEmpty) return 0;
    int total = 0;
    for (var chunk in _chunkList(deckIds, 10)) {
      final snapshot = await _wordsRef.where('deckId', whereIn: chunk).count().get();
      total += snapshot.count ?? 0;
    }
    return total;
  }

  Future<int> countLearned(List<String> deckIds) async {
    if (deckIds.isEmpty) return 0;
    final allWords = await getAllWords(deckIds: deckIds);
    return allWords.where((w) => w.reviewCount > 0).length;
  }

  Future<int> countMastered(List<String> deckIds) async {
    if (deckIds.isEmpty) return 0;
    final allWords = await getAllWords(deckIds: deckIds);
    return allWords.where((w) => w.correctStreak >= 3 && w.interval >= 21).length;
  }

  Future<int> countDueOn(List<String> deckIds, DateTime day) async {
    if (deckIds.isEmpty) return 0;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    
    final allWords = await getAllWords(deckIds: deckIds);
    return allWords.where((w) {
      if (w.reviewCount == 0 || w.nextReview == null) return false;
      return !w.nextReview!.isBefore(startOfDay) && !w.nextReview!.isAfter(endOfDay);
    }).length;
  }

  Future<int> sumReviewCount(List<String> deckIds) async {
    if (deckIds.isEmpty) return 0;
    // Firestore doesn't have SUM aggregation yet in all SDKs easily.
    // Fetch all and sum in memory.
    final words = await getAllWords(deckIds: deckIds);
    return words.fold<int>(0, (int sum, w) => sum + w.reviewCount);
  }

  Future<int> sumCorrectCount(List<String> deckIds) async {
    if (deckIds.isEmpty) return 0;
    final words = await getAllWords(deckIds: deckIds);
    return words.fold<int>(0, (int sum, w) => sum + w.correctCount);
  }

  Future<void> deleteAllForDecks(List<String> deckIds) async {
    if (deckIds.isEmpty) return;
    for (var chunk in _chunkList(deckIds, 10)) {
      final snapshot = await _wordsRef.where('deckId', whereIn: chunk).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> resetProgress(List<String> deckIds) async {
    if (deckIds.isEmpty) return;
    for (var chunk in _chunkList(deckIds, 10)) {
      final snapshot = await _wordsRef.where('deckId', whereIn: chunk).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
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
        });
      }
      await batch.commit();
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}
