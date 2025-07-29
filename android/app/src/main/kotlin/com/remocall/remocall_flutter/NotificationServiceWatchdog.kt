package com.remocall.remocall_flutter

import android.app.job.JobParameters
import android.app.job.JobService
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.provider.Settings
import android.text.TextUtils

class NotificationServiceWatchdog : JobService() {
    
    companion object {
        private const val TAG = "ServiceWatchdog"
        private const val JOB_ID = 9999
        private const val CHECK_INTERVAL = 10 * 1000L // 10초마다 확인 (배터리 걱정 없이 최대 안정성)
        
        fun scheduleWatchdog(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
                
                val jobInfo = JobInfo.Builder(JOB_ID, ComponentName(context, NotificationServiceWatchdog::class.java))
                    .setPersisted(true)
                    .setPeriodic(CHECK_INTERVAL)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                    .setRequiresCharging(false)
                    .setRequiresDeviceIdle(false)
                    .build()
                
                val result = jobScheduler.schedule(jobInfo)
                if (result == JobScheduler.RESULT_SUCCESS) {
                    Log.d(TAG, "✅ Watchdog job scheduled successfully")
                } else {
                    Log.e(TAG, "❌ Failed to schedule watchdog job")
                }
            }
        }
        
        fun cancelWatchdog(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
                jobScheduler.cancel(JOB_ID)
                Log.d(TAG, "Watchdog job cancelled")
            }
        }
        
        private fun isNotificationListenerEnabled(context: Context): Boolean {
            val packageName = context.packageName
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            if (!TextUtils.isEmpty(flat)) {
                val names = flat.split(":").toTypedArray()
                for (name in names) {
                    val cn = ComponentName.unflattenFromString(name)
                    if (cn != null) {
                        if (TextUtils.equals(packageName, cn.packageName)) {
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(TAG, "🔍 Watchdog job started - Checking NotificationListener status")
        
        try {
            // NotificationListener 권한 확인
            if (!isNotificationListenerEnabled(this)) {
                Log.e(TAG, "❌ NotificationListener permission lost!")
                // 권한이 없으면 재시작해도 소용없음
                jobFinished(params, false)
                return false
            }
            
            // NotificationService 재시작 시도
            Log.d(TAG, "🔄 Attempting to restart NotificationService")
            val intent = Intent(this, NotificationService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            
            Log.d(TAG, "✅ NotificationService restart attempted")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in watchdog job", e)
        }
        
        // Job 완료
        jobFinished(params, false)
        return false
    }
    
    override fun onStopJob(params: JobParameters?): Boolean {
        Log.d(TAG, "Watchdog job stopped")
        return false
    }
}