package com.schwabenapps.mkz.fantasyColor

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Keine Stretch-/Crossfade-Animation beim Drehen (OS streckt sonst den letzten Frame).
    window.attributes = window.attributes.apply {
      rotationAnimation = WindowManager.LayoutParams.ROTATION_ANIMATION_JUMPCUT
    }
    super.onCreate(savedInstanceState)
  }
}
