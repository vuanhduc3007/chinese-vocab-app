import 'package:flutter/foundation.dart';
import 'tts_platform_stub.dart' if (dart.library.io) 'tts_platform_native.dart' as platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

/// TTS service that uses flutter_tts on Android and falls back to
/// Google Translate TTS (via audioplayers) on Windows when no Chinese
/// SAPI voice is available.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  bool _useWebTts = false; // true = use Google Translate TTS URL

  Future<void> _ensureInit() async {
    if (_initialized) return;

    try {
      if (!kIsWeb && platform.isWindows) {
        await _initWindows();
      } else {
        await _initMobile();
      }
    } catch (e) {
      debugPrint('[TTS] Init error: $e, falling back to web TTS');
      _useWebTts = true;
    }

    _initialized = true;
  }

  Future<void> _initWindows() async {
    // Check if a real Chinese voice exists in SAPI
    bool hasChineseVoice = false;

    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final name = (v['name'] ?? '').toString().toLowerCase();
            if (locale.contains('zh') || name.contains('huihui') ||
                name.contains('kangkang') || name.contains('yaoyao') ||
                name.contains('xiaoxiao') || name.contains('yunxi')) {
              hasChineseVoice = true;
              await _tts.setVoice({
                'name': v['name'].toString(),
                'locale': v['locale']?.toString() ?? 'zh-CN',
              });
              debugPrint('[TTS] Found Chinese voice: ${v['name']}');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TTS] Error checking voices: $e');
    }

    if (hasChineseVoice) {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _useWebTts = false;
      debugPrint('[TTS] Using SAPI Chinese voice');
    } else {
      _useWebTts = true;
      debugPrint('[TTS] No Chinese SAPI voice found, using Google Translate TTS');
    }
  }

  Future<void> _initMobile() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _useWebTts = false;

    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.isNotEmpty) {
        final offlineEngine = engines.firstWhere(
          (e) => e.toString().toLowerCase().contains('google') ||
                 e.toString().toLowerCase().contains('offline'),
          orElse: () => engines.first,
        );
        await _tts.setEngine(offlineEngine.toString());
      }
    } catch (_) {}
  }

  Future<void> speak(String hanzi) async {
    await _ensureInit();

    if (_useWebTts) {
      await _speakViaWeb(hanzi);
    } else {
      await _tts.stop();
      await _tts.speak(hanzi);
    }
  }

  Future<void> _speakViaWeb(String hanzi) async {
    try {
      await _audioPlayer.stop();
      final encoded = Uri.encodeComponent(hanzi);
      final url = 'https://translate.google.com/translate_tts'
          '?ie=UTF-8&tl=zh-CN&client=tw-ob&q=$encoded';
      debugPrint('[TTS] Web TTS URL: $url');
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('[TTS] Web TTS error: $e');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    await _audioPlayer.stop();
  }
}
