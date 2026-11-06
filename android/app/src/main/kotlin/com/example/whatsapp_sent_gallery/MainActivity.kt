package com.example.whatsapp_sent_gallery

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "whatsapp_sent_gallery/saf"
    private val prefsName = "sent_gallery_prefs"
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAccount: String? = null
    private var methodChannel: MethodChannel? = null

    private val folderPicker = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        val result = pendingResult
        pendingResult = null
        val account = pendingAccount
        pendingAccount = null

        if (uri == null || account == null) {
            result?.error("CANCELLED", "Pemilihan folder dibatalkan", null)
            return@registerForActivityResult
        }

        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            contentResolver.takePersistableUriPermission(uri, flags)
            getSharedPreferences(prefsName, MODE_PRIVATE)
                .edit()
                .putString("folder_$account", uri.toString())
                .apply()
            result?.success(uri.toString())
        } catch (e: Exception) {
            result?.error("PERMISSION_ERROR", e.message, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "chooseFolder" -> {
                    val account = call.argument<String>("account")
                    if (account != "regular" && account != "business") {
                        result.error("BAD_ACCOUNT", "Jenis akun tidak valid", null)
                    } else {
                        pendingResult = result
                        pendingAccount = account
                        folderPicker.launch(null)
                    }
                }
                "listImages" -> {
                    val account = call.argument<String>("account") ?: "regular"
                    val uriString = getSharedPreferences(prefsName, MODE_PRIVATE)
                        .getString("folder_$account", null)
                    if (uriString == null) {
                        result.error("NO_FOLDER", "Folder Sent belum dipilih", null)
                    } else {
                        executor.execute {
                            try {
                                val items = listImageFiles(Uri.parse(uriString))
                                runOnUiThread { result.success(items) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("LIST_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                }
                "readImage" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("BAD_URI", "URI gambar kosong", null)
                    } else {
                        executor.execute {
                            try {
                                val bytes = contentResolver.openInputStream(Uri.parse(uriString))
                                    ?.use { input ->
                                        val output = ByteArrayOutputStream()
                                        input.copyTo(output)
                                        output.toByteArray()
                                    }
                                runOnUiThread {
                                    if (bytes == null) {
                                        result.error("READ_ERROR", "Tidak dapat membaca gambar", null)
                                    } else {
                                        result.success(bytes)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("READ_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun listImageFiles(treeUri: Uri): List<Map<String, Any>> {
        val root = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Folder tidak dapat diakses")
        if (!root.canRead()) throw SecurityException("Tidak ada izin membaca folder")

        val output = mutableListOf<Map<String, Any>>()
        fun walk(folder: DocumentFile) {
            folder.listFiles().forEach { file ->
                if (file.isDirectory) {
                    walk(file)
                } else {
                    val mime = file.type ?: ""
                    val name = file.name ?: "image"
                    val looksLikeImage = mime.startsWith("image/") ||
                        name.lowercase().let {
                            it.endsWith(".jpg") || it.endsWith(".jpeg") ||
                            it.endsWith(".png") || it.endsWith(".webp") ||
                            it.endsWith(".gif") || it.endsWith(".heic")
                        }
                    if (looksLikeImage) {
                        output.add(
                            mapOf(
                                "uri" to file.uri.toString(),
                                "name" to name,
                                "modified" to file.lastModified()
                            )
                        )
                    }
                }
            }
        }
        walk(root)
        return output.sortedByDescending { it["modified"] as Long }
    }
}
