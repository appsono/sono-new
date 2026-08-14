package wtf.sono

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "wtf.sono/device"
private const val EXIT_RECORDS = 16
private const val TRACE_CHARS = 12000

class MainActivity : AudioServiceActivity() {
    // Kill cached engine so mpv cannot retain a dead isolate callback
    // object callback prevents duplicate registration on reattach
    private object ProcessKiller : FlutterEngine.EngineLifecycleListener {
        override fun onPreEngineRestart() {}

        override fun onEngineWillDestroy() {
            Handler(Looper.getMainLooper()).postDelayed({
                val state = ActivityManager.RunningAppProcessInfo()
                ActivityManager.getMyMemoryState(state)
                val fgs = ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE
                if (state.importance <= fgs) return@postDelayed
                Process.killProcess(Process.myPid())
            }, 300)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.addEngineLifecycleListener(ProcessKiller)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMemoryInfo" -> result.success(memoryInfo())
                    "getDeviceInfo" -> result.success(deviceInfo())
                    "getExitReasons" -> result.success(exitReasons())
                    else -> result.notImplemented()
                }
            }
    }

    private fun activityManager() =
        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    private fun memoryInfo(): Map<String, Any?> {
        val am = activityManager()
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return mapOf(
            "isLowRamDevice" to am.isLowRamDevice,
            "totalMem" to info.totalMem,
            "memoryClass" to am.memoryClass,
        )
    }

    // background restriction and doze exemption decide whether an OEM
    // battery manager is allowed to reap a foreground service at all
    private fun deviceInfo(): Map<String, Any?> {
        val am = activityManager()
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "androidRelease" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "fingerprint" to Build.FINGERPRINT,
            "isLowRamDevice" to am.isLowRamDevice,
            "totalMem" to info.totalMem,
            "memoryClass" to am.memoryClass,
            "largeMemoryClass" to am.largeMemoryClass,
            "backgroundRestricted" to
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    am.isBackgroundRestricted
                } else {
                    null
                },
            "ignoringBatteryOptimizations" to
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    power.isIgnoringBatteryOptimizations(packageName)
                } else {
                    null
                },
        )
    }

    private fun exitReasons(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        val am = activityManager()
        return am.getHistoricalProcessExitReasons(packageName, 0, EXIT_RECORDS).map { i ->
            mapOf(
                "timestamp" to i.timestamp,
                "pid" to i.pid,
                "processName" to i.processName,
                "reason" to i.reason,
                "status" to i.status,
                "importance" to i.importance,
                "pss" to i.pss,
                "rss" to i.rss,
                "description" to i.description,
                "trace" to runCatching {
                    i.traceInputStream?.bufferedReader()?.use {
                        it.readText().take(TRACE_CHARS)
                    }
                }.getOrNull(),
            )
        }
    }
}
