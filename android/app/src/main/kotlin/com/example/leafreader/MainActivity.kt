package com.example.leafreader

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
	companion object {
		private const val INTENT_CHANNEL = "com.example.leafreader/intent"
	}

	private var pendingPath: String? = null
	private var intentChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).apply {
			setMethodCallHandler { call, result ->
				when (call.method) {
					"getInitialIntent" -> result.success(pendingPath)
					"consumeInitialIntent" -> {
						pendingPath = null
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
		}

		handleIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleIntent(intent)
	}

	private fun handleIntent(intent: Intent?) {
		if (intent == null) return

		when (intent.action) {
			Intent.ACTION_VIEW, Intent.ACTION_SEND -> {
				val uri = extractUri(intent) ?: return
				val path = persistUriToCache(uri)
				if (path != null) {
					pendingPath = path
					try {
						intentChannel?.invokeMethod("onNewIntent", path)
					} catch (_: Exception) {
						// Ignore MissingPluginException if Flutter isn't ready yet.
					}
				}
			}
		}
	}

	private fun extractUri(intent: Intent): Uri? {
		intent.data?.let { return it }

		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
		} else {
			@Suppress("DEPRECATION")
			intent.getParcelableExtra(Intent.EXTRA_STREAM)
		}
	}

	private fun persistUriToCache(uri: Uri): String? {
		return when (uri.scheme) {
			ContentResolver.SCHEME_FILE -> uri.path
			ContentResolver.SCHEME_CONTENT -> copyContentUri(uri)
			else -> uri.path
		}
	}

	private fun copyContentUri(uri: Uri): String? {
		return try {
			val resolver = contentResolver

			val displayName = resolver.query(uri, null, null, null, null)?.use { cursor ->
				val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
				if (nameIndex != -1 && cursor.moveToFirst()) {
					cursor.getString(nameIndex)
				} else {
					null
				}
			}

			val safeName = (displayName ?: "shared_file").ifEmpty { "shared_file" }
			val baseFile = File(cacheDir, safeName)
			val targetFile = if (baseFile.exists()) {
				File(cacheDir, "${System.currentTimeMillis()}_$safeName")
			} else {
				baseFile
			}

			resolver.openInputStream(uri)?.use { inputStream ->
				FileOutputStream(targetFile).use { outputStream ->
					inputStream.copyTo(outputStream)
				}
				targetFile.absolutePath
			}
		} catch (_: Exception) {
			null
		}
	}
}
