import 'dart:convert';

/// Data structure encoded inside the Rider's Pairing QR Code
class MotoComPairingData {
  final String ssid;
  final String passphrase;
  final String ip;
  final int port;
  final String deviceType; // "android" or "ios"

  MotoComPairingData({
    required this.ssid,
    required this.passphrase,
    required this.ip,
    required this.port,
    required this.deviceType,
  });

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'passphrase': passphrase,
      'ip': ip,
      'port': port,
      'deviceType': deviceType,
    };
  }

  String toJson() => json.encode(toMap());

  factory MotoComPairingData.fromMap(Map<String, dynamic> map) {
    return MotoComPairingData(
      ssid: map['ssid'] ?? '',
      passphrase: map['passphrase'] ?? '',
      ip: map['ip'] ?? '192.168.43.1',
      port: map['port']?.toInt() ?? 50005,
      deviceType: map['deviceType'] ?? 'unknown',
    );
  }

  factory MotoComPairingData.fromJson(String source) =>
      MotoComPairingData.fromMap(json.decode(source));
}
