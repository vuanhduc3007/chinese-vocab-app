import 'package:flutter/material.dart';
import '../../models/word.dart';

class AiPreviewDialog extends StatefulWidget {
  final List<Word> words;

  const AiPreviewDialog({super.key, required this.words});

  @override
  State<AiPreviewDialog> createState() => _AiPreviewDialogState();
}

class _AiPreviewDialogState extends State<AiPreviewDialog> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    // Select all by default
    _selected = List.generate(widget.words.length, (_) => true);
  }

  int get _selectedCount => _selected.where((s) => s).length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tìm thấy ${widget.words.length} từ (Chọn $_selectedCount)'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.words.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final word = widget.words[index];
            return CheckboxListTile(
              value: _selected[index],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selected[index] = val);
                }
              },
              title: Text(
                word.hanzi,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${word.pinyin} - ${word.meaning}'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _selectedCount == 0
              ? null
              : () {
                  final result = <Word>[];
                  for (var i = 0; i < widget.words.length; i++) {
                    if (_selected[i]) {
                      result.add(widget.words[i]);
                    }
                  }
                  Navigator.of(context).pop(result);
                },
          child: const Text('Lưu vào Bộ từ'),
        ),
      ],
    );
  }
}
