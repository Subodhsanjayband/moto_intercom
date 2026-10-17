import 'dart:io';
import 'package:flutter/services.dart';
import 'qr_connection_model.dart';

class IntercomPlatformService {
  static const MethodChannel _channel =
      MethodChannel('com.motocom.intercom/audio_and_network');

  /// Start local Wi-Fi Hotspot on Rider's phone (returns credentials for QR)
  static Future<MotoComPairingData?> startLocalHotspot() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('startLocalHotspot');
      if (result != null) {
        return MotoComPairingData(
          ssid: result['ssid'] as String? ?? 'MotoCom-Direct',
          passphrase: result['passphrase'] as String? ?? 'Rider2026',
          ip: result['ip'] as String? ?? (Platform.isIOS ? '172.20.10.1' : '192.168.43.1'),
          port: (result['port'] as int?) ?? 50005,
          deviceType: Platform.isAndroid ? 'android' : 'ios',
        );
      }
    } on PlatformException catch (e) {
      print("Error starting hotspot: ${e.message}");
    }
    return null;
  }

  /// Pillion phone calls this after scanning QR to auto-connect to the Hotspot
  static Future<bool> connectToHotspot({
    required String ssid,
    required String passphrase,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod('connectToHotspot', {
        'ssid': ssid,
        'passphrase': passphrase,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Error auto-joining hotspot: ${e.message}");
      return false;
    }
  }

  /// Configures helmet Bluetooth headset and YouTube Music ducking
  static Future<bool> configureAudio({required bool enableDucking}) async {
    try {
      final bool? success = await _channel.invokeMethod('configureAudio', {
        'enableDucking': enableDucking,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Error configuring audio: ${e.message}");
      return false;
    }
  }

  /// Starts voice streaming over UDP to peer's IP & port
  static Future<bool> startVoiceStreaming({
    required String ip,
    required int port,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod('startVoiceStreaming', {
        'ip': ip,
        'port': port,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Error starting voice stream: ${e.message}");
      return false;
    }
  }

  /// Stops voice streaming and restores music volume
  static Future<void> stopVoiceStreaming() async {
    try {
      await _channel.invokeMethod('stopVoiceStreaming');
    } on PlatformException catch (e) {
      print("Error stopping voice stream: ${e.message}");
    }
  }
}
