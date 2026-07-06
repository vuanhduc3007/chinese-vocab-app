import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/deck_provider.dart';

/// Manage decks: create, delete, pick which ones are active for the
/// Learning screen, and import a .txt vocabulary file into any of them.
class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  bool _busy = false;

  Future<void> _pickAndImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    final deckName = await _askDeckName(context);
    if (deckName == null || deckName.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final content = utf8.decode(file.bytes!);
      final deckProvider = context.read<DeckProvider>();
      final added = await deckProvider.importTxtIntoDeck(
        deckName: deckName.trim(),
        fileContent: content,
        sourceFileName: result.files.single.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deckProvider.lastImportMessage ?? 'Đã thêm $added từ mới.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi import: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askDeckName(BuildContext context) async {
    final controller = TextEditingController();
    final decks = context.read<DeckProvider>().decks;
    if (decks.isNotEmpty) {
      // Offer a quick pick from existing decks, plus a free-text option.
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Import vào bộ từ nào?'),
          children: [
            ...decks.map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.name),
                child: Text(d.name),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, '__new__'),
              child: const Text('+ Tạo bộ từ mới'),
            ),
          ],
        ),
      );
      if (choice != '__new__') return choice;
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tên bộ từ mới'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Tạo')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ từ (Decks)'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _pickAndImport(context),
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import file txt',
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : deckProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: deckProvider.decks.length,
                  itemBuilder: (context, index) {
                    final deck = deckProvider.decks[index];
                    final isActive = deckProvider.activeDeckIds.contains(deck.id);
                    return ListTile(
                      title: Text(deck.name),
                      subtitle: deck.sourceFileName != null ? Text(deck.sourceFileName!) : null,
                      leading: Checkbox(
                        value: isActive,
                        onChanged: (v) => deckProvider.toggleDeckActive(deck.id!, v ?? false),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa bộ từ?'),
                              content: Text('Toàn bộ từ và tiến trình học trong "${deck.name}" sẽ bị xóa.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await deckProvider.deleteDeck(deck.id!);
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          final name = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Tạo bộ từ trống'),
              content: TextField(controller: controller, autofocus: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Tạo')),
              ],
            ),
          );
          if (name != null && name.trim().isNotEmpty) {
            await deckProvider.createEmptyDeck(name.trim());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
