import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service that sends handwritten stroke data to Google Input Tools
/// for Chinese character recognition. Returns a list of candidate
/// characters the user can pick from.
class HandwritingService {
  static const _url = 'https://inputtools.google.com/request?itc=zh-t-i0-handwrit&app=chromeos';

  /// Recognizes handwritten strokes and returns up to [maxResults] candidates.
  ///
  /// [strokes] is a list of strokes, where each stroke is a list of points,
  /// and each point is an [Offset]-like pair {x, y}.
  /// 
  /// The Google Input Tools API expects:
  /// - ink: list of strokes, each stroke = [[x1,x2,...],[y1,y2,...]]
  /// - width/height of the canvas
  Future<List<String>> recognize({
    required List<List<Map<String, double>>> strokes,
    required double canvasWidth,
    required double canvasHeight,
    int maxResults = 5,
  }) async {
    if (strokes.isEmpty) return [];

    // Convert strokes to the format Google expects:
    // Each stroke is [[x1, x2, ...], [y1, y2, ...]]
    final inkStrokes = <List<List<int>>>[];
    for (final stroke in strokes) {
      final xs = <int>[];
      final ys = <int>[];
      for (final point in stroke) {
        xs.add(point['x']!.round());
        ys.add(point['y']!.round());
      }
      inkStrokes.add([xs, ys]);
    }

    final payload = jsonEncode({
      'options': 'enable_pre_space',
      'requests': [
        {
          'writing_guide': {
            'writing_area_width': canvasWidth.round(),
            'writing_area_height': canvasHeight.round(),
          },
          'ink': inkStrokes,
          'language': 'zh',
        }
      ]
    });

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      // Response format: ['SUCCESS', [['', candidates, ...]]]
      if (data is! List || data.isEmpty || data[0] != 'SUCCESS') return [];

      final results = data[1];
      if (results is! List || results.isEmpty) return [];

      final candidateList = results[0];
      if (candidateList is! List || candidateList.length < 2) return [];

      final candidates = candidateList[1];
      if (candidates is! List) return [];

      return candidates
          .whereType<String>()
          .take(maxResults)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
