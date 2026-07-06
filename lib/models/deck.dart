/// A Deck groups vocabulary words together (e.g. HSK1, HSK2, "Tu cua toi").
/// Each deck has its own independent learning progress because SRS state
/// lives on the [Word] rows, which are each tagged with a `deckId`.
class Deck {
  final int? id;
  final String name;
  final DateTime createdDate;
  final String? sourceFileName; // last txt file imported into this deck

  Deck({
    this.id,
    required this.name,
    DateTime? createdDate,
    this.sourceFileName,
  }) : createdDate = createdDate ?? DateTime.now();

  Deck copyWith({int? id, String? name, String? sourceFileName}) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate,
      sourceFileName: sourceFileName ?? this.sourceFileName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdDate': createdDate.toIso8601String(),
      'sourceFileName': sourceFileName,
    };
  }

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdDate: map['createdDate'] != null
          ? DateTime.parse(map['createdDate'] as String)
          : DateTime.now(),
      sourceFileName: map['sourceFileName'] as String?,
    );
  }
}
