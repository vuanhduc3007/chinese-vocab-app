import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_utils.dart';

class DailyStatsService {
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  CollectionReference get _statsRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('daily_stats');

  Future<void> recordReview({required bool isNewWord, required bool remembered}) async {
    final dateKey = AppDateUtils.dayKey(DateTime.now());
    final docRef = _statsRef.doc(dateKey);

    await docRef.set({
      'date': dateKey,
      'reviewedCount': FieldValue.increment(1),
      'learnedCount': FieldValue.increment(isNewWord ? 1 : 0),
      'forgotCount': FieldValue.increment(remembered ? 0 : 1),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getToday() async {
    final dateKey = AppDateUtils.dayKey(DateTime.now());
    final doc = await _statsRef.doc(dateKey).get();
    if (!doc.exists) {
      return {'date': dateKey, 'learnedCount': 0, 'reviewedCount': 0, 'forgotCount': 0};
    }
    return doc.data() as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLastNDays(int days) async {
    final now = DateTime.now();
    final keys = List.generate(days, (i) => AppDateUtils.dayKey(now.subtract(Duration(days: days - 1 - i))));
    
    // Firestore whereIn supports up to 30 items. If days > 30, we'd need to chunk.
    // Assuming days is usually 7.
    final snapshot = await _statsRef.where('date', whereIn: keys).get();
    
    final byDate = {
      for (final doc in snapshot.docs) 
        doc.id: doc.data() as Map<String, dynamic>
    };
    
    return keys
        .map((k) => byDate[k] ?? {'date': k, 'learnedCount': 0, 'reviewedCount': 0, 'forgotCount': 0})
        .toList();
  }

  Future<int> getStudyStreak() async {
    final snapshot = await _statsRef.orderBy('date', descending: true).get();
    if (snapshot.docs.isEmpty) return 0;

    final datesWithActivity = snapshot.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((r) => ((r['reviewedCount'] as int?) ?? 0) > 0)
        .map((r) => r['date'] as String)
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    if (!datesWithActivity.contains(AppDateUtils.dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (datesWithActivity.contains(AppDateUtils.dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
