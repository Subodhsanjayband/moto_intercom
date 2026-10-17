package com.motocom.intercom

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.motocom.intercom/audio_and_network"
    private lateinit var engine: MotoComAndroidEngine
    private var connectivityManager: ConnectivityManager? = null
    private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = MotoComAndroidEngine(this)
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Host calls this to turn on Wi-Fi hotspot and get credentials for QR
                "startLocalHotspot" -> {
                    engine.startLocalHotspot { ssid, passphrase ->
                        result.success(mapOf(
                            "ssid" to ssid,
                            "passphrase" to passphrase,
                            "ip" to "192.168.43.1",
                            "port" to 50005
                        ))
                    }
                }

                // Client calls this after scanning QR code to auto-join the Rider's hotspot
                "connectToHotspot" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val passphrase = call.argument<String>("passphrase") ?: ""

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val specifier = WifiNetworkSpecifier.Builder()
                            .setSsid(ssid)
                            .setWpa2Passphrase(passphrase)
                            .build()

                        val request = NetworkRequest.Builder()
                            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) // Crucial: Allows connection with NO cellular/internet!
                            .setNetworkSpecifier(specifier)
                            .build()

                        activeNetworkCallback = object : ConnectivityManager.NetworkCallback() {
                            override fun onAvailable(network: Network) {
                                connectivityManager?.bindProcessToNetwork(network)
                                runOnUiThread { result.success(true) }
                            }

                            override fun onUnavailable() {
                                runOnUiThread { result.error("CONNECT_FAIL", "Failed to auto-join hotspot", null) }
                            }
                        }

                        connectivityManager?.requestNetwork(request, activeNetworkCallback!!)
                    } else {
                        // For older Android versions
                        result.success(true)
                    }
                }

                // Configure helmet audio and YouTube Music ducking
                "configureAudio" -> {
                    val enableDucking = call.argument<Boolean>("enableDucking") ?: true
                    engine.startAudioSession(enableDucking)
                    result.success(true)
                }

                "startVoiceStreaming" -> {
                    val ip = call.argument<String>("ip") ?: "192.168.43.1"
                    val port = call.argument<Int>("port") ?: 50005
                    engine.startVoiceStreaming(ip, port)
                    result.success(true)
                }

                "stopVoiceStreaming" -> {
                    engine.stopVoiceStreaming()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        activeNetworkCallback?.let {
            connectivityManager?.unregisterNetworkCallback(it)
        }
        engine.stopVoiceStreaming()
    }
}
