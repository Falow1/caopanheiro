package com.caopanheiro.internal

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "Baixar" of the invite QR Code and poster, and the CSV files of the data
 * export (E2): the Android "Save as" window (ACTION_CREATE_DOCUMENT) lets the
 * manager pick the folder, and the file is written where they chose. No
 * permission is needed. The answer to Flutter is "saved", "cancelled" or an
 * error.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var content: ByteArray? = null
    private val allowedTypes = setOf("image/png", "text/csv")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng" && call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                val mime = if (call.method == "savePng") "image/png" else call.argument<String>("mime")
                when {
                    name.isNullOrBlank() || bytes == null ->
                        result.error("invalid", "Nome ou arquivo ausente.", null)
                    mime == null || mime !in allowedTypes ->
                        result.error("invalid", "Tipo de arquivo não permitido.", null)
                    pending != null ->
                        result.error("busy", "Outro arquivo está sendo salvo.", null)
                    else -> askWhere(name, bytes, mime, result)
                }
            }
    }

    private fun askWhere(name: String, bytes: ByteArray, mime: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pending = result
        content = bytes
        try {
            startActivityForResult(intent, SAVE_REQUEST)
        } catch (error: ActivityNotFoundException) {
            pending = null
            content = null
            result.error("unavailable", "Sem janela para salvar arquivos.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val result = pending ?: return
        val bytes = content
        pending = null
        content = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success("cancelled")
            return
        }
        val main = Handler(Looper.getMainLooper())
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("Arquivo indisponível.")
                stream.use { it.write(bytes) }
                main.post { result.success("saved") }
            } catch (error: Exception) {
                // An empty file left where the person chose would look saved.
                try {
                    DocumentsContract.deleteDocument(contentResolver, uri)
                } catch (_: Exception) {
                }
                main.post { result.error("write_failed", error.message, null) }
            }
        }.start()
    }

    companion object {
        private const val CHANNEL = "caopanheiro/files"
        private const val SAVE_REQUEST = 4107
    }
}
