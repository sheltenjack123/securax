package com.example.my_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.securax/admin"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val adminComponent = ComponentName(this, AdminReceiver::class.java)
                val policyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

                when (call.method) {
                    "requestAdmin" -> {
                        if (policyManager.isAdminActive(adminComponent)) {
                            result.success(true)
                        } else {
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                            intent.putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                "Securax needs Device Admin to detect wrong phone password attempts."
                            )
                            startActivity(intent)
                            result.success(true)
                        }
                    }
                    "isAdminActive" -> {
                        result.success(policyManager.isAdminActive(adminComponent))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
