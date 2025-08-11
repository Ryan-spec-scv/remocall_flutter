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
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.widget.RemoteViews
import java.lang.reflect.Field

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
        
        // 중복 알림 방지를 위한 캐시 (최대 100개로 제한)
        private const val MAX_CACHE_SIZE = 100
        private val recentNotifications = java.util.Collections.synchronizedMap(
            object : LinkedHashMap<String, Long>() {
                override fun removeEldestEntry(eldest: Map.Entry<String, Long>): Boolean {
                    return size > MAX_CACHE_SIZE
                }
            }
        )
        private const val DUPLICATE_THRESHOLD_MS = 1000L
    }
    
    private lateinit var logManager: LogManager
    private lateinit var queueService: NotificationQueueService
    private lateinit var tokenManager: TokenManager
    
    // extras 빈값 감지를 위한 변수들
    private val handler = Handler(Looper.getMainLooper())
    private var emptyExtrasCount = 0
    private var lastSuccessfulExtrasTime = System.currentTimeMillis()
    private val REBIND_THRESHOLD = 5  // 연속 5번 빈값이면 재바인딩 (더 빠른 대응)
    private val PREEMPTIVE_REBIND_INTERVAL = 90 * 60 * 1000L  // 1시간 30분마다 예방적 재바인딩
    private var lastRebindTime = System.currentTimeMillis()
    
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
        
        // 예방적 재바인딩 스케줄링
        schedulePreemptiveRebind()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "NotificationService destroyed")
        
        logManager.logServiceLifecycle("DESTROYED", "Normal shutdown")
        
        // 백그라운드 프로세스들 중지
        tokenManager.cancelPeriodicRefresh()
        queueService.stopQueueProcessor()
        
        // LogManager 리소스 해제
        logManager.destroy()
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected")
        logManager.logServiceLifecycle("LISTENER_CONNECTED")
        
        // 연결 시 카운터 초기화
        emptyExtrasCount = 0
        lastSuccessfulExtrasTime = System.currentTimeMillis()
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected")
        logManager.logServiceLifecycle("LISTENER_DISCONNECTED")
        
        // 연결이 끊어지면 5초 후 재바인딩 시도
        handler.postDelayed({
            logManager.logServiceLifecycle("DISCONNECT_RECOVERY", "5초 즉시 복구 시도")
            requestRebind()
        }, 5000)
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
            
            // 알림 데이터 추출 - 다층 방어 시스템
            val notification = sbn.notification
            val (title, text, bigText) = extractNotificationData(notification, sbn)
            
            // extras를 JSONObject로 변환
            val extrasJson = JSONObject()
            notification.extras.keySet().forEach { key ->
                try {
                    val value = notification.extras.get(key)
                    if (value != null) {
                        extrasJson.put(key, value.toString())
                    }
                } catch (e: Exception) {
                    // ignore
                }
            }
            
            // 카카오페이 알림인 경우 추가 디버깅 정보
            if (sbn.packageName == KAKAO_PAY_PACKAGE) {
                extrasJson.put("notificationId", sbn.id)
                extrasJson.put("key", sbn.key)
                extrasJson.put("groupKey", sbn.groupKey ?: "null")
                extrasJson.put("tag", sbn.tag ?: "null")
                extrasJson.put("flags", notification.flags)
                extrasJson.put("isGroupSummary", notification.flags and Notification.FLAG_GROUP_SUMMARY != 0)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    extrasJson.put("channelId", notification.channelId ?: "null")
                }
            }
            
            // 모든 알림 로깅
            logManager.logNotificationReceived(
                packageName = sbn.packageName,
                title = title,
                message = bigText.ifEmpty { text },
                extras = extrasJson
            )
            
            // 빈 알림 체크 및 모니터링
            if (title.isBlank() && text.isBlank() && bigText.isBlank()) {
                if (sbn.packageName == KAKAO_PAY_PACKAGE) {
                    // 카카오페이의 빈 알림 카운트 증가
                    emptyExtrasCount++
                    Log.w(TAG, "Empty KakaoPay notification (count: $emptyExtrasCount)")
                    
                    // 연속으로 빈 extras가 많이 발생하면 재바인딩
                    if (emptyExtrasCount >= REBIND_THRESHOLD) {
                        Log.e(TAG, "Too many empty extras ($emptyExtrasCount), requesting rebind")
                        logManager.logError("EMPTY_EXTRAS_REBIND", 
                            Exception("Continuous empty extras detected"), 
                            "Count: $emptyExtrasCount")
                        requestRebind()
                        emptyExtrasCount = 0
                    }
                } else {
                    Log.d(TAG, "Empty notification from ${sbn.packageName}, skipping")
                }
                return
            } else {
                // 정상적인 extras를 받으면 카운터 초기화
                if (sbn.packageName == KAKAO_PAY_PACKAGE && (title.isNotBlank() || text.isNotBlank())) {
                    emptyExtrasCount = 0
                    lastSuccessfulExtrasTime = System.currentTimeMillis()
                }
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
    
    /**
     * 다층 방어 시스템을 통한 알림 데이터 추출
     * 1순위: 표준 extras
     * 2순위: RemoteViews 직접 추출
     * 3순위: Reflection을 통한 강제 추출
     */
    private fun extractNotificationData(
        notification: Notification, 
        sbn: StatusBarNotification
    ): Triple<String, String, String> {
        var title = ""
        var text = ""
        var bigText = ""
        var extractionMethod = "unknown"
        
        // 방법 1: 표준 extras 접근
        try {
            val extras = notification.extras
            title = extras.getString(Notification.EXTRA_TITLE_BIG) 
                ?: extras.getString(Notification.EXTRA_TITLE) 
                ?: ""
            text = extras.getString(Notification.EXTRA_TEXT) ?: ""
            bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: text
            
            if (title.isNotEmpty() || text.isNotEmpty()) {
                extractionMethod = "extras"
                Log.d(TAG, "✅ Extracted via extras: title='$title', text='$text'")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to extract from extras", e)
        }
        
        // 방법 2: RemoteViews에서 직접 추출 (extras 실패 시)
        if (title.isEmpty() && text.isEmpty() && sbn.packageName == KAKAO_PAY_PACKAGE) {
            try {
                val remoteTexts = extractFromRemoteViews(notification)
                if (remoteTexts.isNotEmpty()) {
                    title = remoteTexts.getOrNull(0) ?: ""
                    text = remoteTexts.getOrNull(1) ?: ""
                    bigText = text
                    extractionMethod = "remoteviews"
                    Log.d(TAG, "✅ Extracted via RemoteViews: title='$title', text='$text'")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to extract from RemoteViews", e)
            }
        }
        
        // 방법 3: Reflection을 통한 강제 추출
        if (title.isEmpty() && text.isEmpty() && sbn.packageName == KAKAO_PAY_PACKAGE) {
            try {
                val reflectionTexts = extractWithReflection(notification)
                if (reflectionTexts.isNotEmpty()) {
                    title = reflectionTexts.getOrNull(0) ?: ""
                    text = reflectionTexts.getOrNull(1) ?: ""
                    bigText = text
                    extractionMethod = "reflection"
                    Log.d(TAG, "✅ Extracted via Reflection: title='$title', text='$text'")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to extract with reflection", e)
            }
        }
        
        // 최종 결과 검증 및 로깅
        val hasData = title.isNotEmpty() || text.isNotEmpty() || bigText.isNotEmpty()
        
        if (sbn.packageName == KAKAO_PAY_PACKAGE) {
            if (hasData) {
                emptyExtrasCount = 0
                lastSuccessfulExtrasTime = System.currentTimeMillis()
                Log.d(TAG, "✅ 데이터 추출 성공 ($extractionMethod): '$title' / '$text'")
            } else {
                emptyExtrasCount++
                Log.e(TAG, "❌ 모든 방법으로 데이터 추출 실패 (count: $emptyExtrasCount)")
                
                // 즉시 재바인딩 트리거 (더 공격적인 대응)
                if (emptyExtrasCount >= REBIND_THRESHOLD) {
                    Log.e(TAG, "🔄 Emergency rebind triggered due to extraction failures")
                    logManager.logError("EMERGENCY_REBIND", 
                        Exception("Continuous extraction failures"), 
                        "Count: $emptyExtrasCount, Method: all_failed")
                    requestRebind()
                    emptyExtrasCount = 0
                }
            }
        }
        
        return Triple(title, text, bigText)
    }
    
    /**
     * RemoteViews에서 텍스트 추출
     */
    private fun extractFromRemoteViews(notification: Notification): List<String> {
        val texts = mutableListOf<String>()
        
        try {
            // contentView와 bigContentView 모두 확인
            val remoteViews = notification.bigContentView ?: notification.contentView
            
            if (remoteViews != null) {
                val extractedTexts = extractTextsFromRemoteViews(remoteViews)
                texts.addAll(extractedTexts)
                
                // 카카오페이 알림 패턴 필터링
                val filteredTexts = extractedTexts.filter { 
                    it.contains("원") || it.contains("님이") || it.contains("보냈")
                }
                
                if (filteredTexts.isNotEmpty()) {
                    texts.clear()
                    texts.addAll(filteredTexts)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting from RemoteViews", e)
        }
        
        return texts
    }
    
    /**
     * RemoteViews의 Action들에서 텍스트 추출
     */
    private fun extractTextsFromRemoteViews(remoteViews: RemoteViews): List<String> {
        val texts = mutableListOf<String>()
        
        try {
            val remoteViewsClass = remoteViews.javaClass
            val mActionsField = remoteViewsClass.getDeclaredField("mActions")
            mActionsField.isAccessible = true
            
            @Suppress("UNCHECKED_CAST")
            val mActions = mActionsField.get(remoteViews) as? ArrayList<Any>
            
            mActions?.forEach { action ->
                try {
                    val actionClass = action.javaClass
                    
                    // ReflectionAction에서 값 추출
                    if (actionClass.simpleName.contains("ReflectionAction")) {
                        val valueField = actionClass.getDeclaredField("value")
                        valueField.isAccessible = true
                        val value = valueField.get(action)
                        
                        if (value is CharSequence && value.toString().isNotEmpty()) {
                            texts.add(value.toString())
                        }
                    }
                    
                    // TextViewAction에서 값 추출
                    if (actionClass.simpleName.contains("TextViewAction")) {
                        val textField = actionClass.getDeclaredField("text")
                        textField.isAccessible = true
                        val textValue = textField.get(action)
                        
                        if (textValue is CharSequence && textValue.toString().isNotEmpty()) {
                            texts.add(textValue.toString())
                        }
                    }
                } catch (e: Exception) {
                    // 개별 action 처리 실패는 무시
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting texts from RemoteViews", e)
        }
        
        return texts.distinct() // 중복 제거
    }
    
    /**
     * Reflection을 통한 강제 데이터 추출
     */
    private fun extractWithReflection(notification: Notification): List<String> {
        val texts = mutableListOf<String>()
        
        try {
            // Notification 객체의 모든 필드 검사
            val fields = notification.javaClass.declaredFields
            
            for (field in fields) {
                try {
                    field.isAccessible = true
                    val value = field.get(notification)
                    
                    when {
                        value is CharSequence && value.toString().isNotEmpty() -> {
                            texts.add(value.toString())
                        }
                        value is Bundle -> {
                            // Bundle 내부의 모든 값 검사
                            for (key in value.keySet()) {
                                try {
                                    val bundleValue = value[key]
                                    if (bundleValue is CharSequence && bundleValue.toString().isNotEmpty()) {
                                        texts.add(bundleValue.toString())
                                    }
                                } catch (e: Exception) {
                                    // 무시
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    // 개별 필드 접근 실패는 무시
                }
            }
            
            // 카카오페이 패턴에 맞는 텍스트만 필터링
            val filtered = texts.filter { text ->
                text.contains("원") || text.contains("님이") || 
                text.contains("보냈") || text.contains("카카오페이")
            }
            
            return if (filtered.isNotEmpty()) filtered else texts
        } catch (e: Exception) {
            Log.e(TAG, "Error in reflection extraction", e)
            return emptyList()
        }
    }
    
    /**
     * 예방적 재바인딩 스케줄링
     * 1시간 30분마다 예방적으로 재바인딩 수행
     */
    private fun schedulePreemptiveRebind() {
        val rebindRunnable = object : Runnable {
            override fun run() {
                val currentTime = System.currentTimeMillis()
                val timeSinceLastRebind = currentTime - lastRebindTime
                
                if (timeSinceLastRebind >= PREEMPTIVE_REBIND_INTERVAL) {
                    Log.d(TAG, "🔄 Preemptive rebind after ${timeSinceLastRebind / 1000 / 60} minutes")
                    logManager.logServiceLifecycle("PREEMPTIVE_REBIND", "1시간 30분 예방적 재바인딩")
                    requestRebind()
                    lastRebindTime = currentTime
                }
                
                // 30분 체크 로그 추가
                logManager.logServiceLifecycle("REBIND_CHECK", "30분 재바인딩 체크 완료")
                
                // 다음 체크를 30분 후에 예약
                handler.postDelayed(this, 30 * 60 * 1000L)
            }
        }
        
        // 최초 실행은 1시간 30분 후
        handler.postDelayed(rebindRunnable, PREEMPTIVE_REBIND_INTERVAL)
    }
    
    /**
     * NotificationListenerService 재바인딩 요청
     * extras 접근 실패 문제 해결을 위해 서비스 바인딩을 갱신
     */
    private fun requestRebind() {
        lastRebindTime = System.currentTimeMillis()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Android N 이상에서는 requestRebind API 사용
                requestRebind(ComponentName(this, this::class.java))
                Log.d(TAG, "✅ Rebind requested successfully")
                logManager.logServiceLifecycle("REBIND_REQUESTED", "API24+ requestRebind")
            } else {
                // Android N 미만에서는 서비스 재시작으로 대체
                restartServiceForRebind()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request rebind", e)
            logManager.logError("REBIND_FAILED", e, "Attempting service restart")
            // 재바인딩 실패 시 서비스 재시작 시도
            restartServiceForRebind()
        }
    }
    
    /**
     * 서비스를 일시적으로 비활성화했다가 다시 활성화하여 재바인딩
     * Android N 미만 또는 requestRebind 실패 시 사용
     */
    private fun restartServiceForRebind() {
        try {
            val componentName = ComponentName(this, this::class.java)
            val pm = packageManager
            
            // 서비스 일시 비활성화
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            
            // 1초 후 다시 활성화
            handler.postDelayed({
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.d(TAG, "✅ Service restarted for rebind")
                logManager.logServiceLifecycle("SERVICE_RESTARTED", "Manual rebind")
            }, 1000)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart service for rebind", e)
            logManager.logError("SERVICE_RESTART_FAILED", e, "Manual rebind failed")
        }
    }
}