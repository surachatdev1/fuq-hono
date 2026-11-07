package com.nwl.nwl_secret_login

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var soundResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nwl/reminder_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickSound") {
                    result.notImplemented()
                } else if (soundResult != null) {
                    result.error("BUSY", "Sound picker is already open", null)
                } else {
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                            (call.arguments as? String)?.takeIf { it.isNotEmpty() }?.let(Uri::parse))
                    }
                    soundResult = result
                    try { startActivityForResult(intent, 8201) }
                    catch (e: Exception) { soundResult = null; result.error("PICKER", "Cannot open sound picker", null) }
                }
            }
    }
    @Deprecated("Android activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8201) return
        val result = soundResult ?: return
        soundResult = null
        if (resultCode != Activity.RESULT_OK) { result.success(null); return }
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
            data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }
        result.success(uri?.toString() ?: "")
    }
}
