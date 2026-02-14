package com.example.my_app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.UserHandle
import android.os.SystemClock
import android.util.Log

class AdminReceiver : DeviceAdminReceiver() {
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        handleFailedAttempt(context)
    }

    override fun onPasswordFailed(context: Context, intent: Intent, user: UserHandle) {
        super.onPasswordFailed(context, intent, user)
        handleFailedAttempt(context)
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        resetFailedAttempts(context)
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent, user: UserHandle) {
        super.onPasswordSucceeded(context, intent, user)
        resetFailedAttempts(context)
    }

    private fun handleFailedAttempt(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val armed = prefs.getBoolean(KEY_SYSTEM_MONITORING_ENABLED, false)
        if (!armed) {
            Log.d(TAG, "System password failed, but monitoring is DISABLED (armed=false).")
            return
        }

        // Some devices/ROMs can deliver multiple callbacks for a single failure.
        // Debounce to avoid starting multiple camera services concurrently.
        val now = SystemClock.elapsedRealtime()
        val last = prefs.getLong(KEY_LAST_EVENT_MS, 0L)
        if (now - last < 400L) {
            Log.d(TAG, "Debounced duplicate failure event.")
            return
        }
        prefs.edit().putLong(KEY_LAST_EVENT_MS, now).apply()

        val failedCount = prefs.getInt(KEY_FAILED_COUNT, 0) + 1
        prefs.edit().putInt(KEY_FAILED_COUNT, failedCount).apply()

        Log.d(TAG, "System password failed: attempts=$failedCount. Starting CameraService.")
        triggerCameraService(context)
        prefs.edit().putInt(KEY_FAILED_COUNT, 0).apply()
    }

    private fun resetFailedAttempts(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(KEY_FAILED_COUNT, 0).apply()
    }

    private fun triggerCameraService(context: Context) {
        val serviceIntent = Intent(context, CameraService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CameraService from lock event.", e)
        }
    }

    companion object {
        private const val TAG = "SecuraxAdmin"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        private const val KEY_SYSTEM_MONITORING_ENABLED = "flutter.system_monitoring_enabled"

        // Native-only counter, to avoid clashes with app PIN counter.
        private const val KEY_FAILED_COUNT = "securax_system_failed_count"
        private const val KEY_LAST_EVENT_MS = "securax_last_failed_event_ms"
    }
}
