class Deck {
  final String? id;
  final String name;
  final DateTime createdDate;

  /// Optional: Remember the original filename if imported from a text file.
  final String? sourceFileName;

  Deck({
    this.id,
    required this.name,
    this.sourceFileName,
    DateTime? createdDate,
  }) : createdDate = createdDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdDate': createdDate.toIso8601String(),
      'sourceFileName': sourceFileName,
    };
  }

  factory Deck.fromMap(Map<String, dynamic> map, [String? docId]) {
    return Deck(
      id: docId ?? map['id'] as String?,
      name: map['name'] as String,
      sourceFileName: map['sourceFileName'] as String?,
      createdDate: map['createdDate'] != null
          ? DateTime.parse(map['createdDate'] as String)
          : null,
    );
  }
}
