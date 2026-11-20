package com.example.ngiga

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.Intent
import android.app.Activity
import io.flutter.plugin.common.MethodCall

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val saveRequestCode = 46071

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stockroom/files")
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method != "saveFile") {
                    result.notImplemented()
                } else if (pendingSave != null) {
                    result.error("SAVE_BUSY", "Another save is in progress", null)
                } else {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (bytes == null || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                        result.error("BAD_FILE", "Missing file details", null)
                    } else {
                        pendingSave = result
                        pendingBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        try {
                            startActivityForResult(intent, saveRequestCode)
                        } catch (error: Exception) {
                            pendingSave = null
                            pendingBytes = null
                            result.error("SAVE_FAILED", error.message, null)
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stockroom/app_icon")
            .setMethodCallHandler { call, result ->
                val icons = mapOf("violet" to "IconViolet", "silver" to "IconSilver",
                    "midnight" to "IconMidnight")
                when (call.method) {
                    "getIcon" -> {
                        val active = icons.entries.firstOrNull { (_, alias) ->
                            packageManager.getComponentEnabledSetting(
                                ComponentName(this, "$packageName.$alias")) ==
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        }?.key ?: "violet"
                        result.success(active)
                    }
                    "setIcon" -> {
                        val icon = call.argument<String>("icon")
                        if (!icons.containsKey(icon)) {
                            result.error("BAD_ICON", "Unknown icon choice", null)
                        } else {
                            try {
                                val selected = icons.getValue(icon!!)
                                packageManager.setComponentEnabledSetting(
                                    ComponentName(this, "$packageName.$selected"),
                                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                    PackageManager.DONT_KILL_APP)
                                icons.values.filter { it != selected }.forEach { alias ->
                                    packageManager.setComponentEnabledSetting(
                                        ComponentName(this, "$packageName.$alias"),
                                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                        PackageManager.DONT_KILL_APP)
                                }
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("ICON_CHANGE_FAILED", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequestCode) return
        val result = pendingSave
        val bytes = pendingBytes
        pendingSave = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(data.data!!)?.use { stream ->
                stream.write(bytes ?: ByteArray(0))
            } ?: throw IllegalStateException("Could not open the selected file")
            result?.success(true)
        } catch (error: Exception) {
            result?.error("SAVE_FAILED", error.message, null)
        }
    }
}
