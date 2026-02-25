package com.bluevideoapp.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode

class MainActivity : FlutterActivity() {
	override fun getRenderMode(): RenderMode = RenderMode.texture

	override fun getTransparencyMode(): TransparencyMode = TransparencyMode.opaque
}
