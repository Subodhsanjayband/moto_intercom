import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/qr_connection_model.dart';
import '../services/intercom_platform_service.dart';

class QrPairDialog extends StatefulWidget {
  final Function(MotoComPairingData pairingData, bool isHost) onConnected;

  const QrPairDialog({Key? key, required this.onConnected}) : super(key: key);

  @override
  State<QrPairDialog> createState() => _QrPairDialogState();
}

class _QrPairDialogState extends State<QrPairDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MotoComPairingData? hostPairingData;
  bool isGeneratingHost = true;
  bool isConnecting = false;
  String statusMessage = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initHostCredentials();
  }

  Future<void> _initHostCredentials() async {
    setState(() => isGeneratingHost = true);
    final data = await IntercomPlatformService.startLocalHotspot();
    setState(() {
      hostPairingData = data ??
          MotoComPairingData(
            ssid: "MotoCom-Direct",
            passphrase: "RiderPasscode2026",
            ip: "192.168.43.1",
            port: 50005,
            deviceType: "direct",
          );
      isGeneratingHost = false;
    });
  }

  void _onQrCodeScanned(BarcodeCapture capture) async {
    if (isConnecting) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          final data = MotoComPairingData.fromJson(barcode.rawValue!);
          setState(() {
            isConnecting = true;
            statusMessage = "Auto-joining ${data.ssid}...";
          });

          // Perform OS-level Wi-Fi Auto-Join (Android WifiNetworkSpecifier / iOS NEHotspotConfiguration)
          final success = await IntercomPlatformService.connectToHotspot(
            ssid: data.ssid,
            passphrase: data.passphrase,
          );

          if (success) {
            setState(() => statusMessage = "Connected! Starting voice intercom...");
            widget.onConnected(data, false);
            if (mounted) Navigator.of(context).pop();
          } else {
            setState(() {
              isConnecting = false;
              statusMessage = "Connection failed. Please scan again.";
            });
          }
          break;
        } catch (e) {
          // Not a MotoCom QR code, ignore
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 360,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code), text: "Rider (Host)"),
                Tab(icon: Icon(Icons.qr_code_scanner), text: "Pillion (Scan)"),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- TAB 1: RIDER QR GENERATOR ---
                  isGeneratingHost
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.amberAccent))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: hostPairingData!.toJson(),
                                version: QrVersions.auto,
                                size: 220.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "SSID: ${hostPairingData!.ssid}",
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Ask Pillion to scan this QR code to auto-join without cellular data.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),

                  // --- TAB 2: PILLION QR SCANNER ---
                  isConnecting
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Colors.greenAccent),
                              const SizedBox(height: 16),
                              Text(
                                statusMessage,
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              MobileScanner(
                                onDetect: _onQrCodeScanned,
                              ),
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.amberAccent, width: 2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "Point at Rider's QR Code",
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("CLOSE", style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
