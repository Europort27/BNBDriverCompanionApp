package com.example.bnbdriverapp

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "bnbdriverapp/power_management"
	private var wakeLock: PowerManager.WakeLock? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"acquireWakeLock" -> {
						acquireWakeLock()
						result.success(null)
					}
					"releaseWakeLock" -> {
						releaseWakeLock()
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun acquireWakeLock() {
		if (wakeLock?.isHeld == true) return

		val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
		wakeLock = powerManager.newWakeLock(
			PowerManager.PARTIAL_WAKE_LOCK,
			"bnbdriverapp:wardriving",
		).apply {
			acquire()
		}
	}

	private fun releaseWakeLock() {
		wakeLock?.let {
			if (it.isHeld) it.release()
		}
		wakeLock = null
	}

	override fun onDestroy() {
		releaseWakeLock()
		super.onDestroy()
	}
}
