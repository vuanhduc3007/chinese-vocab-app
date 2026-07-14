import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchUrl() async {
    final url = Uri.parse('https://aistudio.google.com/app/apikey');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở liên kết. Bạn hãy tự truy cập: aistudio.google.com/app/apikey')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cần có Gemini API Key'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tính năng "Quét ảnh lấy từ vựng" sử dụng Trí tuệ nhân tạo (Google Gemini) để nhận diện và phân tích chữ Hán trong ảnh.\n\n'
              'Để sử dụng miễn phí, bạn cần cung cấp API Key cá nhân của mình. Mã này được lưu an toàn trên máy của bạn và không bị chia sẻ.',
            ),
            const SizedBox(height: 16),
            const Text('Cách lấy Key:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _launchUrl,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('1. Bấm vào đây để mở Google AI Studio'),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                '2. Đăng nhập bằng tài khoản Google\n'
                '3. Bấm nút "Create API Key" \n'
                '4. Copy đoạn mã đó và dán vào ô bên dưới:',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
                hintText: 'AIzaSy...',
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final key = _controller.text.trim();
            if (key.isNotEmpty) {
              Navigator.of(context).pop(key);
            }
          },
          child: const Text('Lưu & Tiếp tục'),
        ),
      ],
    );
  }
}
