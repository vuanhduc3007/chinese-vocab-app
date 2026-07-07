import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/deck_provider.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/answer_buttons.dart';

/// The single, infinite learning screen. There is intentionally no
/// "end of session" state anywhere in this widget - it always shows
/// exactly one word and two/one action(s), forever, until the user
/// explicitly exits.
class LearningScreen extends StatefulWidget {
  final VoidCallback? onExit;
  const LearningScreen({super.key, this.onExit});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final FocusNode _focusNode = FocusNode();
  Set<String> _lastActiveDeckIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-syncs the learning queue whenever the set of active decks
    // changes (e.g. user (de)selected a deck on the Deck screen), but
    // avoids reloading the current word on every unrelated rebuild.
    final deckProvider = context.watch<DeckProvider>();
    if (!_setEquals(deckProvider.activeDeckIds, _lastActiveDeckIds)) {
      _lastActiveDeckIds = Set.of(deckProvider.activeDeckIds);
      final deckIds = deckProvider.activeDeckIds.toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LearningProvider>().setActiveDecks(deckIds);
      });
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final learningProvider = context.read<LearningProvider>();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        learningProvider.revealAnswer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (learningProvider.face == CardFace.answer) {
          learningProvider.answerRemembered();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        if (learningProvider.face == CardFace.answer) {
          learningProvider.answerForgot();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onExit?.call();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();
    final word = learningProvider.currentWord;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Học từ vựng'),
          actions: [
            IconButton(
              onPressed: () => widget.onExit?.call(),
              icon: const Icon(Icons.close),
              tooltip: 'Thoát',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: word == null
                  ? _buildEmptyState(context, learningProvider)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlashcardWidget(
                          word: word,
                          face: learningProvider.face,
                          onSpeak: learningProvider.speakCurrentWord,
                          onToggleFavorite: learningProvider.toggleFavoriteCurrentWord,
                        ),
                        const SizedBox(height: 32),
                        if (learningProvider.face == CardFace.question)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: learningProvider.revealAnswer,
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                              child: const Text('Hiện đáp án', style: TextStyle(fontSize: 16)),
                            ),
                          )
                        else
                          AnswerButtons(
                            onRemembered: learningProvider.answerRemembered,
                            onForgot: learningProvider.answerForgot,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, LearningProvider provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Chưa có từ vựng nào trong bộ từ đang chọn.\nHãy import file .txt ở màn hình Bộ từ.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
