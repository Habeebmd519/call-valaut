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
import java.util.Collections

class CallVaultService : Service() {

    companion object {
        private const val TAG = "CALLVAULT"
        private const val CHANNEL_ID = "callvault_channel"
    }

    private lateinit var watchPath: String
    

    // JSON stored in app storage
    private val jsonFile by lazy {
        File(filesDir, "callvault_recordings.json")
    }


private val processedFiles =
    Collections.synchronizedSet(mutableSetOf<String>())

private val allowedExtensions = setOf(
    "mp3",
    "m4a",
    "aac",
    "wav",
    "amr",
    "3gp",
    "ogg"
)

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

        val notification: Notification =
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
        log(folder.absolutePath)
        log("Folder Exists = ${folder.exists()}")

        if (!folder.exists()) {

            log("Folder does NOT exist")

            return
        }

       val existing = folder.listFiles() ?: emptyArray()

log("Existing Files = ${existing.size}")

existing.forEach {
    if (it.isFile) {
        processedFiles.add(it.absolutePath)
        log("Ignoring existing -> ${it.name}")
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

        when (event and ALL_EVENTS) {

            CREATE -> {
                log("------------------------------------")
                log("CREATE")
                log(fullPath)
            }

            MOVED_TO -> {
                log("------------------------------------")
                log("MOVED_TO")
                log(fullPath)
            }

            CLOSE_WRITE -> {

    log("------------------------------------")
    log("CLOSE_WRITE")
    log(fullPath)

    if (processedFiles.contains(fullPath)) {
        log("Already processed")
        return
    }

    processedFiles.add(fullPath)

    handler.postDelayed({

        Thread {
            processRecording(fullPath)
        }.start()

    }, 3000)
}
        }
    }
}


        observer.startWatching()

        log("FileObserver Started")
    }

private fun processRecording(fullPath: String) {

    val recording = File(fullPath)

    if (!recording.exists()) {

        log("Recording not found")

        processedFiles.remove(fullPath)

        return
    }

    val extension =
        recording.extension.lowercase()

    if (extension !in allowedExtensions) {

    log("Ignored non-audio file")

    processedFiles.remove(fullPath)

    return
}

    var stable = false

for (i in 0 until 5) {

    val before = recording.length()

    Thread.sleep(1000)

    val after = recording.length()

    if (before == after) {
        stable = true
        break
    }
}

if (!stable) {
    log("Recording still growing")
    processedFiles.remove(fullPath)
    return
}

    log("====================================")
    log("Recording Completed")
    log("Name : ${recording.name}")
    log("Path : ${recording.absolutePath}")
    log("Size : ${recording.length()} bytes")

    try {

    RecordingStore.saveRecording(
        jsonFile,
        recording
    )

    log("Saved metadata")
    if (RecordingStore.isUploaded(jsonFile, recording.absolutePath)) {
    log("Already uploaded")
    processedFiles.remove(fullPath)
    return
}
   

    UploadManager.upload(
    this,
    recording,
    jsonFile
)

    log("UploadManager finished")

    processedFiles.remove(fullPath)

} catch (e: Exception) {

    log("UPLOAD ERROR")
    log(e.stackTraceToString())

    processedFiles.remove(fullPath)
}
    log("====================================")
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