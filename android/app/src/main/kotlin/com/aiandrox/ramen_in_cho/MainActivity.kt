package com.aiandrox.ramen_in_cho

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.aiandrox.ramen_in_cho/system_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openNotificationSettings") {
                startActivity(notificationSettingsIntent())
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun notificationSettingsIntent(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
}
