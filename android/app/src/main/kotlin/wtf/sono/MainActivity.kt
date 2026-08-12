package wtf.sono

import android.app.ActivityManager
import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    // Kill cached engine so mpv cannot retain a dead isolate callback
    // object callback prevents duplicate registration on reattach
    private object ProcessKiller : FlutterEngine.EngineLifecycleListener {
        override fun onPreEngineRestart() {}

        override fun onEngineWillDestroy() {
            // post so AudioService can finish cleanup before process exists
            Handler(Looper.getMainLooper()).post {
                Process.killProcess(Process.myPid())
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.addEngineLifecycleListener(ProcessKiller)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "wtf.sono/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryInfo") {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val info = ActivityManager.MemoryInfo()
                am.getMemoryInfo(info)
                result.success(
                    mapOf(
                        "isLowRamDevice" to am.isLowRamDevice,
                        "totalMem" to info.totalMem,
                        "memoryClass" to am.memoryClass,
                    ),
                )
            } else {
                result.notImplemented()
            }
        }
    }
}
