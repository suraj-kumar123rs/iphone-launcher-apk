package com.suraj.lumen

import android.annotation.SuppressLint
import android.app.ActivityOptions
import android.app.SearchManager
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQ_WALLPAPER = 4711
        private const val ICON_SIZE = 192
    }

    private var channel: MethodChannel? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingWallpaper: MethodChannel.Result? = null
    private var torchOn = false
    private var pkgReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/native")
        channel = ch
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        registerPackageReceiver()
        try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            cm.registerTorchCallback(object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    torchOn = enabled
                }
            }, main)
        } catch (e: Exception) {
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME) || Intent.ACTION_MAIN == intent.action) {
            channel?.invokeMethod("home", null)
        }
    }

    override fun onDestroy() {
        try {
            pkgReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {
        }
        super.onDestroy()
    }

    // ---------------- Method channel ----------------

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getApps" -> io.execute {
                    try {
                        val list = loadApps()
                        main.post { result.success(list) }
                    } catch (e: Exception) {
                        main.post { result.error("apps", e.message, null) }
                    }
                }
                "defaults" -> result.success(defaults())
                "launch" -> result.success(launch(call))
                "appInfo" -> result.success(
                    tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + call.argument<String>("pkg"))))
                )
                "uninstall" -> result.success(
                    tryStart(Intent(Intent.ACTION_DELETE, Uri.parse("package:" + call.argument<String>("pkg"))))
                )
                "expandNotifications" -> result.success(expandNotifications())
                "homeSettings" -> result.success(
                    tryStart(Intent(Settings.ACTION_HOME_SETTINGS)) || tryStart(Intent(Settings.ACTION_SETTINGS))
                )
                "isDefault" -> result.success(isDefault())
                "pickWallpaper" -> {
                    pendingWallpaper?.success(null)
                    pendingWallpaper = result
                    val i = Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
                    try {
                        startActivityForResult(Intent.createChooser(i, "Choose wallpaper"), REQ_WALLPAPER)
                    } catch (e: Exception) {
                        pendingWallpaper = null
                        result.success(null)
                    }
                }
                "battery" -> result.success(battery())
                "status" -> result.success(status())
                "setTorch" -> result.success(setTorch(call.argument<Boolean>("on") == true))
                "setBrightness" -> result.success(setBrightness(num(call, "v")))
                "requestWrite" -> result.success(
                    tryStart(Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName")))
                )
                "setVolume" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val v = (num(call, "v") * max).roundToInt().coerceIn(0, max)
                    try {
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, v, 0)
                    } catch (e: Exception) {
                    }
                    result.success(true)
                }
                "mediaKey" -> {
                    val code = when (call.argument<String>("key")) {
                        "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                        "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                        else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                    }
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                    result.success(true)
                }
                "openPanel" -> result.success(openPanel(call.argument<String>("kind") ?: ""))
                "openShortcut" -> result.success(openShortcut(call.argument<String>("kind") ?: ""))
                "openUrl" -> result.success(tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: ""))))
                "webSearch" -> result.success(webSearch(call.argument<String>("q") ?: ""))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native", e.message, null)
        }
    }

    private fun num(call: MethodCall, key: String): Double =
        (call.argument<Any>(key) as? Number)?.toDouble() ?: 0.0

    private fun tryStart(i: Intent, opts: Bundle? = null): Boolean = try {
        startActivity(i, opts)
        true
    } catch (e: Exception) {
        false
    }

    // ---------------- Apps ----------------

    private fun loadApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos = pm.queryIntentActivities(intent, 0)
        val dir = File(filesDir, "icons")
        dir.mkdirs()
        val out = ArrayList<Map<String, Any?>>()
        val seen = HashSet<String>()
        for (ri in infos) {
            val pkg = ri.activityInfo.packageName
            if (pkg == packageName || !seen.add(pkg)) continue
            val label = ri.loadLabel(pm).toString()
            var installed = 0L
            var updated = 0L
            try {
                val pi = pm.getPackageInfo(pkg, 0)
                installed = pi.firstInstallTime
                updated = pi.lastUpdateTime
            } catch (e: Exception) {
            }
            val file = File(dir, "$pkg.png")
            val stamp = File(dir, "$pkg.stamp")
            val stampValue = updated.toString()
            val fresh = file.exists() && stamp.exists() && stamp.readText() == stampValue
            if (!fresh) {
                try {
                    val bmp = iconBitmap(ri.loadIcon(pm))
                    FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    stamp.writeText(stampValue)
                } catch (e: Exception) {
                }
            }
            val appInfo = ri.activityInfo.applicationInfo
            val category = if (Build.VERSION.SDK_INT >= 26) appInfo.category else -1
            val system = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            out.add(
                mapOf(
                    "pkg" to pkg,
                    "label" to label,
                    "icon" to file.absolutePath,
                    "category" to category,
                    "installed" to installed,
                    "system" to system
                )
            )
        }
        return out
    }

    /** Draws the icon full-bleed so Flutter can mask it into a rounded square. */
    private fun iconBitmap(d: Drawable): Bitmap {
        val size = ICON_SIZE
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.WHITE)
        if (Build.VERSION.SDK_INT >= 26 && d is AdaptiveIconDrawable) {
            val pad = size / 4
            d.background?.let {
                it.setBounds(-pad, -pad, size + pad, size + pad)
                it.draw(c)
            }
            d.foreground?.let {
                it.setBounds(-pad, -pad, size + pad, size + pad)
                it.draw(c)
            }
        } else {
            val inset = (size * 0.14).toInt()
            d.setBounds(inset, inset, size - inset, size - inset)
            d.draw(c)
        }
        return bmp
    }

    private fun defaults(): List<String> {
        val pm = packageManager
        val intents = listOf(
            Intent(Intent.ACTION_DIAL),
            Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MESSAGING),
            Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_BROWSER),
            Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
        )
        val out = ArrayList<String>()
        for (i in intents) {
            try {
                val p = pm.resolveActivity(i, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
                if (p != null && p != "android" && !out.contains(p)) out.add(p)
            } catch (e: Exception) {
            }
        }
        return out
    }

    private fun launch(call: MethodCall): Boolean {
        val pkg = call.argument<String>("pkg") ?: return false
        val i = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        var opts: Bundle? = null
        val x = call.argument<Any>("x") as? Number
        if (x != null) {
            val d = resources.displayMetrics.density
            opts = ActivityOptions.makeScaleUpAnimation(
                window.decorView,
                (x.toDouble() * d).toInt(),
                (num(call, "y") * d).toInt(),
                (num(call, "w") * d).toInt().coerceAtLeast(1),
                (num(call, "h") * d).toInt().coerceAtLeast(1)
            ).toBundle()
        }
        return tryStart(i, opts) || tryStart(i)
    }

    private fun registerPackageReceiver() {
        val f = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                channel?.invokeMethod("appsChanged", null)
            }
        }
        pkgReceiver = r
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(r, f, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(r, f)
        }
    }

    private fun isDefault(): Boolean {
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val r = packageManager.resolveActivity(i, PackageManager.MATCH_DEFAULT_ONLY)
        return r?.activityInfo?.packageName == packageName
    }

    @SuppressLint("WrongConstant")
    private fun expandNotifications(): Boolean = try {
        val sbs = getSystemService("statusbar")
        val c = Class.forName("android.app.StatusBarManager")
        c.getMethod("expandNotificationsPanel").invoke(sbs)
        true
    } catch (e: Exception) {
        false
    }

    // ---------------- Wallpaper ----------------

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_WALLPAPER) return
        val r = pendingWallpaper ?: return
        pendingWallpaper = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            r.success(null)
            return
        }
        io.execute {
            try {
                filesDir.listFiles()?.filter { it.name.startsWith("wallpaper_") }?.forEach { it.delete() }
                val f = File(filesDir, "wallpaper_" + System.currentTimeMillis() + ".jpg")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(f).use { input.copyTo(it) }
                }
                val ok = f.exists() && f.length() > 0
                main.post { r.success(if (ok) f.absolutePath else null) }
            } catch (e: Exception) {
                main.post { r.success(null) }
            }
        }
    }

    // ---------------- Controls ----------------

    private fun battery(): Map<String, Any> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val st = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val s = st?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = s == BatteryManager.BATTERY_STATUS_CHARGING || s == BatteryManager.BATTERY_STATUS_FULL
        return mapOf("level" to level, "charging" to charging)
    }

    private fun status(): Map<String, Any> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        val vol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        var wifi = false
        try {
            wifi = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).isWifiEnabled
        } catch (e: Exception) {
        }
        var bt = false
        try {
            bt = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter?.isEnabled == true
        } catch (e: Exception) {
        }
        val airplane = Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) == 1
        var cellular = false
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cellular = cm.getNetworkCapabilities(cm.activeNetwork)?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
        } catch (e: Exception) {
        }
        var bright = 0.5
        try {
            bright = Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255.0
        } catch (e: Exception) {
        }
        return mapOf(
            "wifi" to wifi,
            "bluetooth" to bt,
            "airplane" to airplane,
            "cellular" to cellular,
            "torch" to torchOn,
            "brightness" to bright.coerceIn(0.0, 1.0),
            "volume" to vol.toDouble() / max,
            "music" to am.isMusicActive,
            "canWrite" to Settings.System.canWrite(this)
        )
    }

    private fun setTorch(on: Boolean): Boolean {
        return try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (id in cm.cameraIdList) {
                val ch = cm.getCameraCharacteristics(id)
                if (ch.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true) {
                    cm.setTorchMode(id, on)
                    torchOn = on
                    return on
                }
            }
            false
        } catch (e: Exception) {
            torchOn
        }
    }

    private fun setBrightness(v: Double): Boolean {
        if (!Settings.System.canWrite(this)) return false
        return try {
            Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
            Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, (v * 255).roundToInt().coerceIn(1, 255))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openPanel(kind: String): Boolean {
        val q = Build.VERSION.SDK_INT >= 29
        val action = when (kind) {
            "wifi" -> if (q) Settings.Panel.ACTION_WIFI else Settings.ACTION_WIFI_SETTINGS
            "internet" -> if (q) Settings.Panel.ACTION_INTERNET_CONNECTIVITY else Settings.ACTION_WIRELESS_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "airplane" -> Settings.ACTION_AIRPLANE_MODE_SETTINGS
            "volume" -> if (q) Settings.Panel.ACTION_VOLUME else Settings.ACTION_SOUND_SETTINGS
            "dnd" -> "android.settings.ZEN_MODE_SETTINGS"
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "cast" -> Settings.ACTION_CAST_SETTINGS
            else -> Settings.ACTION_SETTINGS
        }
        return tryStart(Intent(action)) || tryStart(Intent(Settings.ACTION_SETTINGS))
    }

    private fun openShortcut(kind: String): Boolean {
        val i = when (kind) {
            "camera" -> Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            "alarm" -> Intent(AlarmClock.ACTION_SHOW_ALARMS)
            "timer" -> Intent(AlarmClock.ACTION_SHOW_TIMERS)
            "calculator" -> Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CALCULATOR)
            "calendar" -> Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_CALENDAR)
            "settings" -> Intent(Settings.ACTION_SETTINGS)
            else -> return false
        }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return tryStart(i)
    }

    private fun webSearch(q: String): Boolean {
        val i = Intent(Intent.ACTION_WEB_SEARCH).putExtra(SearchManager.QUERY, q)
        if (tryStart(i)) return true
        return tryStart(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(q))))
    }
}
