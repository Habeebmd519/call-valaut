package com.example.callvault

import android.content.Context
import android.util.Log
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONArray
import java.io.File
import java.util.concurrent.TimeUnit

object UploadManager {

    private const val TAG = "CALLVAULT"

    private const val DEFAULT_WEBHOOK =
        "https://n8n-642200590.kloudbeansite.com/webhook/call-upload"

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(3, TimeUnit.MINUTES)
        .readTimeout(3, TimeUnit.MINUTES)
        .build()

    fun upload(
        context: Context,
        recording: File,
    ): Boolean {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )

        val webhook = prefs.getString(
            "flutter.server_url",
            DEFAULT_WEBHOOK,
        )?.trim().orEmpty().ifBlank {
            DEFAULT_WEBHOOK
        }

        return try {
            if (!recording.exists()) {
                Log.e(TAG, "Upload failed: file does not exist")
                Log.e(TAG, "File path: ${recording.absolutePath}")
                return false
            }

            val metadata = extractMetadata(recording)

            val matchedClientName = findClientNameByPhone(
                context = context,
                phoneNumber = metadata.phoneNumber,
            )

            val filename = safeValue(
                value = recording.name,
                placeholder = "recording_${System.currentTimeMillis()}.mp3",
            )

            val phoneNumber = safeValue(
                value = metadata.phoneNumber,
                placeholder = "Not available",
            )

            val contactName = safeValue(
                value = metadata.contactName,
                placeholder = "Unknown contact",
            )

            val clientName = safeValue(
                value = matchedClientName,
                placeholder = "Unknown client",
            )

            val callDate = safeValue(
                value = metadata.callDate,
                placeholder = "Not available",
            )

            val callTime = safeValue(
                value = metadata.callTime,
                placeholder = "Not available",
            )

            val mimeType = detectMimeType(recording)

            Log.d(TAG, "Webhook = $webhook")
            Log.d(TAG, "File = ${recording.absolutePath}")
            Log.d(TAG, "Filename = $filename")
            Log.d(TAG, "MIME = $mimeType")
            Log.d(TAG, "Phone = $phoneNumber")
            Log.d(TAG, "Contact = $contactName")
            Log.d(TAG, "Client = $clientName")
            Log.d(TAG, "Date = $callDate")
            Log.d(TAG, "Time = $callTime")

            val body = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart("filename", filename)
                .addFormDataPart("phone_number", phoneNumber)
                .addFormDataPart("contact_name", contactName)
                .addFormDataPart("client_name", clientName)
                .addFormDataPart("call_date", callDate)
                .addFormDataPart("call_time", callTime)
                .addFormDataPart(
                    "file",
                    filename,
                    recording.asRequestBody(
                        mimeType.toMediaTypeOrNull(),
                    ),
                )
                .build()

            val request = Request.Builder()
                .url(webhook)
                .post(body)
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()

                Log.d(TAG, "Status = ${response.code}")
                Log.d(TAG, "Response = $responseBody")

                if (response.isSuccessful) {
                    Log.d(TAG, "Upload Success")
                    true
                } else {
                    Log.e(
                        TAG,
                        "Upload Failed: ${response.code} ${response.message}",
                    )
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload Error", e)
            false
        }
    }

    private fun findClientNameByPhone(
        context: Context,
        phoneNumber: String?,
    ): String? {
        val normalizedInput = normalizePhoneNumber(phoneNumber)

        if (normalizedInput.isEmpty()) {
            Log.d(TAG, "Cannot match client: phone number is empty")
            return null
        }

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )

        val savedClientsJson = prefs.getString(
            "flutter.saved_clients",
            null,
        )

        if (savedClientsJson.isNullOrBlank()) {
            Log.d(TAG, "No saved client mappings found")
            return null
        }

        return try {
            Log.d(TAG, "Saved clients JSON = $savedClientsJson")

            val clients = JSONArray(savedClientsJson)

            for (index in 0 until clients.length()) {
                val item = clients.optJSONObject(index) ?: continue

                val savedPhone = item
                    .optString("phone_number")
                    .ifBlank {
                        item.optString("phoneNumber")
                    }
                    .trim()

                val savedClientName = item
                    .optString("client_name")
                    .ifBlank {
                        item.optString("clientName")
                    }
                    .trim()

                val normalizedSaved =
                    normalizePhoneNumber(savedPhone)

                Log.d(
                    TAG,
                    "Comparing phones: " +
                        "${normalizedInput.takeLast(10)} <-> " +
                        normalizedSaved.takeLast(10),
                )

                if (
                    normalizedSaved.isNotEmpty() &&
                    phoneNumbersMatch(
                        normalizedInput,
                        normalizedSaved,
                    )
                ) {
                    if (savedClientName.isBlank()) {
                        Log.d(
                            TAG,
                            "Phone matched, but client name is empty",
                        )
                        return null
                    }

                    Log.d(
                        TAG,
                        "Matched client '$savedClientName' for $phoneNumber",
                    )

                    return savedClientName
                }
            }

            Log.d(
                TAG,
                "No client matched for phone: $phoneNumber",
            )

            null
        } catch (e: Exception) {
            Log.e(
                TAG,
                "Failed to read saved client mappings",
                e,
            )
            null
        }
    }

    private fun phoneNumbersMatch(
        first: String,
        second: String,
    ): Boolean {
        if (first == second) {
            return true
        }

        if (first.length >= 10 && second.length >= 10) {
            return first.takeLast(10) == second.takeLast(10)
        }

        return false
    }

    private fun normalizePhoneNumber(
        value: String?,
    ): String {
        return value
            ?.replace(Regex("[^0-9]"), "")
            ?.trim()
            .orEmpty()
    }

    private fun safeValue(
        value: String?,
        placeholder: String,
    ): String {
        val cleaned = value?.trim().orEmpty()

        return if (
            cleaned.isBlank() ||
            cleaned.equals(
                "unknown",
                ignoreCase = true,
            )
        ) {
            placeholder
        } else {
            cleaned
        }
    }

    private fun detectMimeType(
        file: File,
    ): String {
        return when (file.extension.lowercase()) {
            "m4a" -> "audio/mp4"
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "aac" -> "audio/aac"
            "amr" -> "audio/amr"
            "3gp" -> "audio/3gpp"
            "ogg" -> "audio/ogg"
            else -> "application/octet-stream"
        }
    }

    private fun extractMetadata(
        recording: File,
    ): RecordingUploadMetadata {
        val filename = recording.nameWithoutExtension

        val pattern = Regex(
            """^(.*?)\(([^)]+)\)_(\d{8})(\d{6})$""",
        )

        val match = pattern.find(filename)

        if (match == null) {
            Log.d(
                TAG,
                "Could not parse metadata from: ${recording.name}",
            )

            return RecordingUploadMetadata(
                phoneNumber = null,
                contactName = null,
                callDate = null,
                callTime = null,
            )
        }

        val contactName = match.groupValues[1]
            .trim()
            .removePrefix("#")
            .trim()

        val phoneNumber =
            match.groupValues[2].trim()

        val rawDate =
            match.groupValues[3]

        val rawTime =
            match.groupValues[4]

        val callDate =
            "${rawDate.substring(0, 4)}-" +
                "${rawDate.substring(4, 6)}-" +
                rawDate.substring(6, 8)

        val callTime =
            "${rawTime.substring(0, 2)}:" +
                "${rawTime.substring(2, 4)}:" +
                rawTime.substring(4, 6)

        return RecordingUploadMetadata(
            phoneNumber = phoneNumber,
            contactName = contactName,
            callDate = callDate,
            callTime = callTime,
        )
    }

    private data class RecordingUploadMetadata(
        val phoneNumber: String?,
        val contactName: String?,
        val callDate: String?,
        val callTime: String?,
    )
}