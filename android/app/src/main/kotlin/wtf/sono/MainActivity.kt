package wtf.sono

import android.app.ActivityManager
import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
