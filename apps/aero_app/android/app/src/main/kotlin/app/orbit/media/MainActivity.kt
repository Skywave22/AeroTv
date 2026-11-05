package app.orbit.media

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity.
 *
 * Exposes a tiny device channel so Dart can make a real TV detection instead of
 * guessing from screen size. Also declares the leanback launcher entry via the
 * manifest so the app appears on the Android TV home screen.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "tv.aero/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> result.success(isTelevision())
                    "model" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * UiModeManager is the authoritative check. The leanback feature check is a
     * fallback for Fire TV, which sometimes reports UI_MODE_TYPE_NORMAL.
     */
    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }
        return packageManager.hasSystemFeature("android.software.leanback") ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")
    }
}
