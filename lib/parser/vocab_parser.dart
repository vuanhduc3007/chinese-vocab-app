/// A single parsed line from the vocabulary .txt source, before it is
/// turned into a persisted [Word] (parsing has no idea about decks, ids,
/// or SRS state - it only understands the text format).
class ParsedEntry {
  final String hanzi;
  final String pinyin;
  final String? partOfSpeech;
  final String meaning;

  const ParsedEntry({
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    this.partOfSpeech,
  });

  @override
  String toString() =>
      'ParsedEntry(hanzi: $hanzi, pinyin: $pinyin, pos: $partOfSpeech, meaning: $meaning)';
}

/// Parses the plain-text vocabulary format described in the project spec:
///
///   Chu Han ; Pinyin [Loai tu] : Nghia
///
/// Examples:
///   临;lín [đt.]: đến, tới
///   你;nǐ [đại.]: bạn
///   你好;nǐ hǎo: xin chào       (no part-of-speech -> still valid)
///
/// The parser is deliberately forgiving about whitespace around the `;`
/// and `:` separators, and about the optional `[...]` part-of-speech tag.
/// Nothing here is hard-coded: every entry comes purely from the text
/// that is fed in.
class VocabParser {
  const VocabParser._();

  static final RegExp _lineRegex = RegExp(
    r'^\s*(?<hanzi>[^;]+?)\s*;\s*(?<pinyin>[^\[:]+?)\s*(?:\[(?<pos>[^\]]*)\]\s*)?:\s*(?<meaning>.+?)\s*$',
  );

  /// Parses the full contents of a vocabulary txt file into a list of
  /// [ParsedEntry]. Blank lines and lines starting with `#` (comments)
  /// are ignored. Lines that don't match the expected format are simply
  /// skipped (reported via [onInvalidLine] if provided) rather than
  /// crashing the whole import.
  static List<ParsedEntry> parseFile(
    String content, {
    void Function(int lineNumber, String rawLine)? onInvalidLine,
  }) {
    final entries = <ParsedEntry>[];
    final lines = content.split(RegExp(r'\r\n|\r|\n'));

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final entry = parseLine(trimmed);
      if (entry == null) {
        onInvalidLine?.call(i + 1, raw);
        continue;
      }
      entries.add(entry);
    }
    return entries;
  }

  /// Parses a single line. Returns null if the line does not match the
  /// expected `hanzi;pinyin [pos]: meaning` format.
  static ParsedEntry? parseLine(String line) {
    final match = _lineRegex.firstMatch(line);
    if (match == null) return null;

    final hanzi = match.namedGroup('hanzi')?.trim() ?? '';
    final pinyin = match.namedGroup('pinyin')?.trim() ?? '';
    final pos = match.namedGroup('pos')?.trim();
    final meaning = match.namedGroup('meaning')?.trim() ?? '';

    if (hanzi.isEmpty || pinyin.isEmpty || meaning.isEmpty) return null;

    return ParsedEntry(
      hanzi: hanzi,
      pinyin: pinyin,
      partOfSpeech: (pos == null || pos.isEmpty) ? null : pos,
      meaning: meaning,
    );
  }
}
