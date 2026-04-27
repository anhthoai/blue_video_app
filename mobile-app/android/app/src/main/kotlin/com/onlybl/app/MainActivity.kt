package com.onlybl.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val contentProtectionChannel = "com.onlybl.app/content_protection"

	override fun getRenderMode(): RenderMode = RenderMode.texture

	override fun getTransparencyMode(): TransparencyMode = TransparencyMode.opaque

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			contentProtectionChannel,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"setProtectionEnabled" -> {
					val enabled = call.argument<Boolean>("enabled") ?: false
					runOnUiThread {
						if (enabled) {
							window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
						} else {
							window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
						}
						result.success(null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
