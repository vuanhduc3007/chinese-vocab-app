import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_helper_io.dart' if (dart.library.html) 'database_helper_web.dart' as db_platform;

/// Central place that owns the single [Database] instance for the whole
/// app and creates/migrates its schema. Both repositories talk only to
/// this helper - nothing else in the codebase issues raw SQL, which is
/// what keeps the "database" layer cleanly separated from "repositories"
/// per the requested Clean Architecture.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String dbFileName = 'chinese_vocab.db';
  static const int dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // On web, use the FFI web factory backed by sql.js (IndexedDB persistence)
      databaseFactory = databaseFactoryFfiWeb;
    } else if (db_platform.isDesktop) {
      // On desktop (Windows/Linux/macOS) use the FFI-backed factory
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // On mobile (Android/iOS), sqflite uses its native factory by default.

    final dbPath = await db_platform.getDatabasePath(dbFileName);

    return openDatabase(
      dbPath,
      version: dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE decks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        createdDate TEXT NOT NULL,
        sourceFileName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hanzi TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        meaning TEXT NOT NULL,
        partOfSpeech TEXT,
        deckId INTEGER NOT NULL,

        correctCount INTEGER NOT NULL DEFAULT 0,
        wrongCount INTEGER NOT NULL DEFAULT 0,
        reviewCount INTEGER NOT NULL DEFAULT 0,
        correctStreak INTEGER NOT NULL DEFAULT 0,

        easeFactor REAL NOT NULL DEFAULT 2.5,
        interval INTEGER NOT NULL DEFAULT 0,
        repetition INTEGER NOT NULL DEFAULT 0,

        lastReview TEXT,
        nextReview TEXT,
        lastShown TEXT,

        createdDate TEXT NOT NULL,
        isFavorite INTEGER NOT NULL DEFAULT 0,

        FOREIGN KEY (deckId) REFERENCES decks (id) ON DELETE CASCADE,
        UNIQUE (hanzi, pinyin, deckId)
      )
    ''');

    await db.execute('CREATE INDEX idx_words_deck ON words (deckId)');
    await db.execute('CREATE INDEX idx_words_next_review ON words (nextReview)');

    // Table that records how many *new* words were first-learned on each
    // calendar day, used for the "words learned per day" chart and daily
    // goal tracking without needing to re-scan the whole words table.
    await db.execute('''
      CREATE TABLE daily_stats (
        date TEXT PRIMARY KEY,
        learnedCount INTEGER NOT NULL DEFAULT 0,
        reviewedCount INTEGER NOT NULL DEFAULT 0,
        forgotCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // A default deck so the app is immediately usable before any import.
    await db.insert('decks', {
      'name': 'Từ của tôi',
      'createdDate': DateTime.now().toIso8601String(),
      'sourceFileName': null,
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
