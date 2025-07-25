package com.remocall.remocall_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "Boot completed, checking notification access")
            
            // NotificationListenerService는 시스템이 자동으로 시작하므로
            // 여기서는 앱이 설치되어 있고 권한이 있다는 것만 확인
            try {
                val componentName = android.provider.Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners"
                )
                
                if (componentName != null && componentName.contains(context.packageName)) {
                    Log.d(TAG, "Notification access is enabled, service will start automatically")
                } else {
                    Log.w(TAG, "Notification access is not enabled")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking notification access", e)
            }
        }
    }
}