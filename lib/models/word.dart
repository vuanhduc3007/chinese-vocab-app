class Word {
  final String? id;

  // ----- Content fields (parsed from txt) -----
  final String hanzi;
  final String pinyin;
  final String meaning;
  final String? partOfSpeech;
  final String deckId;

  // ----- SM-2 / learning state fields -----
  int correctCount;
  int wrongCount;
  int reviewCount;
  int correctStreak;

  double easeFactor;
  int interval; // in days
  int repetition;

  DateTime? lastReview;
  DateTime? nextReview;
  DateTime? lastShown;

  final DateTime createdDate;
  bool isFavorite;

  Word({
    this.id,
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    this.partOfSpeech,
    required this.deckId,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.reviewCount = 0,
    this.correctStreak = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetition = 0,
    this.lastReview,
    this.nextReview,
    this.lastShown,
    DateTime? createdDate,
    this.isFavorite = false,
  }) : createdDate = createdDate ?? DateTime.now();

  bool get isNew => reviewCount == 0;

  bool isDue(DateTime now) {
    if (isNew) return false;
    if (nextReview == null) return true;
    return !nextReview!.isAfter(now);
  }

  Word copyWith({
    String? id,
    String? hanzi,
    String? pinyin,
    String? meaning,
    String? partOfSpeech,
    String? deckId,
    int? correctCount,
    int? wrongCount,
    int? reviewCount,
    int? correctStreak,
    double? easeFactor,
    int? interval,
    int? repetition,
    DateTime? lastReview,
    DateTime? nextReview,
    DateTime? lastShown,
    DateTime? createdDate,
    bool? isFavorite,
  }) {
    return Word(
      id: id ?? this.id,
      hanzi: hanzi ?? this.hanzi,
      pinyin: pinyin ?? this.pinyin,
      meaning: meaning ?? this.meaning,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      deckId: deckId ?? this.deckId,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      reviewCount: reviewCount ?? this.reviewCount,
      correctStreak: correctStreak ?? this.correctStreak,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetition: repetition ?? this.repetition,
      lastReview: lastReview ?? this.lastReview,
      nextReview: nextReview ?? this.nextReview,
      lastShown: lastShown ?? this.lastShown,
      createdDate: createdDate ?? this.createdDate,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hanzi': hanzi,
      'pinyin': pinyin,
      'meaning': meaning,
      'partOfSpeech': partOfSpeech,
      'deckId': deckId,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'reviewCount': reviewCount,
      'correctStreak': correctStreak,
      'easeFactor': easeFactor,
      'interval': interval,
      'repetition': repetition,
      'lastReview': lastReview?.toIso8601String(),
      'nextReview': nextReview?.toIso8601String(),
      'lastShown': lastShown?.toIso8601String(),
      'createdDate': createdDate.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map, [String? docId]) {
    return Word(
      id: docId ?? map['id'] as String?,
      hanzi: map['hanzi'] as String,
      pinyin: map['pinyin'] as String,
      meaning: map['meaning'] as String,
      partOfSpeech: map['partOfSpeech'] as String?,
      deckId: map['deckId'] as String,
      correctCount: map['correctCount'] as int? ?? 0,
      wrongCount: map['wrongCount'] as int? ?? 0,
      reviewCount: map['reviewCount'] as int? ?? 0,
      correctStreak: map['correctStreak'] as int? ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] as int? ?? 0,
      repetition: map['repetition'] as int? ?? 0,
      lastReview: map['lastReview'] != null
          ? DateTime.parse(map['lastReview'] as String)
          : null,
      nextReview: map['nextReview'] != null
          ? DateTime.parse(map['nextReview'] as String)
          : null,
      lastShown: map['lastShown'] != null
          ? DateTime.parse(map['lastShown'] as String)
          : null,
      createdDate: map['createdDate'] != null
          ? DateTime.parse(map['createdDate'] as String)
          : DateTime.now(),
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }
}
