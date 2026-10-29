package cn.local.qqa.qqa_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qqa/core",
        ).setMethodCallHandler { call, result ->
            try {
                result.success(QqaCore.handle(call.method, call.arguments))
            } catch (error: QqaCore.RuleException) {
                result.error("rule", error.message, null)
            } catch (error: Throwable) {
                result.error("core", error.toString(), null)
            }
        }
    }
}
