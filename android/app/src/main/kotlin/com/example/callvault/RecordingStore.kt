package com.example.callvault

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

object RecordingStore {

    fun saveRecording(
        jsonFile: File,
        recording: File
    ) {

        // Create JSON file if needed
        if (!jsonFile.exists()) {
            jsonFile.parentFile?.mkdirs()
            jsonFile.writeText("[]")
        }

        val jsonArray = JSONArray(jsonFile.readText())

        // Prevent duplicate entries
        for (i in 0 until jsonArray.length()) {

            val item = jsonArray.getJSONObject(i)

            if (item.getString("filePath") == recording.absolutePath) {
                return
            }
        }

        val fileName = recording.name

        //------------------------------------
        // Extract phone number
        //------------------------------------

        var phoneNumber = "Unknown"

        try {

            val start = fileName.indexOf("(")
            val end = fileName.indexOf(")")

            if (start != -1 && end != -1) {
                phoneNumber =
                    fileName.substring(start + 1, end)
            }

        } catch (_: Exception) {
        }

        //------------------------------------
        // Extract date & time
        //------------------------------------

        var date = ""
        var time = ""

        try {

            val regex =
                Regex("(\\d{14})")

            val match =
                regex.find(fileName)

            if (match != null) {

                val value = match.value

                val input =
                    SimpleDateFormat(
                        "yyyyMMddHHmmss",
                        Locale.getDefault()
                    )

                val outputDate =
                    SimpleDateFormat(
                        "yyyy-MM-dd",
                        Locale.getDefault()
                    )

                val outputTime =
                    SimpleDateFormat(
                        "HH:mm:ss",
                        Locale.getDefault()
                    )

                val parsed: Date =
                    input.parse(value)!!

                date = outputDate.format(parsed)
                time = outputTime.format(parsed)
            }

        } catch (_: Exception) {
        }

        //------------------------------------
        // JSON Object
        //------------------------------------

        val obj = JSONObject()

        obj.put(
            "id",
            UUID.randomUUID().toString()
        )

        obj.put(
            "phoneNumber",
            phoneNumber
        )

        obj.put(
            "fileName",
            fileName
        )

        obj.put(
            "filePath",
            recording.absolutePath
        )

        obj.put(
            "size",
            recording.length()
        )

        obj.put(
            "date",
            date
        )

        obj.put(
            "time",
            time
        )

        obj.put(
            "uploaded",
            false
        )

        obj.put(
            "createdAt",
            System.currentTimeMillis()
        )

        jsonArray.put(obj)

        jsonFile.writeText(
            jsonArray.toString(4)
        )
    }
    fun isUploaded(
    jsonFile: File,
    filePath: String
): Boolean {

    if (!jsonFile.exists()) return false

    val array = JSONArray(jsonFile.readText())

    for (i in 0 until array.length()) {

        val obj = array.getJSONObject(i)

        if (obj.getString("filePath") == filePath) {
            return obj.optBoolean("uploaded", false)
        }
    }

    return false
}

fun markUploaded(
    jsonFile: File,
    filePath: String
) {

    if (!jsonFile.exists()) return

    val array = JSONArray(jsonFile.readText())

    for (i in 0 until array.length()) {

        val obj = array.getJSONObject(i)

        if (obj.getString("filePath") == filePath) {

            obj.put("uploaded", true)

            break
        }
    }

    jsonFile.writeText(array.toString(4))
}
}