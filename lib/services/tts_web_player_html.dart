import 'dart:html' as html;

html.AudioElement? _currentAudio;

Future<void> playGoogleTtsWeb(String url) async {
  _currentAudio?.pause();
  _currentAudio = html.AudioElement(url);
  await _currentAudio!.play();
}
