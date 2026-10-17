package com.motocom.intercom

import android.content.Context
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import kotlin.concurrent.thread

/**
 * MotoCom Android Engine:
 * 1. Programmatic Local-Only Wi-Fi Hotspot (No Internet / No Mobile Data required)
 * 2. Bluetooth Helmet Headset Audio Routing (SCO Mode)
 * 3. YouTube Music Audio Ducking via Transient Focus
 * 4. Hardware Echo Cancellation & Noise Suppression
 */
class MotoComAndroidEngine(private val context: Context) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var socket: DatagramSocket? = null
    private var peerAddress: InetAddress? = null
    private var peerPort = 50005
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null

    // Audio focus request to duck YouTube Music when intercom is talking
    private var audioFocusRequest: AudioFocusRequest? = null

    // --- 1. OFFLINE WI-FI HOTSPOT (Android Host) ---
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
                    
                    onHotspotReady(ssid, password)
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                }
            }, Handler(Looper.getMainLooper()))
        }
    }

    // --- 2. BLUETOOTH HELMET AUDIO ROUTING & DUCKING ---
    fun startAudioSession(enableDucking: Boolean = true) {
        // Set mode to communication for VoIP / Intercom
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        // Modern API 31+ communication device routing with fallback to SCO
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

            // Request focus: This causes YouTube Music to drop its volume automatically!
            audioManager.requestAudioFocus(audioFocusRequest!!)
        }
    }

    // --- 3. LOW LATENCY VOICE RECORDING WITH HARDWARE AEC ---
    fun startVoiceStreaming(destinationIp: String, destinationPort: Int) {
        peerAddress = InetAddress.getByName(destinationIp)
        peerPort = destinationPort
        socket = DatagramSocket()

        val sampleRate = 48000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION, // Activates built-in mic DSP
            sampleRate,
            channelConfig,
            audioFormat,
            bufferSize
        )

        // Attach hardware Acoustic Echo Canceler and Noise Suppressor if supported
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

            while (isRecording) {
                val readCount = audioRecord?.read(audioBuffer, 0, audioBuffer.size) ?: 0
                if (readCount > 0) {
                    // Check RMS for noise gate
                    var sum = 0.0
                    for (i in 0 until readCount) {
                        sum += audioBuffer[i] * audioBuffer[i]
                        // Convert short to little-endian bytes
                        byteBuffer[i * 2] = (audioBuffer[i].toInt() and 0xFF).toByte()
                        byteBuffer[i * 2 + 1] = ((audioBuffer[i].toInt() shr 8) and 0xFF).toByte()
                    }
                    val rms = Math.sqrt(sum / readCount)
                    val db = 20.0 * Math.log10(Math.max(rms, 0.00001) / 32767.0)

                    // Filter out wind noise below -35 dBFS
                    if (db > -35.0) {
                        val packet = DatagramPacket(byteBuffer, readCount * 2, peerAddress, peerPort)
                        socket?.send(packet)
                    }
                }
            }
        }
    }

    fun stopVoiceStreaming() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        socket?.close()

        // Release audio focus so YouTube Music volume restores back to 100%
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
}
