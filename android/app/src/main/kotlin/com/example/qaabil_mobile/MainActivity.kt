package com.example.qaabil_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var videoPickerResult: MethodChannel.Result? = null
    private var videoSizeLimit = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qaabil/video_picker")
            .setMethodCallHandler { call, result ->
                val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                when {
                    call.method != "pickVideo" -> result.notImplemented()
                    maxBytes == null || maxBytes <= 0 -> result.error("invalid_limit", null, null)
                    videoPickerResult != null -> result.error("busy", null, null)
                    else -> openVideoPicker(maxBytes, result)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun openVideoPicker(maxBytes: Long, result: MethodChannel.Result) {
        videoPickerResult = result
        videoSizeLimit = maxBytes
        val documentsIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/mp4", "video/quicktime"))
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:Download",
                ),
            )
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val photoPicker = Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "video/*" }
                try {
                    startActivityForResult(photoPicker, VIDEO_REQUEST)
                    return
                } catch (_: ActivityNotFoundException) {
                    // Some Android builds omit the system Photo Picker.
                }
            }
            startActivityForResult(documentsIntent, VIDEO_REQUEST)
        } catch (_: Exception) {
            videoPickerResult = null
            result.error("picker_unavailable", null, null)
        }
    }

    @Deprecated("Handles results from startActivityForResult in FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != VIDEO_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = videoPickerResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            videoPickerResult = null
            result.success(null)
            return
        }
        val maxBytes = videoSizeLimit
        Thread { copyVideo(uri, maxBytes, result) }.start()
    }

    private fun copyVideo(uri: Uri, maxBytes: Long, result: MethodChannel.Result) {
        var temporary: File? = null
        try {
            val name = contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            } ?: "video.mp4"
            val file = File.createTempFile("qaabil-video-", ".upload", cacheDir)
            temporary = file
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("No stream for selected video")
            input.use { source ->
                file.outputStream().use { destination ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var written = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        written += read
                        if (written > maxBytes) throw VideoTooLarge()
                        destination.write(buffer, 0, read)
                    }
                    if (written == 0L) throw IOException("Empty video")
                }
            }
            runOnUiThread {
                videoPickerResult = null
                result.success(mapOf("path" to file.path, "name" to name))
            }
        } catch (exception: Exception) {
            temporary?.delete()
            val code = if (exception is VideoTooLarge) "file_too_large" else "file_unreadable"
            runOnUiThread {
                videoPickerResult = null
                result.error(code, null, null)
            }
        }
    }

    private class VideoTooLarge : IOException()

    private companion object {
        const val VIDEO_REQUEST = 4371
    }
}
