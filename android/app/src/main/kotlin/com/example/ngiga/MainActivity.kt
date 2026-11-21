package com.example.ngiga

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.Intent
import android.app.Activity
import io.flutter.plugin.common.MethodCall
import android.os.Build
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Environment
import android.net.Uri

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val saveRequestCode = 46071

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stockroom/reminders")
            .setMethodCallHandler { call, result ->
                if (call.method == "sync") {
                    @Suppress("UNCHECKED_CAST")
                    val loans = call.argument<List<Map<String, Any?>>>("loans") ?: emptyList()
                    LoanReminders.sync(this, loans, call.argument<Boolean>("silent") ?: false)
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(
                            android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 46072)
                    }
                    result.success(null)
                } else result.notImplemented()
            }
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
                    } else if (mimeType == "image/png" && Build.VERSION.SDK_INT >= 29) {
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                put(MediaStore.Images.Media.RELATIVE_PATH,
                                    Environment.DIRECTORY_PICTURES + "/NGIGA")
                            }
                            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                                values) ?: throw IllegalStateException("Gallery is unavailable")
                            try {
                                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                                    ?: throw IllegalStateException("Could not write image")
                            } catch (error: Exception) {
                                contentResolver.delete(uri, null, null)
                                throw error
                            }
                            result.success(true)
                            openSaved(uri, "image/png")
                        } catch (error: Exception) {
                            result.error("SAVE_FAILED", error.message, null)
                        }
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
            openSaved(data.data!!, contentResolver.getType(data.data!!) ?: "application/pdf")
        } catch (error: Exception) {
            result?.error("SAVE_FAILED", error.message, null)
        }
    }

    private fun openSaved(uri: Uri, mimeType: String) {
        try {
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(view, "Open receipt with"))
        } catch (_: Exception) {
            // The file was saved even if no viewer is installed.
        }
    }
}
