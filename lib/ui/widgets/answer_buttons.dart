import 'package:flutter/material.dart';

/// The two mutually-exclusive buttons shown after the answer is revealed.
/// Kept as one widget so both the Learning screen and any future review
/// mode (e.g. a dedicated "khó" review) can reuse the exact same look
/// and shortcut wiring.
class AnswerButtons extends StatelessWidget {
  final VoidCallback onRemembered;
  final VoidCallback onForgot;

  const AnswerButtons({super.key, required this.onRemembered, required this.onForgot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onForgot,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: Colors.redAccent),
            ),
            child: const Text('Quên', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: onRemembered,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.green,
            ),
            child: const Text('Đã nhớ', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
