import 'package:flutter/material.dart';
import '../../models/word.dart';
import '../../providers/learning_provider.dart';
import '../../services/handwriting_service.dart';

/// Flashcard for "Drawing" mode: shows meaning as question,
/// user draws Chinese characters on a canvas, system recognizes them
/// via Google Input Tools, then compares with the correct answer.
class DrawingFlashcardWidget extends StatefulWidget {
  final Word word;
  final CardFace face;
  final String? userInput;
  final bool? isCorrect;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;
  final ValueChanged<String> onSubmit;

  const DrawingFlashcardWidget({
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
  State<DrawingFlashcardWidget> createState() => _DrawingFlashcardWidgetState();
}

class _DrawingFlashcardWidgetState extends State<DrawingFlashcardWidget> {
  final HandwritingService _hwService = HandwritingService();

  // Current stroke being drawn
  List<Map<String, double>> _currentStroke = [];
  // All completed strokes (for recognition)
  List<List<Map<String, double>>> _strokes = [];
  // Recognized candidates from the last recognition call
  List<String> _candidates = [];
  // The accumulated user answer (multiple characters)
  String _composedAnswer = '';
  bool _isRecognizing = false;
  // Canvas size for recognition
  double _canvasWidth = 280;
  double _canvasHeight = 280;

  @override
  void didUpdateWidget(covariant DrawingFlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
      _clearAll();
    }
  }

  void _clearAll() {
    setState(() {
      _currentStroke = [];
      _strokes = [];
      _candidates = [];
      _composedAnswer = '';
      _isRecognizing = false;
    });
  }

  void _clearCanvas() {
    setState(() {
      _currentStroke = [];
      _strokes = [];
      _candidates = [];
      _isRecognizing = false;
    });
  }

  void _undoLastChar() {
    if (_composedAnswer.isEmpty) return;
    setState(() {
      _composedAnswer = _composedAnswer.substring(0, _composedAnswer.length - 1);
    });
  }

  Future<void> _recognizeStrokes() async {
    if (_strokes.isEmpty) return;
    setState(() => _isRecognizing = true);

    final candidates = await _hwService.recognize(
      strokes: _strokes,
      canvasWidth: _canvasWidth,
      canvasHeight: _canvasHeight,
    );

    if (mounted) {
      setState(() {
        _candidates = candidates;
        _isRecognizing = false;
      });
    }
  }

  void _selectCandidate(String char) {
    setState(() {
      _composedAnswer += char;
      _strokes = [];
      _currentStroke = [];
      _candidates = [];
    });
  }

  void _handleSubmit() {
    if (_composedAnswer.isEmpty) return;
    widget.onSubmit(_composedAnswer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswer = widget.face == CardFace.answer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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

          // Meaning (the "question")
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

          const SizedBox(height: 16),

          if (!isAnswer) ...[
            // Composed answer so far
            if (_composedAnswer.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _composedAnswer,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _undoLastChar,
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      tooltip: 'Xóa chữ cuối',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Drawing canvas
            LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxWidth.clamp(200.0, 300.0);
                _canvasWidth = size;
                _canvasHeight = size;
                return Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surface,
                    ),
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _currentStroke = [
                            {'x': details.localPosition.dx, 'y': details.localPosition.dy}
                          ];
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _currentStroke.add({
                            'x': details.localPosition.dx.clamp(0, size),
                            'y': details.localPosition.dy.clamp(0, size),
                          });
                        });
                      },
                      onPanEnd: (_) {
                        setState(() {
                          if (_currentStroke.length > 1) {
                            _strokes.add(List.from(_currentStroke));
                          }
                          _currentStroke = [];
                        });
                        _recognizeStrokes();
                      },
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _StrokePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Candidates row
            if (_isRecognizing)
              const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_candidates.isNotEmpty)
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _candidates.map((c) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => _selectCandidate(c),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 22),
                        ),
                        child: Text(c),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              const SizedBox(height: 48),

            const SizedBox(height: 8),

            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearCanvas,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Xóa nét'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _composedAnswer.isEmpty ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Kiểm tra đáp án', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Answer revealed
            _buildResultBanner(theme),
            const SizedBox(height: 16),

            // Correct answer (Hanzi)
            Text(
              widget.word.hanzi,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),

            // Pinyin
            Text(
              widget.word.pinyin,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            // What user composed
            if (widget.userInput != null && widget.userInput!.isNotEmpty) ...[
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.titleMedium,
                  children: [
                    TextSpan(
                      text: 'Bạn viết: ',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                    TextSpan(
                      text: widget.userInput,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.isCorrect == true ? Colors.green : Colors.redAccent,
                        fontSize: 24,
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

/// Custom painter that draws all completed strokes and the current
/// in-progress stroke on the canvas.
class _StrokePainter extends CustomPainter {
  final List<List<Map<String, double>>> strokes;
  final List<Map<String, double>> currentStroke;
  final Color color;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw cross guides (faint)
    final guidePaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), guidePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), guidePaint);

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Draw current stroke
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Map<String, double>> stroke, Paint paint) {
    if (stroke.length < 2) return;
    final path = Path();
    path.moveTo(stroke[0]['x']!, stroke[0]['y']!);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i]['x']!, stroke[i]['y']!);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
