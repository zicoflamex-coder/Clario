package com.zico.clario

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.pm.PackageManager
import android.provider.OpenableColumns
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pending: MethodChannel.Result? = null
    private var pendingText: String = ""
    private val icons = listOf("blue", "green", "purple", "dark")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clario/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val at = (call.argument<Number>("at") ?: 0).toLong()
                        val title = call.argument<String>("title") ?: ""
                        AlarmUtil.schedule(this, id, at, title)
                        result.success(true)
                    }
                    "cancel" -> {
                        AlarmUtil.cancel(this, call.argument<Int>("id") ?: 0)
                        result.success(true)
                    }
                    "status" -> result.success(status())
                    "requestNotif" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 77)
                        } else {
                            open("notif")
                        }
                        result.success(true)
                    }
                    "pickFile" -> {
                        pending = result
                        val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        startActivityForResult(i, 901)
                    }
                    "saveFile" -> {
                        pending = result
                        pendingText = call.argument<String>("text") ?: ""
                        val i = Intent(Intent.ACTION_CREATE_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("application/json")
                            .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "clario-backup.json")
                        startActivityForResult(i, 902)
                    }
                    "readFile" -> {
                        pending = result
                        val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*")
                        startActivityForResult(i, 903)
                    }
                    "openFile" -> {
                        try {
                            val i = Intent(Intent.ACTION_VIEW)
                                .setData(Uri.parse(call.argument<String>("uri") ?: ""))
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openUrl" -> {
                        try {
                            val i = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: ""))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "setIcon" -> {
                        setIcon(call.argument<String>("name") ?: "blue")
                        result.success(true)
                    }
                    "getIcon" -> result.success(currentIcon())
                    "open" -> {
                        open(call.argument<String>("what") ?: "app")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun status(): Map<String, Boolean> {
        val m = HashMap<String, Boolean>()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        m["notif"] = nm.areNotificationsEnabled()
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        m["exact"] = if (Build.VERSION.SDK_INT >= 31) am.canScheduleExactAlarms() else true
        m["fullscreen"] = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        m["battery"] = pm.isIgnoringBatteryOptimizations(packageName)
        return m
    }

    private fun details(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    private fun open(what: String) {
        val pkg = Uri.parse("package:$packageName")
        val i: Intent = when (what) {
            "notif" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            "exact" -> if (Build.VERSION.SDK_INT >= 31)
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg) else details()
            "fullscreen" -> if (Build.VERSION.SDK_INT >= 34)
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg) else details()
            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
            else -> details()
        }
        try {
            startActivity(i)
        } catch (e: Exception) {
            try {
                startActivity(details())
            } catch (e2: Exception) {
            }
        }
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return c.getString(idx) ?: "file"
                }
            }
        } catch (e: Exception) {
        }
        return uri.lastPathSegment ?: "file"
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode < 901 || requestCode > 903) return
        val r = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            r.success(null)
            return
        }
        when (requestCode) {
            901 -> {
                try {
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (e: Exception) {
                }
                r.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
            }
            902 -> {
                try {
                    contentResolver.openOutputStream(uri)?.use { it.write(pendingText.toByteArray(Charsets.UTF_8)) }
                    r.success(true)
                } catch (e: Exception) {
                    r.success(false)
                }
            }
            else -> {
                try {
                    val t = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                    r.success(t)
                } catch (e: Exception) {
                    r.success(null)
                }
            }
        }
    }

    private fun aliasName(n: String): ComponentName =
        ComponentName(packageName, "com.zico.clario.Icon" + n.replaceFirstChar { it.uppercase() })

    private fun setIcon(name: String) {
        for (n in icons) {
            val state = if (n == name) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            packageManager.setComponentEnabledSetting(aliasName(n), state, PackageManager.DONT_KILL_APP)
        }
    }

    private fun currentIcon(): String {
        for (n in icons) {
            if (packageManager.getComponentEnabledSetting(aliasName(n)) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return n
        }
        return "blue"
    }
}
