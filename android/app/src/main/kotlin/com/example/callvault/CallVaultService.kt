package com.example.callvault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.FileObserver
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CallVaultService : Service() {

    companion object {
        private const val TAG = "CALLVAULT"
        private const val CHANNEL_ID = "callvault_channel"
    }

    private lateinit var watchPath: String

   

    private lateinit var observer: FileObserver

    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()

        log("====================================")
        log("Service Created")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                CHANNEL_ID,
                "CallVault Monitoring",
                NotificationManager.IMPORTANCE_LOW
            )

            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(
    intent: Intent?,
    flags: Int,
    startId: Int
): Int {

    watchPath = intent?.getStringExtra("watchPath") ?: run {
        log("No watch path received.")
        stopSelf()
        return START_NOT_STICKY
    }

    log("Service Started")
    log("Watch Path = $watchPath")

    val notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CallVault")
            .setContentText("Monitoring call recordings...")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .build()

    startForeground(1, notification)

    log("Foreground Started")

    startWatching()

    return START_STICKY
}
    private fun startWatching() {

        val folder = File(watchPath)

        log("------------------------------------")
        log("Watching Folder")
        log(watchPath)
        log("Folder Exists = ${folder.exists()}")

        if (!folder.exists()) {
            log("Folder does NOT exist")
            return
        }

        val files = folder.listFiles()

        log("Existing Files = ${files?.size ?: 0}")

        files?.forEach {
            log("Existing -> ${it.name}")
        }

        if (::observer.isInitialized) {
            observer.stopWatching()
        }

        observer = object : FileObserver(
            watchPath,
            ALL_EVENTS
        ) {

            override fun onEvent(
                event: Int,
                path: String?
            ) {

                if (path == null) return

                val fullPath = "$watchPath/$path"

                log("------------------------------------")
                log("EVENT = $event")
                log("PATH = $path")

                when (event and ALL_EVENTS) {

                    CREATE -> {

                        log("CREATE")
                        log(fullPath)
                    }

                    MODIFY -> {

                        log("MODIFY")
                        log(fullPath)
                    }

                    MOVED_TO -> {

                        log("MOVED_TO")
                        log(fullPath)
                    }

                    DELETE -> {

                        log("DELETE")
                        log(fullPath)
                    }

                    CLOSE_WRITE -> {

                        log("CLOSE_WRITE")
                        log(fullPath)

                        handler.postDelayed({

                            val recording = File(fullPath)

                            log("Exists = ${recording.exists()}")

                            if (!recording.exists()) {
                                log("Recording not found")
                                return@postDelayed
                            }

                            log("================================")
                            log("Recording Completed")
                            log("Name = ${recording.name}")
                            log("Path = ${recording.absolutePath}")
                            log("Size = ${recording.length()} bytes")

                           log("Recording detected: ${recording.absolutePath}")

                            log("================================")

                        }, 3000)
                    }
                }
            }
        }

        observer.startWatching()

        log("FileObserver Started")
    }

    override fun onDestroy() {

        log("Service Destroyed")

        if (::observer.isInitialized) {
            observer.stopWatching()
        }

        handler.removeCallbacksAndMessages(null)

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun log(message: String) {

        Log.d(TAG, message)

        try {

            val file =
                File("/storage/emulated/0/Download/callvault_log.txt")

            if (!file.exists()) {
                file.createNewFile()
            }

            val time = SimpleDateFormat(
                "HH:mm:ss",
                Locale.getDefault()
            ).format(Date())

            file.appendText("$time   $message\n")

        } catch (_: Exception) {
        }
    }
}