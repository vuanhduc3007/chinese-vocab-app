import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/deck_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/typing_flashcard_widget.dart';
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
  bool _modeInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Sync learning mode from settings on first build
    if (!_modeInitialized) {
      _modeInitialized = true;
      final settings = context.read<SettingsProvider>();
      final learningProvider = context.read<LearningProvider>();
      final mode = _modeFromString(settings.learningMode);
      if (learningProvider.learningMode != mode) {
        learningProvider.setLearningMode(mode);
      }
    }

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

  static LearningMode _modeFromString(String s) {
    switch (s) {
      case 'typing':
        return LearningMode.typing;
      case 'drawing':
        return LearningMode.drawing;
      default:
        return LearningMode.recognition;
    }
  }

  static String _modeToString(LearningMode m) {
    switch (m) {
      case LearningMode.typing:
        return 'typing';
      case LearningMode.drawing:
        return 'drawing';
      case LearningMode.recognition:
        return 'recognition';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final learningProvider = context.read<LearningProvider>();

    // In typing mode, don't intercept keyboard events (let TextField handle them)
    if (learningProvider.learningMode == LearningMode.typing &&
        learningProvider.face == CardFace.question) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (learningProvider.learningMode == LearningMode.recognition) {
          learningProvider.revealAnswer();
        }
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

  void _onModeChanged(LearningMode mode) {
    final learningProvider = context.read<LearningProvider>();
    learningProvider.setLearningMode(mode);
    context.read<SettingsProvider>().setLearningMode(_modeToString(mode));
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
            // Mode switcher
            PopupMenuButton<LearningMode>(
              tooltip: 'Chọn chế độ học',
              icon: Icon(_modeIcon(learningProvider.learningMode)),
              onSelected: _onModeChanged,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: LearningMode.recognition,
                  child: Row(
                    children: [
                      Icon(Icons.visibility,
                          color: learningProvider.learningMode == LearningMode.recognition
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      const SizedBox(width: 12),
                      const Text('Nhận mặt'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: LearningMode.typing,
                  child: Row(
                    children: [
                      Icon(Icons.keyboard,
                          color: learningProvider.learningMode == LearningMode.typing
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      const SizedBox(width: 12),
                      const Text('Gõ chữ'),
                    ],
                  ),
                ),
              ],
            ),
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFlashcard(learningProvider, word),
                                const SizedBox(height: 32),
                                _buildActions(learningProvider),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlashcard(LearningProvider provider, word) {
    switch (provider.learningMode) {
      case LearningMode.typing:
        return TypingFlashcardWidget(
          word: word,
          face: provider.face,
          userInput: provider.lastUserInput,
          isCorrect: provider.lastInputCorrect,
          onSpeak: provider.speakCurrentWord,
          onToggleFavorite: provider.toggleFavoriteCurrentWord,
          onSubmit: (input) => provider.submitWritingAnswer(input),
        );
      case LearningMode.recognition:
      default:
        return FlashcardWidget(
          word: word,
          face: provider.face,
          onSpeak: provider.speakCurrentWord,
          onToggleFavorite: provider.toggleFavoriteCurrentWord,
        );
    }
  }

  Widget _buildActions(LearningProvider provider) {
    if (provider.learningMode == LearningMode.typing && provider.face == CardFace.question) {
      // In typing mode, buttons are inside the flashcard widget
      return const SizedBox.shrink();
    }

    if (provider.face == CardFace.question) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: provider.revealAnswer,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
          child: const Text('Hiện đáp án', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return AnswerButtons(
      onRemembered: provider.answerRemembered,
      onForgot: provider.answerForgot,
    );
  }

  IconData _modeIcon(LearningMode mode) {
    switch (mode) {
      case LearningMode.recognition:
        return Icons.visibility;
      case LearningMode.typing:
        return Icons.keyboard;
      case LearningMode.drawing:
        return Icons.draw;
    }
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
