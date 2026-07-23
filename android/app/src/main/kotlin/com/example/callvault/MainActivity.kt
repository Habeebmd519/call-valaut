package com.example.callvault

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "callvault/service"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // -----------------------------------
                // Start Service
                // -----------------------------------
                "startService" -> {
                    val watchPath =
                        call.argument<String>("watchPath")

                    if (watchPath.isNullOrBlank()) {
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
                        Intent(
                            this,
                            CallVaultService::class.java
                        )

                    intent.putExtra(
                        "watchPath",
                        watchPath
                    )

                    try {
                        if (
                            Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.O
                        ) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(
                            "CALLVAULT",
                            "Could not start service",
                            e
                        )

                        result.error(
                            "START_SERVICE_FAILED",
                            e.message,
                            null
                        )
                    }
                }

                // -----------------------------------
                // Stop Service
                // -----------------------------------
                "stopService" -> {
                    try {
                        val stopped = stopService(
                            Intent(
                                this,
                                CallVaultService::class.java
                            )
                        )

                        result.success(stopped)
                    } catch (e: Exception) {
                        Log.e(
                            "CALLVAULT",
                            "Could not stop service",
                            e
                        )

                        result.error(
                            "STOP_SERVICE_FAILED",
                            e.message,
                            null
                        )
                    }
                }

                // -----------------------------------
                // Lookup contact name from number
                // -----------------------------------
                "lookupContactName" -> {
                    val phoneNumber =
                        call.argument<String>("phoneNumber")

                    if (phoneNumber.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val permissionGranted =
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_CONTACTS
                        ) == PackageManager.PERMISSION_GRANTED

                    if (!permissionGranted) {
                        result.error(
                            "CONTACT_PERMISSION_DENIED",
                            "Contacts permission is not granted.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    try {
                        val contactName =
                            findContactNameByNumber(
                                phoneNumber
                            )

                        result.success(contactName)
                    } catch (e: Exception) {
                        Log.e(
                            "CALLVAULT",
                            "Contact lookup failed",
                            e
                        )

                        result.error(
                            "CONTACT_LOOKUP_FAILED",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun findContactNameByNumber(
        phoneNumber: String
    ): String? {
        val lookupUri = Uri.withAppendedPath(
            ContactsContract
                .PhoneLookup
                .CONTENT_FILTER_URI,
            Uri.encode(phoneNumber)
        )

        val projection = arrayOf(
            ContactsContract
                .PhoneLookup
                .DISPLAY_NAME
        )

        contentResolver.query(
            lookupUri,
            projection,
            null,
            null,
            null
        )?.use { cursor ->

            val nameIndex =
                cursor.getColumnIndex(
                    ContactsContract
                        .PhoneLookup
                        .DISPLAY_NAME
                )

            if (
                cursor.moveToFirst() &&
                nameIndex >= 0
            ) {
                return cursor
                    .getString(nameIndex)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
            }
        }

        return null
    }
}