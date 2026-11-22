package com.example.parsu_motopass

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private val documentRequest = 701
    private val maxSize = 5 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "edu.parsu.motopass/documents")
            .setMethodCallHandler { call, result ->
                if (call.method == "renderPdf") {
                    val bytes = call.argument<ByteArray>("bytes")
                    val page = call.argument<Int>("page")
                    if (bytes == null || bytes.size > maxSize || page == null) {
                        result.error("pdf", "Invalid PDF request.", null)
                    } else {
                        renderPdf(bytes, page, result)
                    }
                } else if (call.method != "pick") {
                    result.notImplemented()
                } else if (pendingPick != null) {
                    result.error("busy", "A document picker is already open.", null)
                } else {
                    pendingPick = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/png", "image/jpeg"))
                    }
                    try {
                        startActivityForResult(intent, documentRequest)
                    } catch (_: android.content.ActivityNotFoundException) {
                        pendingPick = null
                        result.error("unavailable", "No document picker is available.", null)
                    }
                }
            }
    }

    private fun renderPdf(bytes: ByteArray, index: Int, result: MethodChannel.Result) {
        thread {
            try {
                val file = File.createTempFile("review-", ".pdf", cacheDir)
                val response = try {
                    file.writeBytes(bytes)
                    val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                    // The open descriptor keeps the contents available after unlinking.
                    file.delete()
                    val renderer = try {
                        PdfRenderer(descriptor)
                    } catch (error: Exception) {
                        descriptor.close()
                        throw error
                    }
                    renderer.use { pdf ->
                        pdf.openPage(index).use { page ->
                            val scale = 1200.0 / maxOf(page.width, page.height)
                            val bitmap = Bitmap.createBitmap(
                                maxOf(1, (page.width * scale).toInt()),
                                maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888
                            )
                            try {
                                bitmap.eraseColor(android.graphics.Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val image = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, image)
                                mapOf("count" to pdf.pageCount, "image" to image.toByteArray())
                            } finally {
                                bitmap.recycle()
                            }
                        }
                    }
                } finally {
                    file.delete()
                }
                runOnUiThread { result.success(response) }
            } catch (_: Exception) {
                runOnUiThread { result.error("pdf", "Could not display the PDF.", null) }
            }
        }
    }

    @Deprecated("FlutterActivity supplies the activity result through this callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != documentRequest) return
        val result = pendingPick ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingPick = null
            result.success(null)
            return
        }
        thread {
            try {
                val name = contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                } ?: throw IOException()
                val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var count = stream.read(buffer)
                    while (count >= 0 && output.size() + count <= maxSize) {
                        output.write(buffer, 0, count)
                        count = stream.read(buffer)
                    }
                    if (count >= 0 || output.size() == 0) throw IllegalArgumentException()
                    output.toByteArray()
                } ?: throw IOException()
                runOnUiThread {
                    pendingPick = null
                    result.success(mapOf("name" to name, "bytes" to bytes))
                }
            } catch (error: Exception) {
                val message = if (error is IllegalArgumentException)
                    "Choose a file between 1 byte and 5 MB."
                else
                    "Could not read the selected file."
                runOnUiThread {
                    pendingPick = null
                    result.error("read_failed", message, null)
                }
            }
        }
    }
}
