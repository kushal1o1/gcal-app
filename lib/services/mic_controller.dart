import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Owns speech-to-text for the whole app. The pill bar's center mic button and
/// the Home screen both observe this controller, so listening state and the
/// recognized text stay in one place regardless of which tab is active.
class MicController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();

  String text = '';
  bool listening = false;
  bool available = false;

  Future<void> init() async {
    available = await _speech.initialize();
    notifyListeners();
  }

  void setText(String value) {
    if (value == text) return;
    text = value;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (listening) {
      await stop();
      return;
    }
    if (!available) return;
    listening = true;
    notifyListeners();
    await _speech.listen(
      onResult: (result) {
        text = result.recognizedWords;
        notifyListeners();
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        listenMode: stt.ListenMode.confirmation,
      ),
    );
    listening = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _speech.stop();
    listening = false;
    notifyListeners();
  }
}