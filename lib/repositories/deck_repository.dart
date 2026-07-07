import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/deck.dart';

class DeckRepository {
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  CollectionReference get _decksRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('decks');

  Future<List<Deck>> getAllDecks() async {
    final snapshot = await _decksRef.orderBy('createdDate').get();
    return snapshot.docs.map((doc) => Deck.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<Deck?> getDeckByName(String name) async {
    final snapshot = await _decksRef.where('name', isEqualTo: name).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Deck.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<Deck?> getDeckById(String id) async {
    final doc = await _decksRef.doc(id).get();
    if (!doc.exists) return null;
    return Deck.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<Deck> getOrCreateDeck(String name, {String? sourceFileName}) async {
    final existing = await getDeckByName(name);
    if (existing != null) return existing;

    final docRef = _decksRef.doc(); // Auto-generate ID
    final newDeck = Deck(
      id: docRef.id,
      name: name,
      sourceFileName: sourceFileName,
    );
    await docRef.set(newDeck.toMap());
    return newDeck;
  }

  Future<void> updateSourceFileName(String deckId, String fileName) async {
    await _decksRef.doc(deckId).update({'sourceFileName': fileName});
  }

  Future<void> deleteDeck(String deckId) async {
    // Note: Deleting a deck should also delete its words. 
    // We'll leave the words deletion to be handled explicitly by the provider or a cloud function,
    // but for now, we just delete the deck document.
    await _decksRef.doc(deckId).delete();
  }

  Future<int> wordCountForDeck(String deckId) async {
    final wordsRef = FirebaseFirestore.instance.collection('users').doc(_uid).collection('words');
    final snapshot = await wordsRef.where('deckId', isEqualTo: deckId).count().get();
    return snapshot.count ?? 0;
  }
}
