package com.remocall.remocall_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * 알림 수신 서비스 (단순화된 버전)
 * - 알림 수신 및 필터링만 담당
 * - 큐 관리는 NotificationQueueService로 위임
 * - 토큰 관리는 TokenManager로 위임
 */
class NotificationService : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationService"
        private const val KAKAO_PAY_PACKAGE = "com.kakaopay.app"
        private const val SNAPPAY_PACKAGE = "com.remocall.remocall_flutter"
        private const val KAKAO_TEST_PACKAGE = "com.test.kakaonotifier.kakao_test_notifier"
        private const val NOTIFICATION_CHANNEL_ID = "depositpro_notification_listener"
        private const val NOTIFICATION_ID = 1001
        
        // 중복 알림 방지를 위한 캐시
        private val recentNotifications = java.util.Collections.synchronizedMap(
            mutableMapOf<String, Long>()
        )
        private const val DUPLICATE_THRESHOLD_MS = 1000L
    }
    
    private lateinit var logManager: LogManager
    private lateinit var queueService: NotificationQueueService
    private lateinit var tokenManager: TokenManager
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationService created")
        
        // 서비스 초기화
        logManager = LogManager.getInstance(this)
        queueService = NotificationQueueService.getInstance(this)
        tokenManager = TokenManager.getInstance(this)
        
        logManager.logServiceLifecycle("CREATED")
        
        // Foreground 서비스 시작
        startForegroundService()
        
        // 독립적인 백그라운드 프로세스들 시작
        tokenManager.schedulePeriodicRefresh()     // 토큰 주기적 갱신
        queueService.startQueueProcessor()         // 큐 처리 프로세서 시작
        NotificationServiceWatchdog.scheduleWatchdog(this)  // 서비스 모니터링
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "NotificationService destroyed")
        
        logManager.logServiceLifecycle("DESTROYED", "Normal shutdown")
        
        // 백그라운드 프로세스들 중지
        tokenManager.cancelPeriodicRefresh()
        queueService.stopQueueProcessor()
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected")
        logManager.logServiceLifecycle("LISTENER_CONNECTED")
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected")
        logManager.logServiceLifecycle("LISTENER_DISCONNECTED")
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        
        try {
            // 개발/프로덕션 모드 확인
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isProduction = prefs.getBoolean("flutter.is_production", true)
            val isTestPackageAllowed = !isProduction && sbn.packageName == KAKAO_TEST_PACKAGE
            
            // 카카오페이, 스냅페이, 테스트앱만 처리
            if (sbn.packageName != KAKAO_PAY_PACKAGE && 
                sbn.packageName != SNAPPAY_PACKAGE &&
                !isTestPackageAllowed) {
                return  // 다른 앱은 무시
            }
            
            Log.d(TAG, "Processing notification from: ${sbn.packageName}")
            
            // 헬스체크용 타임스탬프 업데이트
            updateHealthCheckTimestamp()
            
            // 알림 데이터 추출
            val notification = sbn.notification
            val extras = notification.extras
            
            val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
            val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
            val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: text
            
            // extras를 JSONObject로 변환
            val extrasJson = JSONObject()
            extras.keySet().forEach { key ->
                try {
                    val value = extras.get(key)
                    if (value != null) {
                        extrasJson.put(key, value.toString())
                    }
                } catch (e: Exception) {
                    // ignore
                }
            }
            
            // 모든 알림 로깅
            logManager.logNotificationReceived(
                packageName = sbn.packageName,
                title = title,
                message = bigText.ifEmpty { text },
                extras = extrasJson
            )
            
            // 빈 알림 체크
            if (title.isBlank() && text.isBlank() && bigText.isBlank()) {
                if (sbn.packageName == KAKAO_PAY_PACKAGE) {
                    // 카카오페이의 빈 알림은 정상적인 그룹 업데이트
                    Log.d(TAG, "Empty KakaoPay notification (likely group update)")
                } else {
                    Log.d(TAG, "Empty notification from ${sbn.packageName}, skipping")
                }
                return
            }
            
            // 그룹 요약 알림 제외
            if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
                Log.d(TAG, "Group summary notification, skipping")
                return
            }
            
            // 카카오페이 알림이면 화면 켜기
            if (sbn.packageName == KAKAO_PAY_PACKAGE) {
                wakeUpScreen()
            }
            
            // 큐에 추가만 함 (처리는 독립적인 프로세서가 담당)
            val message = bigText.ifEmpty { text }.ifEmpty { title }
            if (message.isNotBlank()) {
                // 중복 알림 체크
                val messageHash = "${sbn.packageName}:${message.hashCode()}"
                val currentTime = System.currentTimeMillis()
                
                // 중복 알림 체크
                val lastTime = recentNotifications[messageHash]
                if (lastTime != null && currentTime - lastTime < DUPLICATE_THRESHOLD_MS) {
                    Log.d(TAG, "Duplicate notification within ${DUPLICATE_THRESHOLD_MS}ms, skipping")
                    return
                }
                
                recentNotifications[messageHash] = currentTime
                
                // 오래된 항목 정리 (1분 이상 된 항목 제거)
                recentNotifications.entries.removeIf { 
                    currentTime - it.value > 60000L 
                }
                
                val notificationId = queueService.enqueue(message)
                if (notificationId != null) {
                    Log.d(TAG, "Notification added to queue: $notificationId")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
            logManager.logError("onNotificationPosted", e)
        }
    }
    
    /**
     * Foreground 서비스 시작
     */
    private fun startForegroundService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "SnapPay 알림 리스너",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "카카오페이 알림을 모니터링합니다"
                    setShowBadge(false)
                }
                
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                this, 0,
                packageManager.getLaunchIntentForPackage(packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("SnapPay 알림 서비스")
                .setContentText("카카오페이 입금 알림을 감지하고 있습니다")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()
            
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground service started")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service", e)
        }
    }
    
    /**
     * 헬스체크 타임스탬프 업데이트
     */
    private fun updateHealthCheckTimestamp() {
        val prefs = getSharedPreferences("NotificationHealth", Context.MODE_PRIVATE)
        prefs.edit()
            .putLong("last_any_notification", System.currentTimeMillis())
            .putBoolean("is_healthy", true)
            .apply()
    }
    
    /**
     * 카카오페이 알림 원본 데이터 로깅
     */
    private fun logKakaoPayNotificationData(sbn: StatusBarNotification, extras: android.os.Bundle) {
        Log.d(TAG, "")
        Log.d(TAG, "=== 🔔 KAKAOPAY RAW NOTIFICATION DATA ===")
        Log.d(TAG, "Package: ${sbn.packageName}")
        Log.d(TAG, "ID: ${sbn.id}")
        Log.d(TAG, "PostTime: ${sbn.postTime}")
        Log.d(TAG, "Key: ${sbn.key}")
        Log.d(TAG, "Tag: ${sbn.tag}")
        Log.d(TAG, "GroupKey: ${sbn.groupKey}")
        Log.d(TAG, "")
        Log.d(TAG, "=== EXTRAS (${extras.keySet().size} keys) ===")
        extras.keySet().sorted().forEach { key ->
            try {
                val value = extras.get(key)
                val valueType = value?.javaClass?.simpleName ?: "null"
                Log.d(TAG, "[$key] ($valueType): $value")
            } catch (e: Exception) {
                Log.d(TAG, "[$key]: ERROR - ${e.message}")
            }
        }
        Log.d(TAG, "=== END KAKAOPAY DATA ===")
        Log.d(TAG, "")
    }
    
    /**
     * 화면 켜기
     */
    private fun wakeUpScreen() {
        try {
            Log.d(TAG, "💰 KakaoPay notification detected - Waking up screen")
            
            // AccessibilityService에 신호 보내기
            SnapPayAccessibilityService.setKakaoPayUnlockNeeded(true)
            
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("wake_screen", true)
            }
            startActivity(intent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error waking up screen", e)
        }
    }
}