package com.regisse.fidelia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel offer alerts arrive on (app/services/push.py sends
        // channel_id "offers"). Its own name in the phone's settings, so a
        // customer can mute offers without muting anything else. Creating an
        // existing channel is a no-op.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("offers", "Bons plans", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Nouveaux bons plans des commerces de votre commune et de vos favoris"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
