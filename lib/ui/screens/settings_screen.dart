import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/deck_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<app_auth.AuthProvider>();

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
          ListTile(
            title: const Text('Gemini API Key'),
            subtitle: Text(
              (settings.geminiApiKey == null || settings.geminiApiKey!.isEmpty)
                  ? 'Chưa cấu hình (Cần thiết cho tính năng Quét ảnh)'
                  : 'Đã cấu hình (Nhấn để thay đổi)',
            ),
            trailing: const Icon(Icons.vpn_key),
            onTap: () async {
              final controller = TextEditingController(text: settings.geminiApiKey ?? '');
              final value = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cấu hình Gemini API Key'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Nhập API Key mới hoặc xóa trắng để xóa...',
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Lưu')),
                  ],
                ),
              );
              if (value != null) {
                await settings.setGeminiApiKey(value.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật Gemini API Key')));
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: Colors.teal),
            title: const Text('Đồng bộ dữ liệu'),
            subtitle: Text('Tài khoản: ${auth.user?.email ?? "Không rõ"}'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dữ liệu đang được tự động đồng bộ 2 chiều!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await auth.signOut();
            },
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
      setState(() => _busy = true);
      try {
        await context.read<DeckProvider>().resetAllProgress();
        _snack('Đã reset toàn bộ tiến trình học trên Cloud.');
      } finally {
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
