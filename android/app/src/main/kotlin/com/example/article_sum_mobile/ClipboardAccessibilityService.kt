package com.example.article_sum_mobile

import android.accessibilityservice.AccessibilityService
import android.content.ClipboardManager
import android.content.Context
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * Accessibility services keep clipboard read access while backgrounded, unlike
 * regular app processes on Android 10+. Used only to detect article-link
 * copies while the app has no foreground UI; actual processing is delegated
 * to the existing Dart pipeline via a headless FlutterEngine so there's a
 * single source of truth for the Supabase/backend calls.
 */
class ClipboardAccessibilityService : AccessibilityService() {
    private var lastSeenText: String? = null
    private lateinit var clipboardManager: ClipboardManager
    private var engine: FlutterEngine? = null
    private val urlRegex = Regex("^https?://\\S+$", RegexOption.IGNORE_CASE)

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener { handleClipChange() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboardManager.addPrimaryClipChangedListener(clipListener)
        if (lastSeenPref() == null) {
            setLastSeenPref(currentClipText() ?: "")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: this service only needs to stay bound for clipboard access.
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        clipboardManager.removePrimaryClipChangedListener(clipListener)
        engine?.destroy()
        engine = null
    }

    private fun currentClipText(): String? {
        val clip = clipboardManager.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        return clip.getItemAt(0).coerceToText(applicationContext)?.toString()?.trim()
    }

    private fun flutterPrefs() =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun lastSeenPref(): String? =
        flutterPrefs().getString("flutter.$LAST_SEEN_KEY", null)

    private fun setLastSeenPref(text: String) {
        flutterPrefs().edit().putString("flutter.$LAST_SEEN_KEY", text).apply()
    }

    private fun handleClipChange() {
        val text = currentClipText()
        if (text.isNullOrEmpty() || text == lastSeenPref()) return
        setLastSeenPref(text)
        if (!urlRegex.matches(text)) return

        Toast.makeText(applicationContext, "링크 감지됨 — 백그라운드에서 처리 중...", Toast.LENGTH_SHORT).show()
        dispatchToDart(text)
    }

    private fun dispatchToDart(url: String) {
        val handle = flutterPrefs().getLong("flutter.$CALLBACK_HANDLE_KEY", -1L)
        if (handle == -1L) return
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle) ?: return

        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(applicationContext)
        }
        loader.ensureInitializationComplete(applicationContext, null)

        val flutterEngine = FlutterEngine(applicationContext)
        engine = flutterEngine
        val dartCallback = DartExecutor.DartCallback(assets, loader.findAppBundlePath(), callbackInfo)
        flutterEngine.dartExecutor.executeDartCallback(dartCallback)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    channel.invokeMethod("processLink", url)
                    result.success(null)
                }
                "error" -> {
                    val message = call.arguments as? String ?: "unknown error"
                    Toast.makeText(applicationContext, "링크 처리 실패: $message", Toast.LENGTH_SHORT).show()
                    result.success(null)
                }
                "done" -> {
                    result.success(null)
                    flutterEngine.destroy()
                    if (engine === flutterEngine) engine = null
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val CHANNEL = "com.example.article_sum_mobile/clipboard_bg"
        const val CALLBACK_HANDLE_KEY = "clipboard_callback_handle"
        const val LAST_SEEN_KEY = "clipboard_last_seen_text"
    }
}
