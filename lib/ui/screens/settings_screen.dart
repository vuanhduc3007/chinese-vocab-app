import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/deck_provider.dart';
import '../../repositories/word_repository.dart';
import '../../repositories/deck_repository.dart';
import '../../services/backup_service.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final BackupService _backupService = BackupService(
    wordRepository: WordRepository(),
    deckRepository: DeckRepository(),
  );
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.isDarkMode,
            onChanged: (v) => settings.setDarkMode(v),
          ),
          ListTile(
            title: const Text('Mục tiêu học hôm nay (Daily Goal)'),
            subtitle: Text('${settings.dailyGoal} từ / ngày'),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final controller = TextEditingController(text: settings.dailyGoal.toString());
              final value = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đặt mục tiêu hàng ngày'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Lưu')),
                  ],
                ),
              );
              final parsed = int.tryParse(value ?? '');
              if (parsed != null && parsed > 0) {
                await settings.setDailyGoal(parsed);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Progress'),
            subtitle: const Text('Lưu tiến trình học ra file JSON'),
            onTap: _busy ? null : _exportProgress,
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import Progress'),
            subtitle: const Text('Nạp lại tiến trình học từ file JSON'),
            onTap: _busy ? null : _importProgress,
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup database ngay'),
            onTap: _busy ? null : _backupNow,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined, color: Colors.redAccent),
            title: const Text('Reset toàn bộ tiến trình học', style: TextStyle(color: Colors.redAccent)),
            onTap: _busy ? null : _resetAll,
          ),
        ],
      ),
    );
  }

  Future<void> _exportProgress() async {
    setState(() => _busy = true);
    try {
      final path = await _backupService.exportProgress();
      _snack('Đã export ra: $path');
    } catch (e) {
      _snack('Lỗi export: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _importProgress() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _busy = true);
    try {
      final jsonString = utf8.decode(file.bytes!);
      final count = await _backupService.importProgressFromJson(jsonString);
      if (mounted) {
        await context.read<DeckProvider>().load();
      }
      _snack('Đã import/cập nhật $count từ.');
    } catch (e) {
      _snack('Lỗi import: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      final path = await _backupService.backupDatabaseFile();
      _snack('Đã backup: $path');
    } catch (e) {
      _snack('Lỗi backup: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận reset'),
        content: const Text('Toàn bộ tiến trình học (SRS) sẽ bị xóa. Từ vựng vẫn được giữ lại. Bạn chắc chứ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<DeckProvider>().resetAllProgress();
      _snack('Đã reset toàn bộ tiến trình học.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
