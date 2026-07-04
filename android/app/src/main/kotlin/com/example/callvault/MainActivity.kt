package com.example.callvault

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "callvault/service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                //-----------------------------------
                // Find Recording Folder
                //-----------------------------------
//                 "findRecordingFolder" -> {

//                     Log.d("CALLVAULT", "Searching recording folder")

                  

//                     Log.d(
//                         "CALLVAULT",
//                         "Folder = $folder"
//                     )
//  Thread {

//         val folder = RecordingFolderFinder.find()

//         runOnUiThread {

//             result.success(folder)

//         }

//     }.start()
//     Log.d(
//                         "CALLVAULT",
//                         "Folder = $folder"
//                     )
//                 }

                //-----------------------------------
                // Start Service
                //-----------------------------------
                "startService" -> {

                    val watchPath =
                        call.argument<String>("watchPath")

                    if (watchPath == null) {

                        result.error(
                            "NO_PATH",
                            "Recording folder not found.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    Log.d(
                        "CALLVAULT",
                        "Flutter requested Start Service"
                    )

                    Log.d(
                        "CALLVAULT",
                        "WatchPath = $watchPath"
                    )

                    val intent =
                        Intent(this, CallVaultService::class.java)

                    intent.putExtra(
                        "watchPath",
                        watchPath
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                        Log.d(
                            "CALLVAULT",
                            "Starting Foreground Service"
                        )

                        startForegroundService(intent)

                    } else {

                        Log.d(
                            "CALLVAULT",
                            "Starting Normal Service"
                        )

                        startService(intent)
                    }

                    result.success(true)
                }

                //-----------------------------------
                // Stop Service
                //-----------------------------------
                "stopService" -> {

                    Log.d(
                        "CALLVAULT",
                        "Stopping Service"
                    )

                    stopService(
                        Intent(
                            this,
                            CallVaultService::class.java
                        )
                    )

                    result.success(true)
                }

                //-----------------------------------
                else -> {

                    result.notImplemented()
                }
            }
        }
    }
}