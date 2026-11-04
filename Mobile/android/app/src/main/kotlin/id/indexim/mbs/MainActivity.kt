package id.indexim.mbs

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
    private val SECURITY_CHANNEL = "id.indexim.mbs/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkVpnNative" -> {
                    result.success(isVpnActiveNative())
                }
                "openVpnSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_VPN_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openDeveloperSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isVpnActiveNative(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val activeNetwork = cm.activeNetwork
                    if (activeNetwork != null) {
                        val caps = cm.getNetworkCapabilities(activeNetwork)
                        if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                            return true
                        }
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val networks = cm.allNetworks
                    for (network in networks) {
                        val caps = cm.getNetworkCapabilities(network)
                        if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                            return true
                        }
                    }
                }
            }

            // Fallback network interface check
            val interfaces = NetworkInterface.getNetworkInterfaces()
            if (interfaces != null) {
                for (iface in interfaces) {
                    val name = iface.name.lowercase()
                    if (iface.isUp && (name.contains("tun") || name.contains("tap") || name.contains("ppp") || name.contains("vpn") || name.contains("wg"))) {
                        return true
                    }
                }
            }
        } catch (_: Exception) {}
        return false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestSupportedRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighestSupportedRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun requestHighestSupportedRefreshRate() {
        val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        } ?: return

        val supportedRefreshRates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            currentDisplay.supportedModes.map { it.refreshRate }
        } else {
            currentDisplay.supportedRefreshRates.toList()
        }

        val preferredRefreshRate = supportedRefreshRates
            .filter { it <= MAX_REFRESH_RATE + REFRESH_RATE_TOLERANCE }
            .maxOrNull()
            ?: return

        val attributes = window.attributes
        attributes.preferredRefreshRate = preferredRefreshRate
        window.attributes = attributes
    }

    private companion object {
        const val MAX_REFRESH_RATE = 120f
        const val REFRESH_RATE_TOLERANCE = 0.5f
    }
}
