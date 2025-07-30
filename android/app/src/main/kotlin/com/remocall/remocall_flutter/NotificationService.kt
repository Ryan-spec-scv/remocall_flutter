package com.remocall.remocall_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.concurrent.scheduleAtFixedRate
import kotlinx.coroutines.delay
import android.os.PowerManager
import android.app.KeyguardManager
import android.view.WindowManager

class NotificationService : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationService"
        private const val CHANNEL = "com.remocall/notifications"
        private const val KAKAO_TALK_PACKAGE = "com.kakao.talk"
        private const val KAKAO_PAY_PACKAGE = "com.kakaopay.app"
        private const val SNAPPAY_PACKAGE = "com.remocall.remocall_flutter"
        private const val KAKAO_TEST_PACKAGE = "com.test.kakaonotifier.kakao_test_notifier" // 테스트 앱 패키지
        private const val NOTIFICATION_CHANNEL_ID = "depositpro_notification_listener"
        private const val NOTIFICATION_ID = 1001
        private const val WAKE_LOCK_TAG = "SnapPay::NotificationListener"
        private const val MAX_TOKEN_REFRESH_RETRY = 20 // 토큰 갱신 최대 재시도 회수
        private const val MAX_QUEUE_ITEM_RETRY = 20 // 큐 아이템 최대 재시도 회수
        
        // 타임스탬프 생성 함수 (UTC 기준)
        fun getKSTTimestamp(): Long {
            // 현재 시간의 밀리초를 그대로 반환 (UTC 기준)
            return System.currentTimeMillis()
        }
        
        // 토큰 갱신 함수
        fun refreshAccessToken(context: Context, refreshToken: String, retryCount: Int = 0): Boolean {
            try {
                Log.d(TAG, "Attempting to refresh access token...")
                
                // API URL 가져오기
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isProduction = prefs.getBoolean("flutter.is_production", true)
                val apiUrl = if (isProduction) {
                    "https://admin-api.snappay.online/api/shop/auth/refresh"
                } else {
                    "https://kakaopay-admin-api.flexteam.kr/api/shop/auth/refresh"
                }
                
                val url = URL(apiUrl)
                val connection = url.openConnection() as HttpURLConnection
                
                try {
                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.connectTimeout = 10000
                    connection.readTimeout = 10000
                    connection.doOutput = true
                    
                    val requestData = JSONObject().apply {
                        put("refresh_token", refreshToken)
                    }
                    
                    connection.outputStream.use { os ->
                        val input = requestData.toString().toByteArray(charset("utf-8"))
                        os.write(input, 0, input.size)
                    }
                    
                    val responseCode = connection.responseCode
                    
                    if (responseCode == 200 || responseCode == 201) {
                        val response = connection.inputStream.bufferedReader().use { it.readText() }
                        val jsonResponse = JSONObject(response)
                        
                        if (jsonResponse.getBoolean("success")) {
                            val data = jsonResponse.getJSONObject("data")
                            val newAccessToken = data.getString("access_token")
                            val newRefreshToken = data.optString("refresh_token", refreshToken)
                            
                            // 새 토큰 저장
                            val editor = prefs.edit()
                            editor.putString("flutter.access_token", newAccessToken)
                            editor.putString("flutter.refresh_token", newRefreshToken)
                            editor.apply()
                            
                            Log.d(TAG, "✅ Token refresh successful")
                            LogManager.getInstance(context).logTokenRefresh(true)
                            return true
                        }
                    }
                    
                    Log.e(TAG, "Token refresh failed with status code: $responseCode")
                    LogManager.getInstance(context).logTokenRefresh(false, "Status code: $responseCode")
                    return false
                } finally {
                    connection?.disconnect()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error refreshing token: ${e.message}", e)
                LogManager.getInstance(context).logTokenRefresh(false, "Exception: ${e.message}")
                return false
            }
        }
        
        // 공통 서버 전송 함수
        fun sendNotificationToServer(
            context: Context,
            message: String,
            accessToken: String,
            onResult: (Boolean, String) -> Unit,
            tokenRefreshCount: Int = 0
        ) {
            try {
                Log.d(TAG, "=== SEND NOTIFICATION TO SERVER (Common) ===")
                
                // API 호출을 위한 데이터 준비 (KST 타임스탬프 사용)
                val notificationData = JSONObject().apply {
                    put("message", message)
                    put("timestamp", getKSTTimestamp())
                }
                
                Log.d(TAG, "Sending data: $notificationData")
                
                // SharedPreferences에서 API URL 가져오기 (개발/프로덕션 구분)
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isProduction = prefs.getBoolean("flutter.is_production", true)
                val apiUrl = if (isProduction) {
                    "https://admin-api.snappay.online/api/kakao-deposits/webhook"
                } else {
                    "https://kakaopay-admin-api.flexteam.kr/api/kakao-deposits/webhook"
                }
                
                Log.d(TAG, "Using API URL: $apiUrl (isProduction: $isProduction)")
                
                // HTTP 요청 직접 수행
                val url = java.net.URL(apiUrl)
                val connection = url.openConnection() as java.net.HttpURLConnection
                
                try {
                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Authorization", "Bearer $accessToken")
                    connection.connectTimeout = 10000
                    connection.readTimeout = 10000
                    connection.doOutput = true
                    connection.doInput = true
                    connection.useCaches = false
                    
                    Log.d(TAG, "Sending POST request to: $url")
                    
                    connection.outputStream.use { os ->
                        val input = notificationData.toString().toByteArray(charset("utf-8"))
                        os.write(input, 0, input.size)
                    }
                    
                    val responseCode = connection.responseCode
                    Log.d(TAG, "Server response code: $responseCode")
                    
                    if (responseCode == 200 || responseCode == 201) {
                        val response = connection.inputStream.bufferedReader().use { it.readText() }
                        Log.d(TAG, "✅ Notification sent to server successfully")
                        Log.d(TAG, "Server response: $response")
                        
                        // 서버 전송 성공 로그
                        context?.let {
                            LogManager.getInstance(it).logServerRequest(
                                url = apiUrl,
                                requestData = notificationData,
                                responseCode = responseCode,
                                responseBody = response,
                                success = true
                            )
                        }
                        
                        // 응답 파싱
                        try {
                            val jsonResponse = JSONObject(response)
                            val success = jsonResponse.getBoolean("success")
                            val data = jsonResponse.getJSONObject("data")
                            val matchStatus = data.getString("match_status")
                            
                            // 서버 응답 상세 로깅
                            val transactionId = data.optString("transaction_id", null)
                            val depositId = data.optString("deposit_id", null)
                            val errorDetail = data.optString("error_detail", null)
                            
                            context?.let {
                                LogManager.getInstance(it).logServerResponseDetail(
                                    matchStatus = matchStatus,
                                    transactionId = transactionId,
                                    depositId = depositId,
                                    errorDetail = errorDetail
                                )
                            }
                            
                            val responseMessage = when (matchStatus) {
                                "matched" -> "✅ 입금이 자동으로 매칭되어 거래가 완료되었습니다."
                                "auto_created" -> "✅ 매칭되는 거래가 없어 새 거래를 자동으로 생성했습니다."
                                "duplicate" -> "ℹ️ 이미 처리된 입금입니다."
                                "failed" -> "❌ 자동 거래 생성에 실패했습니다. 수동 확인이 필요합니다."
                                else -> "서버 응답: $matchStatus"
                            }
                            
                            onResult(success && matchStatus != "failed", responseMessage)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing response: ${e.message}")
                            context?.let {
                                LogManager.getInstance(it).logError("sendNotificationToServer.parsing", e, "Response: $response")
                            }
                            onResult(true, "서버 응답 파싱 오류: ${e.message}")
                        }
                    } else if (responseCode == 401) {
                        // 401 Unauthorized - 토큰 만료
                        Log.e(TAG, "❌ 401 Unauthorized - Token expired, attempting to refresh token...")
                        
                        // 토큰 갱신 시도
                        val refreshToken = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .getString("flutter.refresh_token", null)
                        
                        if (refreshToken != null && tokenRefreshCount < MAX_TOKEN_REFRESH_RETRY) {
                            val refreshSuccess = refreshAccessToken(context, refreshToken, tokenRefreshCount)
                            if (refreshSuccess) {
                                // 토큰 갱신 성공 - 새 토큰으로 재시도
                                val newAccessToken = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                    .getString("flutter.access_token", null)
                                
                                if (newAccessToken != null) {
                                    Log.d(TAG, "Token refreshed successfully, retrying with new token... (attempt ${tokenRefreshCount + 1}/$MAX_TOKEN_REFRESH_RETRY)")
                                    // 재귀 호출로 새 토큰으로 다시 시도
                                    sendNotificationToServer(context, message, newAccessToken, onResult, tokenRefreshCount + 1)
                                    return
                                }
                            }
                        } else if (tokenRefreshCount >= MAX_TOKEN_REFRESH_RETRY) {
                            Log.e(TAG, "Token refresh retry limit reached ($MAX_TOKEN_REFRESH_RETRY)")
                        }
                        
                        // 토큰 갱신 실패
                        onResult(false, "인증 토큰이 만료되었습니다. 다시 로그인해주세요.")
                    } else {
                        val errorStream = connection.errorStream
                        val response = if (errorStream != null) {
                            errorStream.bufferedReader().use { it.readText() }
                        } else {
                            "No error response"
                        }
                        Log.e(TAG, "❌ Server error ($responseCode): $response")
                        
                        // 에러 메시지 파싱 시도
                        var errorMessage = "서버 오류 ($responseCode)"
                        try {
                            val jsonError = JSONObject(response)
                            errorMessage = jsonError.getString("message")
                        } catch (e: Exception) {
                            errorMessage = "서버 오류 ($responseCode): $response"
                        }
                        
                        // 서버 전송 실패 로그
                        context?.let {
                            LogManager.getInstance(it).logServerRequest(
                                url = apiUrl,
                                requestData = notificationData,
                                responseCode = responseCode,
                                responseBody = response,
                                success = false
                            )
                        }
                        
                        onResult(false, errorMessage)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Connection error: ${e.message}", e)
                    context?.let {
                        LogManager.getInstance(it).logError("sendNotificationToServer.connection", e, "URL: $apiUrl")
                    }
                    onResult(false, "네트워크 오류: ${e.message}")
                } finally {
                    connection?.disconnect()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in sendNotificationToServer: ${e.message}", e)
                context?.let {
                    LogManager.getInstance(it).logError("sendNotificationToServer.general", e, "Message: $message")
                }
                onResult(false, "전송 오류: ${e.message}")
            }
        }
    }
    
    private var methodChannel: MethodChannel? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val recentNotifications = ConcurrentHashMap.newKeySet<String>() // Thread-safe 중복 방지
    private var retryTimer: Timer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var logManager: LogManager
    private var healthCheckTimer: Timer? = null
    private var tokenRefreshTimer: Timer? = null
    @Volatile
    private var isRefreshingToken = false
    private val MAX_RECENT_NOTIFICATIONS = 50 // 메모리 사용량 제한
    
    @Volatile
    private var isRunning = false
    
    // 큐 처리 상태만 메모리에 유지 (실제 큐는 SharedPreferences에 저장)
    @Volatile
    private var isProcessingQueue = false
    
    // 현재 처리 중인 알림 ID 추적 (중복 전송 방지)
    private val processingNotifications = ConcurrentHashMap.newKeySet<String>()
    
    // 실패한 알림 데이터 클래스
    data class FailedNotification(
        val id: String = UUID.randomUUID().toString(),
        val message: String,
        val shopCode: String,
        val timestamp: Long,
        val retryCount: Int = 0,
        val lastRetryTime: Long = 0,
        val createdAt: Long = System.currentTimeMillis(),
        val nextRetryTime: Long = System.currentTimeMillis()  // 다음 재시도 가능 시간
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("id", id)
                put("message", message)
                put("shopCode", shopCode)
                put("timestamp", timestamp)
                put("retryCount", retryCount)
                put("lastRetryTime", lastRetryTime)
                put("createdAt", createdAt)
                put("nextRetryTime", nextRetryTime)
            }
        }
        
        companion object {
            fun fromJson(json: JSONObject): FailedNotification {
                return FailedNotification(
                    id = json.getString("id"),
                    message = json.getString("message"),
                    shopCode = json.getString("shopCode"),
                    timestamp = json.getLong("timestamp"),
                    retryCount = json.getInt("retryCount"),
                    lastRetryTime = json.getLong("lastRetryTime"),
                    createdAt = json.getLong("createdAt"),
                    nextRetryTime = json.optLong("nextRetryTime", System.currentTimeMillis())
                )
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationService created")
        
        // 중복 실행 체크
        if (isServiceRunning()) {
            Log.w(TAG, "Service already running, stopping duplicate instance")
            stopSelf()
            return
        }
        
        // LogManager 초기화
        logManager = LogManager.getInstance(this)
        logManager.logServiceLifecycle("CREATED")
        
        // WakeLock 초기화 - 10분 타임아웃으로 메모리 누수 방지
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, 
                WAKE_LOCK_TAG
            ).apply {
                acquire(10 * 60 * 1000L) // 10분 타임아웃
                Log.d(TAG, "WakeLock acquired with 10 minute timeout")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock", e)
        }
        
        startRetryTimer()
        
        // 서비스 실행 상태 설정
        isRunning = true
        
        // Watchdog Job 스케줄링 - 서비스 안정성 보장
        try {
            NotificationServiceWatchdog.scheduleWatchdog(this)
            Log.d(TAG, "Watchdog scheduled for service monitoring")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule watchdog", e)
        }
        
        // 큐 처리 시작
        startQueueProcessing()
        
        // 앱 재시작 시 기존 큐 복구
        loadQueueFromPreferences()
        
        // 헬스체크 타이머 시작
        startHealthCheckTimer()
        
        // 토큰 갱신 타이머 시작
        startTokenRefreshTimer()
        
        // 서비스 중요도 설정
        try {
            startForegroundService()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
            logManager.logServiceLifecycle("FOREGROUND_START_FAILED", e.message ?: "")
        }
    }
    
    private fun startForegroundService() {
        try {
            // Check notification permission for Android 13+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) 
                    != PackageManager.PERMISSION_GRANTED) {
                    Log.w(TAG, "POST_NOTIFICATIONS permission not granted")
                    // 권한이 없어도 서비스는 계속 실행
                }
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "SnapPay 알림 리스너",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "카카오페이 알림을 모니터링합니다"
                    setShowBadge(false)
                }
                
                val notificationManager = getSystemService(NotificationManager::class.java)
                notificationManager.createNotificationChannel(channel)
            }
            
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this, 
                0, 
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("SnapPay")
                .setContentText("SnapPay 작동 중...")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setSilent(true)
                .build()
            
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground service started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service", e)
        }
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected")
        logManager.logServiceLifecycle("LISTENER_CONNECTED")
        startForegroundService()
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected")
        logManager.logServiceLifecycle("LISTENER_DISCONNECTED")
        
        // 즉시 재연결 시도
        try {
            Log.d(TAG, "Attempting to reconnect NotificationListener...")
            requestRebind(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request rebind", e)
        }
        
        // 백업 재시작 제거 - Watchdog에서 처리하도록 변경
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        
        try {
            Log.d(TAG, "Notification received from: ${sbn.packageName}")
            
            // 모든 알림 수신 시 타임스탬프 업데이트 (헬스체크용)
            val prefs = getSharedPreferences("NotificationHealth", Context.MODE_PRIVATE)
            prefs.edit().putLong("last_any_notification", System.currentTimeMillis()).apply()
        
        // 카카오톡 알림 처리 (로그만 남기고 서버 전송하지 않음)
        if (sbn.packageName == "com.kakao.talk") {
            try {
                val notification = sbn.notification
                val extras = notification.extras
                
                val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
                val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
                val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: text
                
                Log.d(TAG, "📱 KakaoTalk notification - Title: $title, Text: $bigText")
                
                // 카카오톡 알림 상세 정보 추출
                Log.d(TAG, "=== KAKAOTALK NOTIFICATION DETAILS ===")
                Log.d(TAG, "Package: ${sbn.packageName}")
                Log.d(TAG, "Title: $title")
                Log.d(TAG, "Text: $text")
                Log.d(TAG, "BigText: $bigText")
                Log.d(TAG, "PostTime: ${sbn.postTime}")
                Log.d(TAG, "Key: ${sbn.key}")
                
                // 추가 extras 정보 추출
                extras.keySet().forEach { key ->
                    val value = extras.get(key)
                    if (value != null && key != "android.bigText" && key != "android.text" && key != "android.title") {
                        Log.d(TAG, "Extra [$key]: $value")
                    }
                }
                
                // 카카오페이 알림이면 화면 켜기
                if (title == "카카오페이") {
                    Log.d(TAG, "💰 KakaoPay notification detected - Waking up screen")
                    
                    // AccessibilityService에 신호 보내기
                    SnapPayAccessibilityService.setKakaoPayUnlockNeeded(true)
                    
                    // 화면 켜기
                    wakeUpAndUnlock()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing KakaoTalk notification: ${e.message}")
            }
            return
        }
        
        // SharedPreferences에서 개발 모드 확인
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isProduction = flutterPrefs.getBoolean("flutter.is_production", true)
        
        // 개발 모드에서만 테스트 앱 허용
        val isTestPackageAllowed = !isProduction && sbn.packageName == KAKAO_TEST_PACKAGE
        
        // 스냅페이, 카카오페이, 그리고 개발모드의 테스트 앱 알림만 처리
        if (sbn.packageName != SNAPPAY_PACKAGE && 
            sbn.packageName != KAKAO_PAY_PACKAGE && 
            !isTestPackageAllowed) {
            Log.d(TAG, "Not allowed package: ${sbn.packageName}, skipping...")
            return
        }
        
        // 패키지명에 따른 구분 표시
        val packageType = when (sbn.packageName) {
            SNAPPAY_PACKAGE -> "SnapPay"
            KAKAO_PAY_PACKAGE -> "KakaoPay"
            KAKAO_TEST_PACKAGE -> "KakaoTest(DEV)"
            else -> "Unknown"
        }
        
        Log.d(TAG, "Processing notification from: ${sbn.packageName} ($packageType)")
        
        try {
            val notification = sbn.notification
            val extras = notification.extras
            
            val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
            val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
            val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: text
            
            // Skip empty notifications
            if (title.isBlank() && bigText.isBlank()) {
                Log.d(TAG, "Empty notification, skipping...")
                return
            }
            
            // 카카오페이, 스냅페이, 그리고 개발모드의 테스트 앱 알림 로그
            if (sbn.packageName == KAKAO_PAY_PACKAGE || 
                sbn.packageName == SNAPPAY_PACKAGE ||
                (!isProduction && sbn.packageName == KAKAO_TEST_PACKAGE)) {
                
                // 테스트 앱인 경우 패키지명에 (TEST) 추가
                val logPackageName = if (sbn.packageName == KAKAO_TEST_PACKAGE) {
                    "${sbn.packageName} (TEST)"
                } else {
                    sbn.packageName
                }
                
                logManager.logNotificationReceived(
                    title = title,
                    message = bigText,
                    packageName = logPackageName,
                    notificationId = sbn.id,
                    postTime = sbn.postTime
                )
            }
            
            // Skip group summary notifications
            if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
                Log.d(TAG, "Group summary notification, skipping...")
                return
            }
            
            // Create a unique key for deduplication (using notification ID and exact content)
            val notificationKey = "${sbn.id}_${title}_${bigText}"
            if (recentNotifications.contains(notificationKey)) {
                Log.d(TAG, "Duplicate notification detected, skipping...")
                return
            }
            
            recentNotifications.add(notificationKey)
            // Clean old entries if too many - 더 효율적인 방식
            if (recentNotifications.size > MAX_RECENT_NOTIFICATIONS) {
                val toRemove = recentNotifications.size - MAX_RECENT_NOTIFICATIONS
                val iterator = recentNotifications.iterator()
                var removed = 0
                while (iterator.hasNext() && removed < toRemove) {
                    iterator.next()
                    iterator.remove()
                    removed++
                }
            }
            
            Log.d(TAG, "${if (sbn.packageName == SNAPPAY_PACKAGE) "SnapPay" else "KakaoPay"} notification - Title: $title, Text: $bigText")
            
            // 알림 상세 정보 추출 (카카오페이 & 스냅페이)
            val appName = if (sbn.packageName == SNAPPAY_PACKAGE) "SNAPPAY" else "KAKAOPAY"
            Log.d(TAG, "=== $appName NOTIFICATION DETAILS ===")
            Log.d(TAG, "Package: ${sbn.packageName}")
            Log.d(TAG, "ID: ${sbn.id}")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Text: $text")
            Log.d(TAG, "BigText: $bigText")
            Log.d(TAG, "PostTime: ${sbn.postTime}")
            Log.d(TAG, "Key: ${sbn.key}")
            Log.d(TAG, "Tag: ${sbn.tag}")
            Log.d(TAG, "GroupKey: ${sbn.groupKey}")
            
            // 추가 extras 정보 추출
            extras.keySet().forEach { key ->
                val value = extras.get(key)
                if (value != null && key != "android.bigText" && key != "android.text" && key != "android.title") {
                    Log.d(TAG, "Extra [$key]: $value")
                }
            }
            
            // 알림을 큐에 추가 (즉시 전송하지 않음)
            Log.d(TAG, "Adding notification to queue for ${sbn.packageName}")
            addToQueue(title, bigText, sbn.packageName)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
        
        } catch (e: Exception) {
            Log.e(TAG, "Critical error in onNotificationPosted", e)
            logManager.logServiceLifecycle("CRITICAL_ERROR", e.message ?: "Unknown error")
            // 크리티컬 에러 발생 시에도 서비스를 재시작하지 않음
            // Watchdog이 상태를 감지하고 필요시 재시작함
        }
    }
    
    private fun parseKakaoTalkMessage(message: String): Map<String, String>? {
        val result = mutableMapOf<String, String>()
        
        // 금액 파싱
        val amountPattern = Regex("([0-9,]+)원")
        val amountMatch = amountPattern.find(message)
        amountMatch?.let {
            result["amount"] = it.groupValues[1].replace(",", "")
        }
        
        // 계좌번호 파싱
        val accountPattern = Regex("([0-9]{4}-[0-9]{2}-[0-9]{6,})")
        val accountMatch = accountPattern.find(message)
        accountMatch?.let {
            result["account"] = it.value
        }
        
        // 거래 유형 판단
        result["type"] = when {
            message.contains("입금") -> "income"
            message.contains("출금") -> "expense"
            message.contains("이체") -> "transfer"
            message.contains("결제") -> "payment"
            message.contains("취소") -> "cancel"
            else -> "unknown"
        }
        
        // 잔액 파싱
        val balancePattern = Regex("잔액[\\s:]*([0-9,]+)원")
        val balanceMatch = balancePattern.find(message)
        balanceMatch?.let {
            result["balance"] = it.groupValues[1].replace(",", "")
        }
        
        // 거래처 파싱
        when {
            // 카카오페이 앱 형식: "이현우(이*우)님이 10,000원을 보냈어요"
            message.contains("님이") && message.contains("원을 보냈어요") -> {
                val senderPattern = Regex("([가-힣a-zA-Z0-9]+)\\([가-힣a-zA-Z0-9*]+\\)님이")
                senderPattern.find(message)?.let {
                    result["from"] = it.groupValues[1].trim()
                    result["from_masked"] = it.groupValues[2].trim()
                    Log.d(TAG, "Parsed sender: ${result["from"]} (${result["from_masked"]})")
                }
            }
            // 테스트 앱 형식: "김철수(김*수)님이 10,000원을 보냈습니다."
            message.contains("님이") && message.contains("원을 보냈습니다") -> {
                val senderPattern = Regex("([가-힣a-zA-Z0-9]+)\\(([가-힣a-zA-Z0-9*]+)\\)님이")
                senderPattern.find(message)?.let {
                    result["from"] = it.groupValues[1].trim()
                    result["from_masked"] = it.groupValues[2].trim()
                    Log.d(TAG, "Parsed sender (Test App): ${result["from"]} (${result["from_masked"]})")
                }
            }
            // 카카오뱅크/토스 등의 입금 형식: "홍길동님이 50,000원 입금"
            message.contains("님이") && message.contains("입금") -> {
                val senderPattern = Regex("([가-힣a-zA-Z0-9]+)님이")
                senderPattern.find(message)?.let {
                    result["from"] = it.groupValues[1].trim()
                }
            }
            // 카카오페이 형식: "홍길동님으로부터"
            message.contains("님으로부터") -> {
                val senderPattern = Regex("([가-힣a-zA-Z0-9]+)님으로부터")
                senderPattern.find(message)?.let {
                    result["from"] = it.groupValues[1].trim()
                }
            }
            message.contains("에서") -> {
                val fromPattern = Regex("(.+?)에서")
                fromPattern.find(message)?.let {
                    result["from"] = it.groupValues[1].trim()
                }
            }
            message.contains("으로") || message.contains("에게") -> {
                val toPattern = Regex("(.+?)(으로|에게)")
                toPattern.find(message)?.let {
                    result["to"] = it.groupValues[1].trim()
                }
            }
        }
        
        // 은행/서비스 정보 파싱
        val bankPattern = Regex("\\[([가-힣a-zA-Z0-9]+)\\]")
        bankPattern.find(message)?.let {
            result["account"] = it.groupValues[1].trim()
        }
        
        result["rawText"] = message
        
        return if (result.isNotEmpty()) result else null
    }
    
    private fun sendToFlutter(sender: String, message: String, parsedData: Map<String, String>?, packageName: String) {
        scope.launch {
            try {
                val data = JSONObject().apply {
                    put("sender", sender)
                    put("message", message)
                    put("timestamp", System.currentTimeMillis())
                    put("packageName", packageName)
                    
                    parsedData?.let { parsed ->
                        val parsedJson = JSONObject()
                        parsed.forEach { (key, value) ->
                            parsedJson.put(key, value)
                        }
                        put("parsedData", parsedJson)
                    }
                }
                
                // Broadcast to MainActivity (앱이 실행중인 경우)
                val intent = Intent("com.remocall.NOTIFICATION_RECEIVED").apply {
                    putExtra("data", data.toString())
                    setPackage(packageName) // 패키지 명시적 지정
                }
                
                Log.d(TAG, "Sending broadcast with action: com.remocall.NOTIFICATION_RECEIVED")
                Log.d(TAG, "Package: $packageName")
                Log.d(TAG, "Data: ${data.toString()}")
                
                sendBroadcast(intent)
                
                Log.d(TAG, "Broadcast sent successfully")
                
                // 서버로 전송하지 않음 - 큐에서 처리됨
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending to Flutter", e)
            }
        }
    }
    
    // 입금 알림인지 확인하는 함수
    private fun isDepositNotification(message: String): Boolean {
        // 입금 패턴: "이름(마스킹)님이 금액원을 보냈어요" 또는 "이름(마스킹)님이 금액원을 보냈습니다."
        // 더 유연한 패턴: 마침표 유무, 공백 차이 등을 허용
        val depositPattern = Regex(".*\\(.*\\*.*\\)님이\\s*[0-9,]+원을\\s*(보냈어요|보냈습니다).*")
        
        // 제외할 패턴들 (송금, 이체 등)
        val excludePatterns = listOf(
            "송금했어요",
            "이체했어요",
            "계좌로",
            "출금",
            "결제",
            "환불",
            "취소"
        )
        
        // 입금 패턴과 일치하고, 제외 패턴이 없을 때만 true
        val isDeposit = message.matches(depositPattern) && 
                       excludePatterns.none { message.contains(it) }
        
        Log.d(TAG, "Message: $message")
        Log.d(TAG, "Is deposit notification: $isDeposit")
        
        // 파싱 시도
        var parsedAmount: String? = null
        var parsedSender: String? = null
        if (isDeposit) {
            try {
                // 금액 파싱
                val amountMatch = Regex("([0-9,]+)원을").find(message)
                parsedAmount = amountMatch?.groupValues?.get(1)
                
                // 보낸사람 파싱
                val senderMatch = Regex("([가-힣a-zA-Z0-9]+)\\(").find(message)
                parsedSender = senderMatch?.groupValues?.get(1)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing deposit details", e)
            }
        }
        
        // 패턴 필터링 결과 로그
        val reason = when {
            !message.matches(depositPattern) -> "입금 패턴과 불일치"
            excludePatterns.any { message.contains(it) } -> "제외 패턴 포함: ${excludePatterns.first { message.contains(it) }}"
            else -> "입금 알림 확인"
        }
        logManager.logPatternFilter(message, isDeposit, reason)
        
        // 파싱 상세 로그
        logManager.logNotificationParsing(
            originalMessage = message,
            parsedAmount = parsedAmount,
            parsedSender = parsedSender,
            isDeposit = isDeposit,
            parseResult = reason
        )
        
        return isDeposit
    }
    
    // 기존 sendToServer - 큐 시스템으로 대체됨 (호환성을 위해 유지)
    private fun sendToServer(message: String, parsedData: Map<String, String>) {
        // 큐에 추가하도록 변경
        addToQueue("", message, SNAPPAY_PACKAGE)
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        // Handle notification removal if needed
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")
        return START_STICKY
    }
    
    
    // 재시도 타이머 시작 - 중복 생성 방지
    @Synchronized
    private fun startRetryTimer() {
        Log.d(TAG, "Starting retry timer")
        // 기존 타이머가 있으면 취소
        retryTimer?.cancel()
        retryTimer = null
        
        // 새 타이머 생성
        retryTimer = Timer("RetryTimer")
        retryTimer?.scheduleAtFixedRate(60000, 60000) { // 1분 후 시작, 1분마다 실행
            // 큐가 있으면 처리 시작
            val notifications = getFailedNotifications()
            if (notifications.isNotEmpty() && !isProcessingQueue) {
                startQueueProcessing()
            }
            renewWakeLock() // WakeLock 갱신
        }
    }
    
    // 알림을 큐에 추가 (SharedPreferences만 사용)
    private fun addToQueue(sender: String, message: String, packageName: String) {
        try {
            val notification = FailedNotification(
                message = message,
                shopCode = "",
                timestamp = NotificationService.getKSTTimestamp()
            )
            
            // SharedPreferences에 저장
            saveFailedNotification(notification)
            
            val queueSize = getFailedNotifications().size
            Log.d(TAG, "Added notification to queue. Queue size: $queueSize")
            
            // 큐 처리가 중지되어 있다면 다시 시작
            if (!isProcessingQueue) {
                startQueueProcessing()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error adding to queue", e)
        }
    }
    
    // 큐 처리 시작 - 동기화 처리
    @Synchronized
    private fun startQueueProcessing() {
        if (isProcessingQueue) {
            Log.d(TAG, "Queue processing already running")
            return
        }
        
        isProcessingQueue = true
        scope.launch {
            processQueue()
        }
    }
    
    // 큐 처리 메인 로직 (SharedPreferences 기반)
    private suspend fun processQueue() {
        Log.d(TAG, "Starting queue processing")
        
        while (isProcessingQueue) {
            val notifications = getFailedNotifications()
            if (notifications.isEmpty()) {
                Log.d(TAG, "Queue is empty, stopping processing")
                break
            }
            
            val currentTime = System.currentTimeMillis()
            var processedAny = false
            
            logManager.logQueueProcessing("START", notifications.size)
            
            // 모든 알림을 순회하며 처리 가능한 것들 처리
            for (notification in notifications) {
                // 다음 재시도 시간 확인
                if (currentTime < notification.nextRetryTime) {
                    Log.d(TAG, "Notification ${notification.id} not ready for retry. Next retry in ${(notification.nextRetryTime - currentTime) / 1000}s")
                    continue
                }
                
                // 이미 처리 중인지 확인
                if (processingNotifications.contains(notification.id)) {
                    Log.d(TAG, "Notification ${notification.id} is already being processed, skipping...")
                    continue
                }
                
                // 처리 시작 표시
                processingNotifications.add(notification.id)
                processedAny = true
                
                Log.d(TAG, "Processing notification from queue (attempt ${notification.retryCount + 1})")
                logManager.logQueueProcessing("ITEM_START", getFailedNotifications().size, "ID: ${notification.id}, Retry: ${notification.retryCount}")
                
                val startTime = System.currentTimeMillis()
                
                // 전송 시도
                val (success, isDuplicate) = sendNotificationToServer(notification)
                
                val endTime = System.currentTimeMillis()
                logManager.logQueueItemTiming(notification.id, startTime, endTime, success, notification.retryCount)
                
                // 처리 완료 표시
                processingNotifications.remove(notification.id)
                
                if (success || isDuplicate) {
                    // 성공 또는 중복: 큐에서 제거
                    removeFromQueue(notification.id)
                    Log.d(TAG, "Notification ${if (isDuplicate) "already processed (duplicate)" else "sent successfully"} and removed from queue")
                    val remainingSize = getFailedNotifications().size
                    logManager.logQueueProcessing("ITEM_COMPLETE", remainingSize, "ID: ${notification.id}")
                } else {
                    // 실패: 재시도 제한 확인
                    if (notification.retryCount < MAX_QUEUE_ITEM_RETRY) {
                        // 큐에서 제거하고 맨 뒤에 다시 추가
                        removeFromQueue(notification.id)
                        
                        val nextRetryTime = System.currentTimeMillis() + getRetryDelay(notification.retryCount + 1)
                        val updatedNotification = notification.copy(
                            retryCount = notification.retryCount + 1,
                            lastRetryTime = System.currentTimeMillis(),
                            nextRetryTime = nextRetryTime
                        )
                        saveFailedNotification(updatedNotification)
                        
                        Log.d(TAG, "Notification failed, moved to end of queue. Retry ${updatedNotification.retryCount}/$MAX_QUEUE_ITEM_RETRY, next retry at ${nextRetryTime}")
                        val queueSize = getFailedNotifications().size
                        logManager.logQueueProcessing("ITEM_FAILED", queueSize, "ID: ${notification.id}, New retry count: ${updatedNotification.retryCount}")
                    } else {
                        // 최대 재시도 회수 초과 - 큐에서 제거
                        removeFromQueue(notification.id)
                        Log.w(TAG, "Notification ${notification.id} exceeded max retry count. Removed from queue.")
                        val queueSize = getFailedNotifications().size
                        logManager.logQueueProcessing("ITEM_MAX_RETRY", queueSize, "ID: ${notification.id}")
                    }
                }
                
                // 각 아이템 처리 후 짧은 대기
                delay(100)
            }
            
            // 아무것도 처리하지 못했으면 잠시 대기
            if (!processedAny) {
                delay(5000) // 5초 대기
            }
        }
        
        isProcessingQueue = false
        val finalSize = getFailedNotifications().size
        Log.d(TAG, "Queue processing stopped. Queue size: $finalSize")
        logManager.logQueueProcessing("COMPLETE", finalSize)
    }
    
    // 재시도 대기 시간 계산
    private fun getRetryDelay(retryCount: Int): Long {
        return when (retryCount) {
            0 -> 0L
            1 -> 5000L  // 5초
            2 -> 10000L // 10초
            else -> 30000L // 30초
        }
    }
    
    // 실제 서버 전송 로직
    private suspend fun sendNotificationToServer(notification: FailedNotification): Pair<Boolean, Boolean> {
        return try {
            // sendToServer 메서드 호출
            val result = withContext(Dispatchers.IO) {
                sendNotificationDirect(notification.message)
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Error sending notification to server", e)
            Pair(false, false)
        }
    }
    
    // 직접 서버로 전송 (동기식)
    private fun sendNotificationDirect(message: String): Pair<Boolean, Boolean> {
        try {
            // 입금 알림인지 확인
            if (!isDepositNotification(message)) {
                Log.d(TAG, "Not a deposit notification, removing from queue")
                return Pair(true, false) // 입금 알림이 아니면 성공으로 처리하여 큐에서 제거
            }
            
            // SharedPreferences에서 액세스 토큰 가져오기
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val accessToken = prefs.getString("flutter.access_token", null)
            
            if (accessToken == null) {
                Log.e(TAG, "No access token available")
                return Pair(false, false)
            }
            
            // 서버로 전송
            val isProduction = prefs.getBoolean("flutter.is_production", true)
            val apiUrl = if (isProduction) {
                "https://admin-api.snappay.online/api/kakao-deposits/webhook"
            } else {
                "https://kakaopay-admin-api.flexteam.kr/api/kakao-deposits/webhook"
            }
            
            val url = URL(apiUrl)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $accessToken")
                doOutput = true
                connectTimeout = 30000
                readTimeout = 30000
            }
            
            val jsonData = JSONObject().apply {
                put("message", message)
                put("timestamp", NotificationService.getKSTTimestamp())
            }
            
            connection.outputStream.use { os ->
                os.write(jsonData.toString().toByteArray())
            }
            
            val responseCode = connection.responseCode
            val responseMessage = try {
                if (responseCode in 200..299) {
                    connection.inputStream.bufferedReader().use { it.readText() }
                } else {
                    connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                }
            } catch (e: Exception) {
                ""
            }
            
            // 응답 로그
            Log.d(TAG, "Server response code: $responseCode, message: $responseMessage")
            
            // 중복 입금 체크
            val isDuplicate = responseMessage.contains("이미 처리된 입금입니다")
            if (isDuplicate) {
                Log.d(TAG, "Server says notification is duplicate, will remove from queue")
            }
            
            val success = responseCode in 200..299
            
            if (!success && !isDuplicate) {
                Log.e(TAG, "Server returned error code: $responseCode")
            }
            
            return Pair(success, isDuplicate)
        } catch (e: Exception) {
            Log.e(TAG, "Error in sendNotificationDirect", e)
            return Pair(false, false)
        }
    }
    
    // 앱 재시작 시 큐 처리 시작 (이미 SharedPreferences에 저장되어 있음)
    private fun loadQueueFromPreferences() {
        try {
            val notifications = getFailedNotifications()
            if (notifications.isNotEmpty()) {
                Log.d(TAG, "Found ${notifications.size} notifications in storage")
                
                // 큐 처리가 중지되어 있다면 다시 시작
                if (!isProcessingQueue) {
                    startQueueProcessing()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading queue from preferences", e)
        }
    }
    
    @Synchronized
    private fun renewWakeLock() {
        try {
            wakeLock?.let { lock ->
                if (!lock.isHeld) {
                    // WakeLock이 해제되어 있다면 다시 획득
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = powerManager.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK, 
                        WAKE_LOCK_TAG
                    ).apply {
                        acquire(10 * 60 * 1000L) // 10분 타임아웃
                        Log.d(TAG, "WakeLock re-acquired with 10 minute timeout")
                    }
                } else {
                    Log.d(TAG, "WakeLock still held - no action needed")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check/renew WakeLock", e)
        }
    }
    
    // 실패한 알림을 큐에 저장 - 동기화 처리
    @Synchronized
    private fun saveFailedNotification(notification: FailedNotification) {
        try {
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val existingQueue = prefs.getString("failed_notifications", "[]") ?: "[]"
            
            val queueArray = JSONArray(existingQueue)
            queueArray.put(notification.toJson())
            
            // 큐 크기 제한 (1000개)
            if (queueArray.length() > 1000) {
                Log.w(TAG, "Queue size exceeds 1000, removing oldest items")
                val newArray = JSONArray()
                for (i in queueArray.length() - 1000 until queueArray.length()) {
                    newArray.put(queueArray.getJSONObject(i))
                }
                prefs.edit()
                    .putString("failed_notifications", newArray.toString())
                    .apply()
            } else {
                prefs.edit()
                    .putString("failed_notifications", queueArray.toString())
                    .apply()
            }
                
            Log.d(TAG, "Saved failed notification to queue. Queue size: ${queueArray.length()}")
            
            // 실패 큐 추가 로그
            logManager.logFailedQueue(
                action = "ADD",
                notificationId = notification.id,
                message = notification.message,
                retryCount = notification.retryCount,
                queueSize = queueArray.length()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error saving failed notification", e)
        }
    }
    
    // 큐에서 실패한 알림들 가져오기 - 동기화 처리
    @Synchronized
    private fun getFailedNotifications(): List<FailedNotification> {
        return try {
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val queueJson = prefs.getString("failed_notifications", "[]") ?: "[]"
            val queueArray = JSONArray(queueJson)
            
            val notifications = mutableListOf<FailedNotification>()
            for (i in 0 until queueArray.length()) {
                val notificationJson = queueArray.getJSONObject(i)
                notifications.add(FailedNotification.fromJson(notificationJson))
            }
            notifications
        } catch (e: Exception) {
            Log.e(TAG, "Error getting failed notifications", e)
            emptyList()
        }
    }
    
    // 큐에서 특정 알림 제거 - 동기화 처리
    @Synchronized
    private fun removeFromQueue(notificationId: String) {
        try {
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val existingQueue = prefs.getString("failed_notifications", "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            
            val newArray = JSONArray()
            for (i in 0 until queueArray.length()) {
                val notification = queueArray.getJSONObject(i)
                if (notification.getString("id") != notificationId) {
                    newArray.put(notification)
                }
            }
            
            prefs.edit()
                .putString("failed_notifications", newArray.toString())
                .apply()
                
            Log.d(TAG, "Removed notification from queue. New queue size: ${newArray.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing from queue", e)
        }
    }
    
    // 재시도 가능 여부 확인 - 최대 20회까지만 재시도
    private fun shouldRetry(notification: FailedNotification): Boolean {
        if (notification.retryCount >= MAX_QUEUE_ITEM_RETRY) {
            Log.w(TAG, "Notification ${notification.id} reached max retry limit ($MAX_QUEUE_ITEM_RETRY)")
            return false
        }
        Log.d(TAG, "Notification ${notification.id} will be retried (attempt ${notification.retryCount + 1}/$MAX_QUEUE_ITEM_RETRY)")
        return true
    }
    
    // 큐에서 알림 업데이트 - 동기화 처리
    @Synchronized
    private fun updateNotificationInQueue(notification: FailedNotification) {
        try {
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val existingQueue = prefs.getString("failed_notifications", "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            
            val newArray = JSONArray()
            var updated = false
            
            for (i in 0 until queueArray.length()) {
                val item = queueArray.getJSONObject(i)
                if (item.getString("id") == notification.id) {
                    newArray.put(notification.toJson())
                    updated = true
                } else {
                    newArray.put(item)
                }
            }
            
            // 만약 업데이트할 항목이 없으면 추가
            if (!updated) {
                newArray.put(notification.toJson())
            }
            
            prefs.edit()
                .putString("failed_notifications", newArray.toString())
                .apply()
                
            Log.d(TAG, "Updated notification ${notification.id} in queue")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating notification in queue", e)
        }
    }
    
    // 입금 알림이 아닌 항목들을 큐에서 제거 - 동기화 처리
    @Synchronized
    fun cleanFailedQueue() {
        try {
            Log.d(TAG, "=== CLEANING FAILED QUEUE ===")
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val existingQueue = prefs.getString("failed_notifications", "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            
            val cleanedArray = JSONArray()
            var removedCount = 0
            
            for (i in 0 until queueArray.length()) {
                val notification = queueArray.getJSONObject(i)
                val message = notification.getString("message")
                
                // 입금 알림인지 확인
                if (isDepositNotification(message)) {
                    cleanedArray.put(notification)
                    Log.d(TAG, "Keeping deposit notification: $message")
                } else {
                    removedCount++
                    Log.d(TAG, "Removing non-deposit notification: $message")
                }
            }
            
            // 정리된 큐 저장
            prefs.edit()
                .putString("failed_notifications", cleanedArray.toString())
                .apply()
                
            Log.d(TAG, "Queue cleaned. Removed $removedCount non-deposit notifications. Remaining: ${cleanedArray.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning failed queue", e)
        }
    }
    
    // AccessibilityService 활성화 확인
    private fun isAccessibilityServiceEnabled(): Boolean {
        try {
            val serviceName = "${packageName}/${SnapPayAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            
            return enabledServices?.contains(serviceName) == true
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accessibility service", e)
            return false
        }
    }
    
    // 화면 켜기 및 잠금 해제 함수
    private fun wakeUpAndUnlock() {
        try {
            Log.d(TAG, "Attempting to wake up and unlock screen...")
            
            // PowerManager를 통해 화면 켜기
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isInteractive) {
                @Suppress("DEPRECATION")
                wakeLock = powerManager.newWakeLock(
                    PowerManager.FULL_WAKE_LOCK or 
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                    PowerManager.ON_AFTER_RELEASE,
                    "$TAG:WakeLock"
                )
                wakeLock?.acquire(10 * 1000L) // 10초 동안 유지
                Log.d(TAG, "Screen wake lock acquired")
            }
            
            // AccessibilityService가 활성화되어 있는지 확인
            val isAccessibilityEnabled = isAccessibilityServiceEnabled()
            Log.d(TAG, "AccessibilityService enabled: $isAccessibilityEnabled")
            
            if (isAccessibilityEnabled) {
                // AccessibilityService가 잠금화면을 해제하도록 기다림
                Log.d(TAG, "Waiting for AccessibilityService to unlock screen...")
                Thread.sleep(1000) // 1초 대기
            } else {
                // AccessibilityService가 비활성화된 경우 기존 방식 사용
                Log.d(TAG, "AccessibilityService not enabled, using MainActivity approach")
                
                val intent = Intent(applicationContext, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    
                    // 잠금화면 해제를 위한 추가 플래그
                    addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                    addFlags(Intent.FLAG_FROM_BACKGROUND)
                    
                    // 카카오페이 알림 플래그 추가
                    putExtra("isKakaoPayNotification", true)
                }
                
                startActivity(intent)
                Log.d(TAG, "MainActivity launched to unlock screen")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error waking up and unlocking screen: ${e.message}", e)
        }
    }
    
    // 헬스체크 타이머 시작 - 중복 생성 방지
    @Synchronized
    private fun startHealthCheckTimer() {
        Log.d(TAG, "Starting health check timer")
        // 기존 타이머가 있으면 취소
        healthCheckTimer?.cancel()
        healthCheckTimer = null
        
        // 새 타이머 생성
        healthCheckTimer = Timer("HealthCheckTimer")
        healthCheckTimer?.scheduleAtFixedRate(60000, 60000) { // 1분마다 실행
            performHealthCheck()
        }
    }
    
    // 토큰 갱신 타이머 시작 - 매시간 갱신
    @Synchronized
    private fun startTokenRefreshTimer() {
        Log.d(TAG, "Starting token refresh timer")
        // 기존 타이머가 있으면 취소
        tokenRefreshTimer?.cancel()
        tokenRefreshTimer = null
        
        // 새 타이머 생성
        tokenRefreshTimer = Timer("TokenRefreshTimer")
        tokenRefreshTimer?.scheduleAtFixedRate(3600000, 3600000) { // 1시간마다 실행
            performTokenRefresh()
        }
    }
    
    // 토큰 갱신 수행
    private fun performTokenRefresh() {
        scope.launch {
            try {
                // 이미 갱신 중이면 스킵
                if (isRefreshingToken) {
                    Log.d(TAG, "Token refresh already in progress, skipping...")
                    return@launch
                }
                
                isRefreshingToken = true
                Log.d(TAG, "Starting hourly token refresh at ${Date()}")
                
                // 큐 처리 일시 중지
                val wasProcessingQueue = isProcessingQueue
                if (wasProcessingQueue) {
                    Log.d(TAG, "Pausing queue processing for token refresh")
                    isProcessingQueue = false
                    delay(500) // 진행 중인 작업이 완료될 시간 부여
                }
                
                // 로그에 큐 처리 중지 기록
                logManager.logQueueProcessing("PAUSE_FOR_TOKEN_REFRESH", getFailedNotifications().size)
                
                // 토큰 갱신 시도
                val context = applicationContext
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val refreshToken = prefs.getString("flutter.refresh_token", null)
                
                if (refreshToken == null) {
                    Log.e(TAG, "No refresh token available for hourly refresh")
                    logManager.logTokenRefresh(false, "No refresh token")
                    isRefreshingToken = false
                    
                    // 큐 처리 재개
                    if (wasProcessingQueue) {
                        Log.d(TAG, "Resuming queue processing after failed token refresh")
                        logManager.logQueueProcessing("RESUME_AFTER_TOKEN_REFRESH", getFailedNotifications().size)
                        startQueueProcessing()
                    }
                    return@launch
                }
                
                val success = NotificationService.refreshAccessToken(context, refreshToken)
                
                if (success) {
                    Log.d(TAG, "✅ Hourly token refresh successful at ${Date()}")
                    logManager.logTokenRefresh(true, "Hourly refresh")
                    
                    // 갱신 성공 시간 저장
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putLong("last_token_refresh", System.currentTimeMillis())
                        .apply()
                } else {
                    Log.e(TAG, "❌ Hourly token refresh failed at ${Date()}")
                    logManager.logTokenRefresh(false, "Hourly refresh failed")
                    
                    // 5분 후 재시도
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            performTokenRefresh()
                        }
                    }, 300000) // 5분
                }
                
                // 큐 처리 재개
                if (wasProcessingQueue) {
                    Log.d(TAG, "Resuming queue processing after token refresh")
                    logManager.logQueueProcessing("RESUME_AFTER_TOKEN_REFRESH", getFailedNotifications().size)
                    startQueueProcessing()
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error in performTokenRefresh", e)
                logManager.logError("performTokenRefresh", e)
            } finally {
                isRefreshingToken = false
            }
        }
    }
    
    // 헬스체크 수행
    private fun performHealthCheck() {
        try {
            val prefs = getSharedPreferences("NotificationHealth", Context.MODE_PRIVATE)
            val lastNotificationTime = prefs.getLong("last_any_notification", 0)
            val timeSinceLastNotification = System.currentTimeMillis() - lastNotificationTime
            
            // 알림 권한 확인
            val hasPermission = isNotificationListenerEnabled()
            
            // 서비스 상태 확인
            val isServiceRunning = true // 이 메소드가 실행되고 있다면 서비스는 실행 중
            
            val queueSize = getFailedNotifications().size
            
            // 헬스체크 로그
            logManager.logHealthCheck(
                lastNotificationTime = lastNotificationTime,
                isServiceRunning = isServiceRunning,
                hasNotificationPermission = hasPermission,
                queueSize = queueSize
            )
            
            Log.d(TAG, "Health check - Last notification: ${timeSinceLastNotification}ms ago, Permission: $hasPermission, Queue: $queueSize")
            
            // 권한이 없어졌다면 재연결 시도
            if (!hasPermission) {
                Log.e(TAG, "Notification permission lost! Attempting to rebind...")
                requestRebind(null)
            }
            
            // 자가 진단 결과 저장 (MainActivity에서 읽을 수 있도록)
            prefs.edit()
                .putLong("last_health_check", System.currentTimeMillis())
                .putBoolean("is_healthy", hasPermission && timeSinceLastNotification < 300000) // 5분 이내
                .putInt("queue_size", queueSize)
                .apply()
                
        } catch (e: Exception) {
            Log.e(TAG, "Error in health check", e)
            logManager.logError("performHealthCheck", e)
        }
    }
    
    // 알림 리스너 권한 확인
    private fun isNotificationListenerEnabled(): Boolean {
        try {
            val enabledListeners = Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners"
            )
            val packageName = packageName
            return enabledListeners?.contains(packageName) == true
        } catch (e: Exception) {
            Log.e(TAG, "Error checking notification listener permission", e)
            return false
        }
    }
    
    // 서비스 중복 실행 확인
    private fun isServiceRunning(): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (NotificationService::class.java.name == service.service.className && 
                service.pid != android.os.Process.myPid()) {
                return true
            }
        }
        return false
    }
    
    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        logManager.logServiceLifecycle("DESTROYED")
        
        retryTimer?.cancel()
        healthCheckTimer?.cancel()
        tokenRefreshTimer?.cancel()
        scope.cancel()
        // Wake lock 해제
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        Log.d(TAG, "NotificationService destroyed")
        
        // 자동 재시작 제거 - Watchdog에서 관리하도록 변경
        // 서비스가 정상적으로 종료되면 자동으로 재시작하지 않음
    }
}