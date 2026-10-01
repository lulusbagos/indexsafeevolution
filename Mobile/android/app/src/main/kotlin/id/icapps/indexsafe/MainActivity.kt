package id.icapps.indexsafe

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
