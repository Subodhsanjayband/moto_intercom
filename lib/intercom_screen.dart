import 'package:flutter/material.dart';
import 'widgets/qr_pair_dialog.dart';
import 'services/intercom_platform_service.dart';

/// MotoCom Rider/Pillion Main Screen
/// Designed specifically for motorcycle riding with gloves:
/// - Visual Rider ⇄ Pillion connection bridge indicator
/// - High-contrast dark theme (OLED readable in bright sunlight)
/// - Huge tap targets (>64dp)
/// - Direct YouTube Music ducking control
class IntercomScreen extends StatefulWidget {
  const IntercomScreen({super.key});

  @override
  State<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends State<IntercomScreen> {
  bool isConnected = false;
  bool isRiderHost = true;
  bool isOpenMic = true;
  bool isTalking = false;
  
  double noiseGateThreshold = -32.0; // dBFS
  double intercomVolume = 0.85;
  double duckingLevel = 0.25; // 25% background YouTube Music volume when talking
  int pingMs = 0;

  void _openQrPairingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => QrPairDialog(
        onConnected: (pairingData, isHost) {
          setState(() {
            isConnected = true;
            isRiderHost = isHost;
            pingMs = 12;
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
  }

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
              isRiderHost ? "MOTOCOM • RIDER" : "MOTOCOM • PILLION",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isConnected ? Colors.greenAccent : Colors.redAccent),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? "Connected • ${pingMs}ms" : "Offline",
                  style: TextStyle(
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
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
              // --- 1. VISUAL RIDER ⇄ PILLION CONNECTION BRIDGE ---
              _buildVisualLinkBanner(),

              const SizedBox(height: 12),

              // --- 2. BIG TRANSMIT / PAIR BUTTON (Glove Friendly) ---
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: isConnected ? null : () => _openQrPairingDialog(context),
                  onTapDown: (!isConnected || isOpenMic) ? null : (_) => setState(() => isTalking = true),
                  onTapUp: (!isConnected || isOpenMic) ? null : (_) => setState(() => isTalking = false),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: !isConnected
                            ? [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)]
                            : (isTalking
                                ? [Colors.redAccent, const Color(0xFFB71C1C)]
                                : [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]),
                        radius: 0.85,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: !isConnected
                            ? Colors.amberAccent.withOpacity(0.6)
                            : (isTalking ? Colors.redAccent : Colors.greenAccent),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (!isConnected
                                  ? Colors.amberAccent
                                  : (isTalking ? Colors.redAccent : Colors.green))
                              .withOpacity(isConnected ? 0.4 : 0.15),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !isConnected
                              ? Icons.qr_code_scanner
                              : (isOpenMic
                                  ? (isTalking ? Icons.mic : Icons.mic_none)
                                  : (isTalking ? Icons.mic : Icons.touch_app)),
                          size: 72,
                          color: !isConnected ? Colors.amberAccent : Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          !isConnected
                              ? "TAP TO PAIR INTERCOM"
                              : (isOpenMic
                                  ? (isTalking ? "MIC ACTIVE (TALKING)" : "OPEN MIC (VOX READY)")
                                  : (isTalking ? "TRANSMITTING (PTT)" : "HOLD TO TALK")),
                          style: TextStyle(
                            color: !isConnected ? Colors.amberAccent : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          !isConnected
                              ? "Scan Rider's QR code to link without data"
                              : (isOpenMic
                                  ? "Auto-triggers on voice • Wind noise filtered"
                                  : "Press and hold to speak"),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- 3. CONTROLS CARD ---
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

              // --- 4. BOTTOM QUICK ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? const Color(0xFF2C2C2C) : Colors.amber.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _openQrPairingDialog(context),
                      icon: Icon(
                        Icons.qr_code,
                        color: isConnected ? Colors.amberAccent : Colors.white,
                      ),
                      label: Text(
                        isConnected ? "RE-PAIR QR" : "PAIR QR",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
                        IntercomPlatformService.playTestTone();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(milliseconds: 800),
                            backgroundColor: Colors.purple,
                            content: Text("Playing audio diagnostic test tone..."),
                          ),
                        );
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

  // --- VISUAL CONNECTION BRIDGE WIDGET ---
  Widget _buildVisualLinkBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isConnected
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Rider Avatar Card
          _buildPeerAvatar(
            title: "RIDER",
            role: isRiderHost ? "YOU (HOST)" : "PEER",
            icon: Icons.two_wheeler,
            color: Colors.amberAccent,
            isOnline: isConnected || isRiderHost,
          ),

          // Dynamic Connecting Bridge Beam
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isConnected ? Icons.link : Icons.link_off,
                        size: 16,
                        color: isConnected ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isConnected ? "DIRECT LINK ACTIVE" : "NOT CONNECTED",
                        style: TextStyle(
                          color: isConnected ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Beam line
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.greenAccent : Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: isConnected
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      // Center Icon Pill
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.green : const Color(0xFF333333),
                          border: Border.all(
                            color: isConnected ? Colors.greenAccent : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isConnected ? Icons.wifi : Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pillion Avatar Card
          _buildPeerAvatar(
            title: "PILLION",
            role: isRiderHost ? "PEER" : "YOU",
            icon: Icons.person_pin,
            color: Colors.cyanAccent,
            isOnline: isConnected,
          ),
        ],
      ),
    );
  }

  Widget _buildPeerAvatar({
    required String title,
    required String role,
    required IconData icon,
    required Color color,
    required bool isOnline,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOnline ? color.withOpacity(0.15) : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(
              color: isOnline ? color : Colors.white24,
              width: 2,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 28,
            color: isOnline ? color : Colors.white38,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isOnline ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          role,
          style: TextStyle(
            color: isOnline ? color : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
