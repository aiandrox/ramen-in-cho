package com.aiandrox.ramen_in_cho

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.aiandrox.ramen_in_cho/shared_photo",
        ).setMethodCallHandler { call, result ->
            if (call.method == "takeSharedPhoto") {
                result.success(SharedPhotoInbox.take())
            } else {
                result.notImplemented()
            }
        }
    }
}
