package com.example.callvault

import android.content.Context
import android.util.Log
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File

object UploadManager {

    private const val TAG = "CALLVAULT"

    private val client = OkHttpClient()

    fun upload(
        context: Context,
        recording: File,
        jsonFile: File
    ) {

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val webhook = prefs.getString(
            "flutter.server_url",
            "https://n8n-642200590.kloudbeansite.com/webhook/call-upload"
        )!!

        try {

            Log.d(TAG, "Webhook = $webhook")

            val body = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart(
                    "file",
                    recording.name,
                    recording.asRequestBody(
                        "audio/*".toMediaTypeOrNull()
                    )
                )
                .build()

            val request = Request.Builder()
                .url(webhook)
                .post(body)
                .build()

            val response = client.newCall(request).execute()

            if (response.isSuccessful) {

                Log.d(TAG, "Upload Success")

                RecordingStore.markUploaded(
                    jsonFile,
                    recording.absolutePath
                )

            } else {

                Log.d(TAG, "Upload Failed : ${response.code}")
            }

            response.close()

        } catch (e: Exception) {

            Log.e(TAG, "Upload Error", e)
        }
    }
}