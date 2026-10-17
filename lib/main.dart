import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'intercom_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for motorcycle mounts
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MotoComApp());
}

class MotoComApp extends StatefulWidget {
  const MotoComApp({super.key});

  @override
  State<MotoComApp> createState() => _MotoComAppState();
}

class _MotoComAppState extends State<MotoComApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request essential riding permissions: Mic for Intercom, Camera for QR, Bluetooth for Helmet
    await [
      Permission.microphone,
      Permission.camera,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoCom Intercom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const IntercomScreen(),
    );
  }
}
