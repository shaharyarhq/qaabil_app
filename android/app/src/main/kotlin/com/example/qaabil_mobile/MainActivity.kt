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
    private var pickerResult: MethodChannel.Result? = null
    private var fileSizeLimit = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qaabil/video_picker")
            .setMethodCallHandler { call, result ->
                val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                when {
                    call.method != "pickVideo" && call.method != "pickPhoto" -> result.notImplemented()
                    maxBytes == null || maxBytes <= 0 -> result.error("invalid_limit", null, null)
                    pickerResult != null -> result.error("busy", null, null)
                    else -> openMediaPicker(maxBytes, call.method == "pickPhoto", result)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun openMediaPicker(maxBytes: Long, photo: Boolean, result: MethodChannel.Result) {
        pickerResult = result
        fileSizeLimit = maxBytes
        val mediaType = if (photo) "image/*" else "video/*"
        val formats = if (photo) arrayOf("image/jpeg", "image/png", "image/webp")
                      else arrayOf("video/mp4", "video/quicktime")
        val documentsIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mediaType
            putExtra(Intent.EXTRA_MIME_TYPES, formats)
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
                val photoPicker = Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = mediaType }
                try {
                    startActivityForResult(photoPicker, MEDIA_REQUEST)
                    return
                } catch (_: ActivityNotFoundException) {
                    // Some Android builds omit the system Photo Picker.
                }
            }
            startActivityForResult(documentsIntent, MEDIA_REQUEST)
        } catch (_: Exception) {
            pickerResult = null
            result.error("picker_unavailable", null, null)
        }
    }

    @Deprecated("Handles results from startActivityForResult in FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != MEDIA_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pickerResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pickerResult = null
            result.success(null)
            return
        }
        val maxBytes = fileSizeLimit
        Thread { copyMedia(uri, maxBytes, result) }.start()
    }

    private fun copyMedia(uri: Uri, maxBytes: Long, result: MethodChannel.Result) {
        var temporary: File? = null
        try {
            val name = contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            } ?: "upload"
            val file = File.createTempFile("qaabil-media-", ".upload", cacheDir)
            temporary = file
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("No stream for selected media")
            input.use { source ->
                file.outputStream().use { destination ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var written = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        written += read
                        if (written > maxBytes) throw FileTooLarge()
                        destination.write(buffer, 0, read)
                    }
                    if (written == 0L) throw IOException("Empty media file")
                }
            }
            runOnUiThread {
                pickerResult = null
                result.success(mapOf("path" to file.path, "name" to name))
            }
        } catch (exception: Exception) {
            temporary?.delete()
            val code = if (exception is FileTooLarge) "file_too_large" else "file_unreadable"
            runOnUiThread {
                pickerResult = null
                result.error(code, null, null)
            }
        }
    }

    private class FileTooLarge : IOException()

    private companion object {
        const val MEDIA_REQUEST = 4371
    }
}
