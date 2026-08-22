import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages for the driver app's voice announcements.
enum DriverLanguage {
  english('en', 'en-US', 'English'),
  tamil('ta', 'ta-IN', 'தமிழ்'),
  hindi('hi', 'hi-IN', 'हिंदी'),
  telugu('te', 'te-IN', 'తెలుగు'),
  malayalam('ml', 'ml-IN', 'മലയാളം'),
  kannada('kn', 'kn-IN', 'ಕನ್ನಡ');

  final String code;
  final String ttsLocale;
  final String displayName;
  const DriverLanguage(this.code, this.ttsLocale, this.displayName);

  static DriverLanguage fromCode(String? code) {
    return DriverLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => DriverLanguage.english,
    );
  }
}

/// Provider for the driver's selected language preference.
final driverLanguageProvider =
    StateNotifierProvider<DriverLanguageNotifier, DriverLanguage>(
        (ref) => DriverLanguageNotifier());

class DriverLanguageNotifier extends StateNotifier<DriverLanguage> {
  static const _prefsKey = 'driver_language_code';

  DriverLanguageNotifier() : super(DriverLanguage.english) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      state = DriverLanguage.fromCode(code);
    } catch (_) {
      // Defaults to English
    }
  }

  Future<void> setLanguage(DriverLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.code);
    } catch (_) {}
  }
}

/// Provider for the TTS service.
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService(ref.read(driverLanguageProvider.notifier));
});

/// Text-to-Speech service for voice-assisted dispatch announcements.
///
/// When a new ride or delivery offer arrives via SignalR, the driver
/// app announces the pickup location and fare aloud in the driver's
/// selected language. This increases acceptance rates while driving
/// without requiring the driver to look at the screen.
class TtsService {
  final DriverLanguageNotifier _languageNotifier;
  FlutterTts? _tts;
  bool _enabled = true;

  TtsService(this._languageNotifier);

  FlutterTts get _engine {
    _tts ??= FlutterTts();
    return _tts!;
  }

  /// Initializes the TTS engine and sets the language.
  Future<void> init() async {
    try {
      await _engine.setSpeechRate(0.45);
      await _engine.setVolume(1.0);
      await _engine.setPitch(1.0);
      await _setLanguage();
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  Future<void> _setLanguage() async {
    final locale = _languageNotifier.state.ttsLocale;
    try {
      await _engine.setLanguage(locale);
    } catch (e) {
      // Fallback to English if the language is not available
      if (kDebugMode) debugPrint('TTS language $locale not available: $e');
      try {
        await _engine.setLanguage('en-US');
      } catch (_) {}
    }
  }

  /// Enables or disables voice announcements.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  /// Stops any current speech.
  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {}
  }

  /// Announces a new ride offer in the driver's selected language.
  ///
  /// Example in Tamil: "புதிய சவாரி. பிக்-அப்: ஒயிட் டவுன். கட்டணம்: ₹85"
  /// Example in English: "New ride. Pickup: White Town. Fare: ₹85"
  Future<void> announceRideOffer({
    required String pickupAddress,
    required double fare,
    required String vehicleType,
    bool isSos = false,
  }) async {
    if (!_enabled) return;

    await _setLanguage();

    final message = _buildRideAnnouncement(
      pickupAddress: pickupAddress,
      fare: fare,
      vehicleType: vehicleType,
      isSos: isSos,
    );

    try {
      await _engine.speak(message);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
    }
  }

  /// Announces a new food delivery offer.
  Future<void> announceFoodDeliveryOffer({
    required String storeName,
    required double earnings,
  }) async {
    if (!_enabled) return;

    await _setLanguage();

    final message = _buildFoodDeliveryAnnouncement(
      storeName: storeName,
      earnings: earnings,
    );

    try {
      await _engine.speak(message);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
    }
  }

  String _buildRideAnnouncement({
    required String pickupAddress,
    required double fare,
    required String vehicleType,
    required bool isSos,
  }) {
    final lang = _languageNotifier.state;

    switch (lang) {
      case DriverLanguage.tamil:
        final prefix = isSos ? 'அவசர சவாரி! ' : 'புதிய சவாரி. ';
        return '$prefixபிக்-அப்: $pickupAddress. கட்டணம்: ₹${fare.toStringAsFixed(0)}';
      case DriverLanguage.hindi:
        final prefix = isSos ? 'आपातकालीन सवारी! ' : 'नई सवारी. ';
        return '$prefixपिकअप: $pickupAddress. किराया: ₹${fare.toStringAsFixed(0)}';
      case DriverLanguage.telugu:
        final prefix = isSos ? 'అత్యవసర రైడ్! ' : 'కొత్త రైడ్. ';
        return '$prefixపికప్: $pickupAddress. ఛార్జ్: ₹${fare.toStringAsFixed(0)}';
      case DriverLanguage.malayalam:
        final prefix = isSos ? 'അടിയന്തര റൈഡ്! ' : 'പുതിയ റൈഡ്. ';
        return '$prefixപിക്കപ്പ്: $pickupAddress. നിരക്ക്: ₹${fare.toStringAsFixed(0)}';
      case DriverLanguage.kannada:
        final prefix = isSos ? 'ತುರ್ತು ಸವಾರಿ! ' : 'ಹೊಸ ಸವಾರಿ. ';
        return '$prefixಪಿಕಪ್: $pickupAddress. ಶುಲ್ಕ: ₹${fare.toStringAsFixed(0)}';
      case DriverLanguage.english:
        final prefix = isSos ? 'Emergency ride! ' : 'New ride. ';
        return '$prefix Pickup: $pickupAddress. Fare: ₹${fare.toStringAsFixed(0)}';
    }
  }

  String _buildFoodDeliveryAnnouncement({
    required String storeName,
    required double earnings,
  }) {
    final lang = _languageNotifier.state;

    switch (lang) {
      case DriverLanguage.tamil:
        return 'புதிய டெலிவரி. கடை: $storeName. வருமானம்: ₹${earnings.toStringAsFixed(0)}';
      case DriverLanguage.hindi:
        return 'नई डिलीवरी. स्टोर: $storeName. कमाई: ₹${earnings.toStringAsFixed(0)}';
      case DriverLanguage.telugu:
        return 'కొత్త డెలివరీ. స్టోర్: $storeName. సంపాదన: ₹${earnings.toStringAsFixed(0)}';
      case DriverLanguage.malayalam:
        return 'പുതിയ ഡെലിവറി. സ്റ്റോർ: $storeName. വരുമാനം: ₹${earnings.toStringAsFixed(0)}';
      case DriverLanguage.kannada:
        return 'ಹೊಸ ಡೆಲಿವರಿ. ಸ್ಟೋರ್: $storeName. ಆದಾಯ: ₹${earnings.toStringAsFixed(0)}';
      case DriverLanguage.english:
        return 'New delivery. Store: $storeName. Earnings: ₹${earnings.toStringAsFixed(0)}';
    }
  }

  /// Disposes the TTS engine.
  void dispose() {
    _tts?.stop();
  }
}
