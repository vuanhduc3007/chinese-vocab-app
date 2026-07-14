import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/word.dart';

class AiImportService {
  final String apiKey;

  AiImportService({required this.apiKey});

  Future<List<Word>> extractVocabFromImage(Uint8List imageBytes, String deckId) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = TextPart(
      '''
Hãy phân tích bức ảnh này và trích xuất toàn bộ từ vựng tiếng Trung có trong đó.
Yêu cầu:
1. Loại bỏ các từ trùng lặp (mỗi từ chỉ xuất hiện 1 lần).
2. Tra cứu Pinyin, Nghĩa tiếng Việt và Từ loại cho từng từ.
3. Trả về kết quả dưới định dạng JSON là một mảng (array) các object.
Mỗi object có cấu trúc chính xác như sau:
{
  "hanzi": "字",
  "pinyin": "zì",
  "meaning": "chữ",
  "partOfSpeech": "danh từ"
}
Không xuất ra bất kỳ text nào khác ngoài JSON.
'''
    );

    final imageParts = [
      DataPart('image/jpeg', imageBytes),
    ];

    try {
      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) return [];

      // Extract JSON from response (handling potential markdown block)
      String jsonStr = text;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final List<dynamic> decoded = jsonDecode(jsonStr);
      final List<Word> words = [];

      for (var item in decoded) {
        if (item is Map<String, dynamic>) {
          final hanzi = item['hanzi']?.toString() ?? '';
          if (hanzi.isEmpty) continue;

          words.add(Word(
            deckId: deckId,
            hanzi: hanzi,
            pinyin: item['pinyin']?.toString() ?? '',
            meaning: item['meaning']?.toString() ?? '',
            partOfSpeech: item['partOfSpeech']?.toString(),
            createdDate: DateTime.now(),
          ));
        }
      }

      return words;
    } catch (e) {
      print('AI Error: \$e');
      throw Exception('Không thể phân tích ảnh. Vui lòng kiểm tra lại API Key hoặc thử lại sau.');
    }
  }
}
