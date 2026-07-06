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
import java.util.Collections
import java.util.Date
import java.util.Locale

class CallVaultService : Service() {

    companion object {
        private const val TAG = "CALLVAULT"
        private const val CHANNEL_ID = "callvault_channel"
    }

    private lateinit var watchPath: String

    private val jsonFile by lazy {
        File(filesDir, "callvault_recordings.json")
    }

    private val processedFiles =
        Collections.synchronizedSet(mutableSetOf<String>())

    private val allowedExtensions = setOf(
        "mp3", "m4a", "aac", "wav", "amr", "3gp", "ogg"
    )

    private lateinit var observer: FileObserver
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()

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
            log("No watch path received")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("CallVault")
                .setContentText("Monitoring call recordings...")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setOngoing(true)
                .build()

        startForeground(1, notification)

        log("Foreground started")
        log("Watch Path = $watchPath")

        startWatching()

        return START_STICKY
    }

    private fun startWatching() {
        val folder = File(watchPath)

        log("Watching folder: ${folder.absolutePath}")
        log("Folder exists: ${folder.exists()}")

        if (!folder.exists()) return

        val existing = folder.listFiles() ?: emptyArray()

        existing.forEach {
            if (it.isFile) {
                processedFiles.add(it.absolutePath)
                log("Ignoring existing: ${it.name}")
            }
        }

        if (::observer.isInitialized) {
            observer.stopWatching()
        }

        observer = object : FileObserver(
            watchPath,
            CREATE or CLOSE_WRITE or MOVED_TO
        ) {
            override fun onEvent(event: Int, path: String?) {
                if (path == null) return

                val fullPath = "$watchPath/$path"

                if ((event and CLOSE_WRITE) == CLOSE_WRITE ||
                    (event and MOVED_TO) == MOVED_TO
                ) {
                    handleNewFile(fullPath)
                }
            }
        }

        observer.startWatching()
        log("FileObserver started")
    }

    private fun handleNewFile(fullPath: String) {
        if (processedFiles.contains(fullPath)) {
            log("Already processing: $fullPath")
            return
        }

        processedFiles.add(fullPath)

        handler.postDelayed({
            Thread {
                processRecording(fullPath)
            }.start()
        }, 3000)
    }

    private fun processRecording(fullPath: String) {
        val recording = File(fullPath)

        try {
            if (!recording.exists()) {
                log("Recording not found")
                return
            }

            val extension = recording.extension.lowercase()

            if (extension !in allowedExtensions) {
                log("Ignored non-audio file: ${recording.name}")
                return
            }

            if (!waitUntilStable(recording)) {
                log("Recording still growing: ${recording.name}")
                return
            }

            log("Recording completed")
            log("Original: ${recording.absolutePath}")
            log("Size: ${recording.length()} bytes")

val uploadFile = recording

            log("Upload file: ${uploadFile.absolutePath}")
            log("Upload size: ${uploadFile.length()} bytes")

            RecordingStore.saveRecording(jsonFile, uploadFile)

            if (RecordingStore.isUploaded(jsonFile, uploadFile.absolutePath)) {
                log("Already uploaded")
                // deleteTempIfNeeded(uploadFile, recording)
                return
            }

            UploadManager.upload(
                this,
                uploadFile,
                jsonFile
            )

            // deleteTempIfNeeded(uploadFile, recording)

            log("UploadManager finished")

        } catch (e: Exception) {
            log("UPLOAD ERROR")
            log(e.stackTraceToString())
        } finally {
            processedFiles.remove(fullPath)
            log("Process finished")
        }
    }

    private fun waitUntilStable(file: File): Boolean {
        repeat(5) {
            val before = file.length()
            Thread.sleep(1000)
            val after = file.length()

            if (before == after && after > 0L) {
                return true
            }
        }

        return false
    }

    

    override fun onDestroy() {
        log("Service destroyed")

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
            val file = File(
                getExternalFilesDir(null),
                "callvault_log.txt"
            )

            if (!file.exists()) {
                file.createNewFile()
            }

            val time = SimpleDateFormat(
                "yyyy-MM-dd HH:mm:ss",
                Locale.getDefault()
            ).format(Date())

            file.appendText("$time | $message\n")
        } catch (_: Exception) {
        }
    }
}