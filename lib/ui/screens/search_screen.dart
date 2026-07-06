import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/word.dart';
import '../../providers/deck_provider.dart';
import '../../repositories/word_repository.dart';

/// Search across hanzi / pinyin / meaning, scoped to the currently
/// active decks. Also doubles as a quick way to browse and star
/// individual words as "khó" (difficult) outside of the review flow.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final WordRepository _repository = WordRepository();
  List<Word> _results = [];
  bool _onlyFavorites = false;

  Future<void> _runSearch() async {
    final deckIds = context.read<DeckProvider>().activeDeckIds.toList();
    if (deckIds.isEmpty) {
      setState(() => _results = []);
      return;
    }

    List<Word> results;
    if (_onlyFavorites) {
      results = await _repository.getFavorites(deckIds: deckIds);
      final query = _controller.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        results = results
            .where((w) =>
                w.hanzi.toLowerCase().contains(query) ||
                w.pinyin.toLowerCase().contains(query) ||
                w.meaning.toLowerCase().contains(query))
            .toList();
      }
    } else {
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() => _results = []);
        return;
      }
      results = await _repository.searchWords(query, deckIds: deckIds);
    }
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo chữ Hán, pinyin, hoặc nghĩa...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _runSearch(),
                    onChanged: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('★ khó'),
                  selected: _onlyFavorites,
                  onSelected: (v) {
                    setState(() => _onlyFavorites = v);
                    _runSearch();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final w = _results[index];
                return ListTile(
                  title: Text('${w.hanzi}  ·  ${w.pinyin}'),
                  subtitle: Text(w.partOfSpeech != null ? '[${w.partOfSpeech}] ${w.meaning}' : w.meaning),
                  trailing: IconButton(
                    icon: Icon(w.isFavorite ? Icons.star : Icons.star_border,
                        color: w.isFavorite ? Colors.amber : null),
                    onPressed: () async {
                      await _repository.toggleFavorite(w.id!, !w.isFavorite);
                      _runSearch();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
