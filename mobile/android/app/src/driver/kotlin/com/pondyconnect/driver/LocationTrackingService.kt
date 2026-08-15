package com.pondyconnect.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Foreground service for driver background location tracking.
///
/// The driver AndroidManifest declares this service with
/// `foregroundServiceType="location"`. This service creates the required
/// notification channel and foreground notification so the service can
/// start, keeping the app alive while the driver is online and tracking
/// GPS position for ride dispatch.
///
/// On Android 14+ (API 34+), startForeground must specify the
/// FOREGROUND_SERVICE_TYPE_LOCATION explicitly.
class LocationTrackingService : Service() {

    companion object {
        private const val CHANNEL_ID = "pondyconnect_location"
        private const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuous location tracking for active rides"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PY Connect Captain")
            .setContentText("You are online and receiving requests.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()

        // Android 14+ (API 34+) requires explicit foreground service type.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
