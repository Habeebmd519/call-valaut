package com.example.callvault

import android.os.Environment
import java.io.File

object RecordingFolderFinder {

    private val audioExtensions = listOf(
        ".mp3",
        ".m4a",
        ".aac",
        ".wav",
        ".amr",
        ".3gp",
        ".ogg"
    )

    fun find(): String? {

        val root = Environment.getExternalStorageDirectory()

        if (!root.exists())
            return null

        var bestFolder: File? = null
        var bestScore = -1

        scan(root) { folder ->

            val files = folder.listFiles() ?: return@scan

            var score = 0

            files.forEach {

                if (!it.isFile)
                    return@forEach

                val name = it.name.lowercase()

                if (audioExtensions.any { ext ->
                        name.endsWith(ext)
                    }) {

                    score++

                    if (name.contains("call"))
                        score += 5

                    if (name.contains("rec"))
                        score += 3

                    if (name.contains("record"))
                        score += 3
                }
            }

            val folderName =
                folder.name.lowercase()

            if (folderName.contains("call"))
                score += 20

            if (folderName.contains("record"))
                score += 15

            if (folderName.contains("rec"))
                score += 10

            if (score > bestScore) {

                bestScore = score
                bestFolder = folder
            }
        }

        return bestFolder?.absolutePath
    }

    private fun scan(
        folder: File,
        callback: (File) -> Unit
    ) {

        callback(folder)

        val children =
            folder.listFiles() ?: return

        children.forEach {

            if (it.isDirectory) {

                try {

                    scan(it, callback)

                } catch (_: Exception) {
                }
            }
        }
    }
}