import 'package:flutter/material.dart';
import '../../models/word.dart';
import '../../providers/learning_provider.dart';

/// Flashcard for "Typing" mode: shows meaning + pinyin as the question,
/// user types the Hanzi into a TextField, then the answer is revealed
/// with a correct/incorrect comparison.
class TypingFlashcardWidget extends StatefulWidget {
  final Word word;
  final CardFace face;
  final String? userInput;
  final bool? isCorrect;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;
  final ValueChanged<String> onSubmit;

  const TypingFlashcardWidget({
    super.key,
    required this.word,
    required this.face,
    this.userInput,
    this.isCorrect,
    required this.onSpeak,
    required this.onToggleFavorite,
    required this.onSubmit,
  });

  @override
  State<TypingFlashcardWidget> createState() => _TypingFlashcardWidgetState();
}

class _TypingFlashcardWidgetState extends State<TypingFlashcardWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant TypingFlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When word changes (new card), clear the input field
    if (oldWidget.word.id != widget.word.id) {
      _controller.clear();
      // Re-focus the text field for the next word
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswer = widget.face == CardFace.answer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Favorite button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: widget.onToggleFavorite,
              icon: Icon(
                widget.word.isFavorite ? Icons.star : Icons.star_border,
                color: widget.word.isFavorite ? Colors.amber : theme.iconTheme.color,
              ),
              tooltip: 'Đánh dấu từ khó',
            ),
          ),

          // Meaning (the "question" in writing mode)
          Text(
            widget.word.meaning,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),

          // Part of speech
          if (widget.word.partOfSpeech != null && widget.word.partOfSpeech!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '[${widget.word.partOfSpeech}]',
              style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 24),

          if (!isAnswer) ...[
            // Input field
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28),
              decoration: InputDecoration(
                hintText: 'Nhập chữ Hán...',
                hintStyle: TextStyle(fontSize: 20, color: theme.hintColor),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Kiểm tra đáp án', style: TextStyle(fontSize: 16)),
              ),
            ),
          ] else ...[
            // Answer revealed - show comparison
            _buildResultBanner(theme),
            const SizedBox(height: 16),

            // Correct answer (Hanzi)
            Text(
              widget.word.hanzi,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // What user typed
            if (widget.userInput != null && widget.userInput!.isNotEmpty) ...[
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.titleMedium,
                  children: [
                    TextSpan(
                      text: 'Bạn gõ: ',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                    TextSpan(
                      text: widget.userInput,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.isCorrect == true ? Colors.green : Colors.redAccent,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Speak button
            IconButton(
              onPressed: widget.onSpeak,
              icon: const Icon(Icons.volume_up, size: 32),
              tooltip: 'Phát âm',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(ThemeData theme) {
    final correct = widget.isCorrect == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: correct ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.cancel,
            color: correct ? Colors.green : Colors.redAccent,
          ),
          const SizedBox(width: 8),
          Text(
            correct ? 'Chính xác!' : 'Chưa đúng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: correct ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
