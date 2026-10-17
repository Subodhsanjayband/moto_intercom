import UIKit
import Flutter
import NetworkExtension

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  private let CHANNEL = "com.motocom.intercom/audio_and_network"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    methodChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
        
      case "startLocalHotspot":
        // iOS does not allow programmatically starting Personal Hotspot.
        // It prompts user or provides manual guidance, returning current hotspot IP.
        result([
          "ssid": "MotoCom-iOS-Hotspot",
          "passphrase": "",
          "ip": "172.20.10.1", // Standard iOS Personal Hotspot Gateway IP
          "port": 50005
        ])
        
      case "connectToHotspot":
        guard let args = call.arguments as? [String: Any],
              let ssid = args["ssid"] as? String,
              let passphrase = args["passphrase"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing SSID or Passphrase", details: nil))
          return
        }
        
        // Auto-join Rider's Wi-Fi Hotspot on iOS using NetworkExtension
        let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
        configuration.joinOnce = false
        
        NEHotspotConfigurationManager.shared.apply(configuration) { error in
          if let error = error {
            result(FlutterError(code: "CONNECT_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
        
      case "configureAudio":
        let args = call.arguments as? [String: Any]
        let enableDucking = args?["enableDucking"] as? Bool ?? true
        do {
          try MotoComAudioSession.shared.configureAudioSession(enableDucking: enableDucking)
          result(true)
        } catch {
          result(FlutterError(code: "AUDIO_CONFIG_FAILED", message: error.localizedDescription, details: nil))
        }
        
      case "startVoiceStreaming":
        do {
          try MotoComAudioSession.shared.startIntercom()
          result(true)
        } catch {
          result(FlutterError(code: "RECORD_FAILED", message: error.localizedDescription, details: nil))
        }
        
      case "stopVoiceStreaming":
        MotoComAudioSession.shared.stopIntercom()
        result(true)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
