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
        private const val CHECK_INTERVAL = 10 * 1000L // 10초마다 확인
        
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
        Log.d(TAG, "🔍 Watchdog job started - Intelligent health check")
        
        try {
            // NotificationListener 권한 확인
            if (!isNotificationListenerEnabled(this)) {
                Log.e(TAG, "❌ NotificationListener permission lost!")
                // 권한이 없으면 재시작해도 소용없음
                jobFinished(params, false)
                return false
            }
            
            // 헬스체크 상태 확인
            val healthPrefs = getSharedPreferences("NotificationHealth", Context.MODE_PRIVATE)
            val lastNotificationTime = healthPrefs.getLong("last_any_notification", 0)
            val lastHealthCheck = healthPrefs.getLong("last_health_check", 0)
            val isHealthy = healthPrefs.getBoolean("is_healthy", true)
            
            val timeSinceLastNotification = System.currentTimeMillis() - lastNotificationTime
            val timeSinceLastHealthCheck = System.currentTimeMillis() - lastHealthCheck
            
            Log.d(TAG, "Last notification: ${timeSinceLastNotification/1000}s ago")
            Log.d(TAG, "Last health check: ${timeSinceLastHealthCheck/1000}s ago")
            Log.d(TAG, "Service healthy: $isHealthy")
            
            // 지능형 재시작 조건
            val shouldRestart = when {
                // 3분 이상 알림이 없고, 헬스체크도 2분 이상 없으면
                timeSinceLastNotification > 180000 && timeSinceLastHealthCheck > 120000 -> {
                    Log.w(TAG, "⚠️ No notifications for 3+ minutes AND no health check for 2+ minutes")
                    true
                }
                // 헬스체크가 unhealthy로 표시되면
                !isHealthy && timeSinceLastHealthCheck < 120000 -> {
                    Log.w(TAG, "⚠️ Service marked as unhealthy")
                    true
                }
                // 5분 이상 헬스체크가 없으면 (서비스가 죽었을 가능성)
                timeSinceLastHealthCheck > 300000 -> {
                    Log.w(TAG, "⚠️ No health check for 5+ minutes - service might be dead")
                    true
                }
                else -> {
                    Log.d(TAG, "✅ Service appears healthy, no restart needed")
                    false
                }
            }
            
            if (shouldRestart) {
                // 서비스 실행 상태 확인
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
                val isServiceRunning = runningServices.any { 
                    it.service.className == NotificationService::class.java.name 
                }
                
                if (!isServiceRunning) {
                    // 서비스가 죽었으면 재시작
                    Log.w(TAG, "⚠️ Service not running - restarting")
                    val intent = Intent(this, NotificationService::class.java)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    
                    Log.d(TAG, "✅ Service restart attempted")
                } else {
                    // 서비스는 실행 중이지만 unhealthy 상태
                    Log.w(TAG, "⚠️ Service is running but appears unhealthy")
                    
                    // 헬스 상태를 unhealthy로 마킹
                    healthPrefs.edit()
                        .putBoolean("is_healthy", false)
                        .putLong("last_health_issue", System.currentTimeMillis())
                        .apply()
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in watchdog job", e)
            // 에러 발생 시에는 안전을 위해 재시작 시도
            try {
                val intent = Intent(this, NotificationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                Log.d(TAG, "Service restart attempted after error")
            } catch (restartError: Exception) {
                Log.e(TAG, "Failed to restart service after error", restartError)
            }
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