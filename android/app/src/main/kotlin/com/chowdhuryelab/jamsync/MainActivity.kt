package com.chowdhuryelab.jamsync

import android.net.Uri
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.chowdhuryelab.jamsync/content_resolver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyContentToCache" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_ARGUMENT", "URI is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val cachedPath = copyContentUriToCache(uriString)
                        result.success(cachedPath)
                    } catch (e: Exception) {
                        result.error("COPY_ERROR", "Failed to copy content URI: ${e.message}", e.toString())
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun copyContentUriToCache(uriString: String): String {
        val uri = Uri.parse(uriString)
        val contentResolver = applicationContext.contentResolver

        // Get file extension from MIME type
        val mimeType = contentResolver.getType(uri)
        val extension = when (mimeType) {
            "audio/mpeg" -> "mp3"
            "audio/mp4", "audio/mp4a-latm" -> "m4a"
            "audio/ogg" -> "ogg"
            "audio/wav", "audio/x-wav" -> "wav"
            "audio/flac" -> "flac"
            else -> "tmp"
        }

        // Create temporary file in cache directory
        val cacheDir = applicationContext.cacheDir
        val tempFile = File.createTempFile("audio_stream_", ".$extension", cacheDir)

        // Copy content to temp file
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw Exception("Cannot open input stream for URI: $uriString")

        return tempFile.absolutePath
    }
}

