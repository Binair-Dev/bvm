package com.bvm.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.BatteryManager
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.app.Activity
import android.content.Context
import android.os.Environment
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bvm.mobile/native"
    private val EVENT_CHANNEL = "com.bvm.mobile/events"

    private lateinit var bootstrapManager: BootstrapManager
    private lateinit var processManager: ProcessManager
    private val portForwardManager = PortForwardManager()
    private var setupDone = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir

        bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
        processManager = ProcessManager(filesDir, nativeLibDir)

        if (!setupDone) {
            setupDone = true
            Thread {
                try { bootstrapManager.setupDirectories() } catch (_: Exception) {}
            }.start()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getProotPath" -> {
                    result.success(processManager.getProotPath())
                }
                "getArch" -> {
                    result.success(ArchUtils.getArch())
                }
                "getFilesDir" -> {
                    result.success(filesDir)
                }
                "getNativeLibDir" -> {
                    result.success(nativeLibDir)
                }
                "isBootstrapComplete" -> {
                    result.success(bootstrapManager.isBootstrapComplete())
                }
                "getBootstrapStatus" -> {
                    result.success(bootstrapManager.getBootstrapStatus())
                }
                "extractRootfs" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractRootfs(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "vmCreate" -> {
                    val name = call.argument<String>("name")
                    if (name != null) {
                        Thread {
                            try {
                                if (!bootstrapManager.isBootstrapComplete()) {
                                    runOnUiThread { result.error("NO_BASE_ROOTFS", "Base Ubuntu rootfs not installed. Run setup first.", null) }
                                    return@Thread
                                }
                                val ok = bootstrapManager.cloneRootfs(name)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("VM_CREATE_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "name required", null)
                    }
                }
                "vmDelete" -> {
                    val name = call.argument<String>("name")
                    if (name != null) {
                        Thread {
                            try {
                                portForwardManager.stopForwardsByVm(name)
                                val ok = bootstrapManager.deleteRootfs(name)
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("VM_DELETE_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "name required", null)
                    }
                }
                "vmList" -> {
                    Thread {
                        try {
                            val vms = bootstrapManager.listVms()
                            runOnUiThread { result.success(vms) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VM_LIST_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "runInProot" -> {
                    val command = call.argument<String>("command")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                    val vmName = call.argument<String>("vmName") ?: "ubuntu"
                    if (command != null) {
                        Thread {
                            try {
                                val output = processManager.runInProotSync(command, timeout, vmName)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "startTerminalService" -> {
                    try {
                        TerminalSessionService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopTerminalService" -> {
                    try {
                        TerminalSessionService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isTerminalServiceRunning" -> {
                    result.success(TerminalSessionService.isRunning)
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "getBatteryStatus" -> {
                    try {
                        val batteryIntent =
                            registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        if (batteryIntent == null) {
                            result.error("BATTERY_ERROR", "Battery status unavailable", null)
                            return@setMethodCallHandler
                        }

                        val level = batteryIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = batteryIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                        val temperature =
                            batteryIntent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
                        val voltage = batteryIntent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
                        val status = batteryIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                        val plugged = batteryIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

                        val percentage =
                            if (level >= 0 && scale > 0) ((level * 100f) / scale).toInt() else -1

                        val statusText = when (status) {
                            BatteryManager.BATTERY_STATUS_CHARGING -> "CHARGING"
                            BatteryManager.BATTERY_STATUS_DISCHARGING -> "DISCHARGING"
                            BatteryManager.BATTERY_STATUS_FULL -> "FULL"
                            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "NOT_CHARGING"
                            else -> "UNKNOWN"
                        }

                        val pluggedText = when {
                            (plugged and BatteryManager.BATTERY_PLUGGED_AC) != 0 -> "AC"
                            (plugged and BatteryManager.BATTERY_PLUGGED_USB) != 0 -> "USB"
                            (plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS) != 0 -> "WIRELESS"
                            else -> "UNPLUGGED"
                        }

                        val data = hashMapOf<String, Any>(
                            "percentage" to percentage,
                            "level" to level,
                            "scale" to scale,
                            "status" to statusText,
                            "plugged" to pluggedText,
                            "isCharging" to (
                                status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                    status == BatteryManager.BATTERY_STATUS_FULL
                                ),
                            "temperatureC" to if (temperature >= 0) temperature / 10.0 else -1.0,
                            "voltageMv" to voltage,
                        )

                        result.success(data)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "setupDirs" -> {
                    Thread {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "writeResolv" -> {
                    Thread {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "copyToClipboard" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("bVM", text))
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "vibrate" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager =
                                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(
                                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(
                                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(durationMs)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIBRATE_ERROR", e.message, null)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            if (!Environment.isExternalStorageManager()) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                            }
                        } else {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.READ_EXTERNAL_STORAGE,
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                                ),
                                STORAGE_PERMISSION_REQUEST
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "hasStoragePermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPermission)
                }
                "getExternalStoragePath" -> {
                    result.success(Environment.getExternalStorageDirectory().absolutePath)
                }
                "readRootfsFile" -> {
                    val path = call.argument<String>("path")
                    val vmName = call.argument<String>("vmName") ?: "ubuntu"
                    if (path != null) {
                        Thread {
                            try {
                                val file = java.io.File("$filesDir/rootfs/$vmName/$path")
                                val content = if (file.exists()) file.readText() else ""
                                runOnUiThread { result.success(content) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_READ_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "writeRootfsFile" -> {
                    val path = call.argument<String>("path")
                    val content = call.argument<String>("content")
                    val vmName = call.argument<String>("vmName") ?: "ubuntu"
                    if (path != null && content != null) {
                        Thread {
                            try {
                                val file = java.io.File("$filesDir/rootfs/$vmName/$path")
                                file.parentFile?.mkdirs()
                                file.writeText(content)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_WRITE_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path and content required", null)
                    }
                }
                "bringToForeground" -> {
                    try {
                        val intent = Intent(applicationContext, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        }
                        applicationContext.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FOREGROUND_ERROR", e.message, null)
                    }
                }
                "readSensor" -> {
                    val sensorType = call.argument<String>("sensor") ?: "accelerometer"
                    Thread {
                        try {
                            val sensorManager =
                                getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            val type = when (sensorType) {
                                "accelerometer" -> Sensor.TYPE_ACCELEROMETER
                                "gyroscope" -> Sensor.TYPE_GYROSCOPE
                                "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
                                "barometer" -> Sensor.TYPE_PRESSURE
                                else -> Sensor.TYPE_ACCELEROMETER
                            }
                            val sensor = sensorManager.getDefaultSensor(type)
                            if (sensor == null) {
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor $sensorType not available", null)
                                }
                                return@Thread
                            }
                            var received = false
                            val listener = object : SensorEventListener {
                                override fun onSensorChanged(event: SensorEvent?) {
                                    if (received || event == null) return
                                    received = true
                                    sensorManager.unregisterListener(this)
                                    val data = hashMapOf<String, Any>(
                                        "sensor" to sensorType,
                                        "timestamp" to event.timestamp,
                                        "accuracy" to event.accuracy
                                    )
                                    when (sensorType) {
                                        "accelerometer", "gyroscope", "magnetometer" -> {
                                            data["x"] = event.values[0].toDouble()
                                            data["y"] = event.values[1].toDouble()
                                            data["z"] = event.values[2].toDouble()
                                        }
                                        "barometer" -> {
                                            data["pressure"] = event.values[0].toDouble()
                                        }
                                    }
                                    runOnUiThread { result.success(data) }
                                }
                                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                            }
                            sensorManager.registerListener(
                                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL
                            )
                            Thread.sleep(3000)
                            if (!received) {
                                sensorManager.unregisterListener(listener)
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor read timed out", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SENSOR_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "startPortForward" -> {
                    val vmName = call.argument<String>("vmName") ?: ""
                    val vmPort = call.argument<Int>("vmPort") ?: 0
                    val hostPort = call.argument<Int>("hostPort") ?: 0
                    val bindAddress = call.argument<String>("bindAddress") ?: "127.0.0.1"
                    if (vmName.isEmpty() || vmPort <= 0 || hostPort <= 0 || hostPort > 65535) {
                        result.error("INVALID_ARGS", "Invalid port forward parameters", null)
                    } else {
                        val session = portForwardManager.startForward(vmName, vmPort, hostPort, bindAddress)
                        if (session != null) {
                            result.success(
                                mapOf(
                                    "id" to session.id,
                                    "vmName" to session.vmName,
                                    "vmPort" to session.vmPort,
                                    "hostPort" to session.hostPort,
                                    "bindAddress" to session.bindAddress
                                )
                            )
                        } else {
                            result.error("PORT_FORWARD_ERROR", "Failed to start port forward. Port may already be in use.", null)
                        }
                    }
                }
                "stopPortForward" -> {
                    val id = call.argument<String>("id") ?: ""
                    if (id.isEmpty()) {
                        result.error("INVALID_ARGS", "id required", null)
                    } else {
                        val ok = portForwardManager.stopForward(id)
                        result.success(ok)
                    }
                }
                "listPortForwards" -> {
                    val list = portForwardManager.listForwards().map {
                        mapOf(
                            "id" to it.id,
                            "vmName" to it.vmName,
                            "vmPort" to it.vmPort,
                            "hostPort" to it.hostPort,
                            "bindAddress" to it.bindAddress
                        )
                    }
                    result.success(list)
                }
                "getLocalIpAddress" -> {
                    result.success(getLocalIpAddress() ?: "")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        createUrlNotificationChannel()
        requestNotificationPermission()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
                override fun onCancel(arguments: Any?) {}
            }
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        portForwardManager.stopAllForwards()
    }

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                if (iface.isLoopback || !iface.isUp) continue
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (addr is java.net.Inet4Address) {
                        return addr.hostAddress
                    }
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
        }
    }

    private fun createUrlNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                URL_CHANNEL_ID,
                "bVM URLs",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected URLs"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val URL_CHANNEL_ID = "bvm_urls"
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
        const val STORAGE_PERMISSION_REQUEST = 1002
    }
}
