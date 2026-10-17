import Foundation
import AVFoundation

/// MotoCom iOS Audio Session & Engine Manager
/// Configured specifically for:
/// 1. Motorcycle Helmet Bluetooth Headset (SCO / HFP + A2DP)
/// 2. YouTube Music Background Coexistence (duckOthers / mixWithOthers)
/// 3. Hardware Echo Cancellation (AEC) and Voice Chat mode
@objc public class MotoComAudioSession: NSObject {
    
    public static let shared = MotoComAudioSession()
    private let audioEngine = AVAudioEngine()
    private var isIntercomActive = false
    
    // Callback for outgoing voice packets
    public var onVoiceDataEncoded: ((Data) -> Void)?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    /// Configure the system AVAudioSession for simultaneous Helmet Bluetooth + Ducking
    public func configureAudioSession(enableDucking: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        
        var options: AVAudioSession.CategoryOptions = [
            .allowBluetooth,        // Allows Bluetooth hands-free (SCO) microphone from helmet
            .allowBluetoothA2DP     // Favors high-quality audio routing when available
        ]
        
        if enableDucking {
            // Tells iOS to automatically lower the volume of background apps (like YouTube Music)
            options.insert(.duckOthers)
        } else {
            // Allows YouTube Music to play simultaneously without lowering volume
            options.insert(.mixWithOthers)
        }
        
        // .voiceChat mode activates iOS hardware Acoustic Echo Cancellation (AEC) and AGC
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try session.setPreferredSampleRate(48000.0)
        try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for ultra-low latency
        try session.setActive(true, options: [])
    }
    
    /// Start capturing rider's voice from helmet mic
    public func startIntercom() throws {
        guard !isIntercomActive else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 960, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isIntercomActive = true
    }
    
    /// Stop voice capture
    public func stopIntercom() {
        guard isIntercomActive else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isIntercomActive = false
        
        // Deactivate session so background music returns to normal volume immediately
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS to determine if speaking (Noise Gate)
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20.0 * log10(max(rms, 0.00001))
        
        // Noise gate threshold: -35 dBFS (filters highway wind noise)
        if db > -35.0 {
            // Convert to 16-bit PCM for Opus encoding
            let pcmData = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
            self.onVoiceDataEncoded?(pcmData)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        // Check if helmet headset was disconnected or connected
        if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable {
            // Re-route audio gracefully
            try? configureAudioSession(enableDucking: true)
        }
    }
}
