import 'package:flutter/material.dart';
import '../../models/word.dart';
import '../../providers/learning_provider.dart';

/// Renders the flashcard itself: hanzi-only on the question face, and
/// hanzi + pinyin + part-of-speech + meaning + speaker button once
/// revealed. Deliberately has zero animation per the spec ("chuyển câu
/// càng nhanh càng tốt") - just an instant content swap.
class FlashcardWidget extends StatelessWidget {
  final Word word;
  final CardFace face;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;

  const FlashcardWidget({
    super.key,
    required this.word,
    required this.face,
    required this.onSpeak,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswer = face == CardFace.answer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onToggleFavorite,
              icon: Icon(
                word.isFavorite ? Icons.star : Icons.star_border,
                color: word.isFavorite ? Colors.amber : theme.iconTheme.color,
              ),
              tooltip: 'Đánh dấu từ khó',
            ),
          ),
          Text(
            word.hanzi,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w600),
          ),
          if (isAnswer) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.pinyin,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Phát âm',
                ),
              ],
            ),
            if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '[${word.partOfSpeech}]',
                style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              word.meaning,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ],
        ],
      ),
    );
  }
}
