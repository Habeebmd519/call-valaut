package com.example.callvault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.os.Build
import android.os.FileObserver
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class CallVaultService : Service() {

    private val CHANNEL_ID = "callvault_channel"

    private val watchPath =
        "/storage/emulated/0/Recordings/sound_recorder/call_rec"

    private lateinit var observer: FileObserver

    override fun onCreate() {
        super.onCreate()

        Log.d("CALLVAULT", "Service Created")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                CHANNEL_ID,
                "CallVault Monitoring",
                NotificationManager.IMPORTANCE_LOW
            )

            val manager =
                getSystemService(NotificationManager::class.java)

            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(
        intent: android.content.Intent?,
        flags: Int,
        startId: Int
    ): Int {

        Log.d("CALLVAULT", "Service Started")

        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("CallVault")
                .setContentText("Monitoring recordings...")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setOngoing(true)
                .build()

        startForeground(1, notification)

        Log.d("CALLVAULT", "Foreground Started")

        startWatching()

        return START_STICKY
    }

    private fun startWatching() {

        Log.d("CALLVAULT", "Watching folder:")
        Log.d("CALLVAULT", watchPath)

        observer = object : FileObserver(
            watchPath,
            CREATE or CLOSE_WRITE
        ) {

            override fun onEvent(event: Int, path: String?) {

                if (path == null) return

                when (event) {

                    CREATE -> {

                        Log.d(
                            "CALLVAULT",
                            "=================================="
                        )

                        Log.d(
                            "CALLVAULT",
                            "NEW FILE CREATED"
                        )

                        Log.d(
                            "CALLVAULT",
                            path
                        )

                        Log.d(
                            "CALLVAULT",
                            "=================================="
                        )
                    }

                    CLOSE_WRITE -> {

                        Log.d(
                            "CALLVAULT",
                            "=================================="
                        )

                        Log.d(
                            "CALLVAULT",
                            "RECORDING FINISHED"
                        )

                        Log.d(
                            "CALLVAULT",
                            path
                        )

                        Log.d(
                            "CALLVAULT",
                            "=================================="
                        )
                    }
                }
            }
        }

        observer.startWatching()

        Log.d(
            "CALLVAULT",
            "FileObserver Started Successfully"
        )
    }

    override fun onDestroy() {

        Log.d("CALLVAULT", "Stopping FileObserver")

        if (::observer.isInitialized) {
            observer.stopWatching()
        }

        Log.d("CALLVAULT", "Service Destroyed")

        super.onDestroy()
    }

    override fun onBind(intent: android.content.Intent?): IBinder? {
        return null
    }
}