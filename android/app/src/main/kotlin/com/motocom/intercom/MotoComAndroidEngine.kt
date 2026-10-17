package com.motocom.intercom

import android.content.Context
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketException
import kotlin.concurrent.thread

/**
 * MotoCom Android Engine:
 * 1. Programmatic Local-Only Wi-Fi Hotspot (No Mobile Data needed)
 * 2. Full-Duplex Bidirectional Audio: AudioRecord (TX) + AudioTrack (RX)
 * 3. Bluetooth Helmet Headset Audio Routing (API 31+ CommunicationDevice & SCO fallback)
 * 4. YouTube Music Audio Ducking via Transient Focus
 * 5. Hardware Echo Cancellation & Noise Suppression
 */
class MotoComAndroidEngine(private val context: Context) {

    private val TAG = "MotoComEngine"
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isRecording = false
    private var isReceiving = false

    private var socket: DatagramSocket? = null
    @Volatile private var peerAddress: InetAddress? = null
    @Volatile private var peerPort = 50005
    private val localPort = 50005

    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    // --- 1. OFFLINE WI-FI HOTSPOT (Rider / Host) ---
    fun startLocalHotspot(onHotspotReady: (ssid: String, passphrase: String) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    super.onStarted(reservation)
                    hotspotReservation = reservation
                    
                    val ssid: String
                    val password: String
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val softApConfig = reservation.softApConfiguration
                        ssid = softApConfig?.ssid ?: "MotoCom_Direct"
                        password = softApConfig?.passphrase ?: "RiderPillion2026"
                    } else {
                        @Suppress("DEPRECATION")
                        val config = reservation.wifiConfiguration
                        @Suppress("DEPRECATION")
                        ssid = config?.SSID ?: "MotoCom_Direct"
                        @Suppress("DEPRECATION")
                        password = config?.preSharedKey ?: "RiderPillion2026"
                    }
                    
                    // Host immediately starts listening on port 50005 for Pillion's handshake
                    startAudioReceiver(localPort)
                    startAudioSession(enableDucking = true)

                    onHotspotReady(ssid, password)
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                    Log.e(TAG, "Hotspot creation failed with code: $reason")
                }
            }, Handler(Looper.getMainLooper()))
        }
    }

    // --- 2. BLUETOOTH HELMET AUDIO ROUTING & YOUTUBE MUSIC DUCKING ---
    fun startAudioSession(enableDucking: Boolean = true) {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val devices = audioManager.availableCommunicationDevices
            val btDevice = devices.firstOrNull { 
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLE_HEADSET 
            }
            if (btDevice != null) {
                audioManager.setCommunicationDevice(btDevice)
            } else {
                @Suppress("DEPRECATION")
                audioManager.startBluetoothSco()
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = true
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.startBluetoothSco()
            @Suppress("DEPRECATION")
            audioManager.isBluetoothScoOn = true
        }

        if (enableDucking && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusType = AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            audioFocusRequest = AudioFocusRequest.Builder(focusType)
                .setAudioAttributes(attributes)
                .setAcceptsDelayedFocusGain(true)
                .build()

            audioManager.requestAudioFocus(audioFocusRequest!!)
        }
    }

    // --- 3. FULL-DUPLEX AUDIO RECEIVER (AudioTrack) ---
    private fun startAudioReceiver(port: Int) {
        if (isReceiving) return
        
        try {
            if (socket == null || socket!!.isClosed) {
                socket = DatagramSocket(port)
                socket?.reuseAddress = true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not bind DatagramSocket to port $port: ${e.message}")
            try {
                socket = DatagramSocket() // Fallback to available port
            } catch (ex: Exception) {}
        }

        val sampleRate = 48000
        val channelConfig = AudioFormat.CHANNEL_OUT_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, audioFormat)

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(audioFormat)
                .setSampleRate(sampleRate)
                .setChannelMask(channelConfig)
                .build())
            .setBufferSizeInBytes(minBufferSize.coerceAtLeast(1920))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
        isReceiving = true

        thread(start = true, name = "MotoComAudioRx") {
            val receiveBuffer = ByteArray(960) // 10ms PCM audio frame
            val packet = DatagramPacket(receiveBuffer, receiveBuffer.size)
            
            Log.i(TAG, "MotoComAudioRx listening on port ${socket?.localPort}...")
            
            while (isReceiving) {
                try {
                    socket?.receive(packet)
                    
                    // Auto-learn peer address from incoming packet
                    if (peerAddress == null) {
                        peerAddress = packet.address
                        peerPort = packet.port
                        Log.i(TAG, "Discovered peer at ${peerAddress?.hostAddress}:$peerPort")
                    }

                    // Play received audio through helmet speaker or phone speaker
                    if (packet.length > 0) {
                        audioTrack?.write(packet.data, packet.offset, packet.length)
                    }
                } catch (e: SocketException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "AudioRx error: ${e.message}")
                }
            }
        }
    }

    // --- 4. FULL-DUPLEX AUDIO TRANSMITTER (AudioRecord) ---
    fun startVoiceStreaming(destinationIp: String, destinationPort: Int) {
        peerAddress = InetAddress.getByName(destinationIp)
        peerPort = destinationPort

        // Start receiver so this device can also hear the other person
        startAudioReceiver(localPort)
        startAudioSession(enableDucking = true)

        if (isRecording) return

        val sampleRate = 48000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate,
            channelConfig,
            audioFormat,
            bufferSize
        )

        // Attach hardware echo canceler and noise suppressor
        val audioSessionId = audioRecord!!.audioSessionId
        if (AcousticEchoCanceler.isAvailable()) {
            AcousticEchoCanceler.create(audioSessionId)?.enabled = true
        }
        if (NoiseSuppressor.isAvailable()) {
            NoiseSuppressor.create(audioSessionId)?.enabled = true
        }

        audioRecord?.startRecording()
        isRecording = true

        thread(start = true, name = "MotoComAudioTx") {
            val audioBuffer = ShortArray(480) // 10ms frame at 48kHz
            val byteBuffer = ByteArray(960)

            Log.i(TAG, "MotoComAudioTx transmitting to $destinationIp:$destinationPort...")

            while (isRecording) {
                val readCount = audioRecord?.read(audioBuffer, 0, audioBuffer.size) ?: 0
                if (readCount > 0) {
                    var sum = 0.0
                    for (i in 0 until readCount) {
                        sum += audioBuffer[i] * audioBuffer[i]
                        byteBuffer[i * 2] = (audioBuffer[i].toInt() and 0xFF).toByte()
                        byteBuffer[i * 2 + 1] = ((audioBuffer[i].toInt() shr 8) and 0xFF).toByte()
                    }
                    val rms = Math.sqrt(sum / readCount)
                    val db = 20.0 * Math.log10(Math.max(rms, 0.00001) / 32767.0)

                    // Wind noise gate: transmit if above -35 dBFS
                    if (db > -35.0 && peerAddress != null) {
                        try {
                            val packet = DatagramPacket(byteBuffer, readCount * 2, peerAddress, peerPort)
                            socket?.send(packet)
                        } catch (e: Exception) {
                            Log.e(TAG, "Tx send error: ${e.message}")
                        }
                    }
                }
            }
        }
    }

    fun stopVoiceStreaming() {
        isRecording = false
        isReceiving = false

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null

        socket?.close()
        socket = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
            audioManager.abandonAudioFocusRequest(audioFocusRequest!!)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        }
        @Suppress("DEPRECATION")
        audioManager.stopBluetoothSco()
        @Suppress("DEPRECATION")
        audioManager.isBluetoothScoOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    // --- 5. AUDIO SPEAKER DIAGNOSTIC TEST TONE ---
    fun playTestTone() {
        thread(start = true) {
            try {
                val sampleRate = 48000
                val numSamples = sampleRate / 2 // 0.5s tone at 440Hz
                val buffer = ShortArray(numSamples)
                for (i in 0 until numSamples) {
                    val angle = 2.0 * Math.PI * i * 440.0 / sampleRate
                    buffer[i] = (Math.sin(angle) * 20000).toInt().toShort()
                }
                val track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()
                track.write(buffer, 0, buffer.size)
                track.play()
            } catch (e: Exception) {
                Log.e(TAG, "Test tone failed: ${e.message}")
            }
        }
    }
}
