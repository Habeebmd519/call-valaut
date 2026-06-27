package com.example.callvault

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "callvault/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startService" -> {

                    Log.d("CALLVAULT", "Flutter requested Start Service")

                    val intent = Intent(this, CallVaultService::class.java)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Log.d("CALLVAULT", "Starting Foreground Service")
                        startForegroundService(intent)
                    } else {
                        Log.d("CALLVAULT", "Starting Normal Service")
                        startService(intent)
                    }

                    result.success(true)
                }

                "stopService" -> {

                    Log.d("CALLVAULT", "Stopping Service")

                    val intent = Intent(this, CallVaultService::class.java)
                    stopService(intent)

                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}