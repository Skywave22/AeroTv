package app.orbit.media

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

/**
 * Host activity.
 *
 * Exposes a tiny device channel so Dart can make a real TV detection instead of
 * guessing from screen size. Also declares the leanback launcher entry via the
 * manifest so the app appears on the Android TV home screen.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "tv.aero/device"
    private val linkChannelName = "tv.aero/deeplink"

    /** Set when a VIEW intent arrives before Dart is ready to receive it. */
    private var pendingLink: String? = null
    private var linkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, linkChannelName)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Dart asks for the launch link once it has a router.
                        "consumeInitialLink" -> {
                            result.success(pendingLink)
                            pendingLink = null
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        captureLink(intent)

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

    /** A link arriving while the app is already running. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLink(intent)
    }

    /**
     * Forwards VIEW intent data to Dart. Only the schemes we actually handle
     * are passed on, so an unrelated intent cannot drive navigation.
     */
    private fun captureLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val data = intent.dataString ?: return
        if (!data.startsWith("stremio://") && !data.startsWith("aerotv://")) return
        val channel = linkChannel
        if (channel == null) {
            pendingLink = data
        } else {
            channel.invokeMethod("onLink", data)
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
