package com.remocall.remocall_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
import kotlin.concurrent.scheduleAtFixedRate

class NotificationService : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationService"
        private const val CHANNEL = "com.remocall/notifications"
        private const val KAKAO_TALK_PACKAGE = "com.kakao.talk"
        private const val KAKAO_PAY_PACKAGE = "com.kakaopay.app"
        private const val NOTIFICATION_CHANNEL_ID = "depositpro_notification_listener"
        private const val NOTIFICATION_ID = 1001
    }
    
    private var methodChannel: MethodChannel? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val recentNotifications = mutableSetOf<String>()
    private var retryTimer: Timer? = null
    
    // 실패한 알림 데이터 클래스
    data class FailedNotification(
        val id: String = UUID.randomUUID().toString(),
        val message: String,
        val shopCode: String,
        val timestamp: Long,
        val retryCount: Int = 0,
        val lastRetryTime: Long = 0,
        val createdAt: Long = System.currentTimeMillis()
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
                    createdAt = json.getLong("createdAt")
                )
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationService created")
        startRetryTimer()
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
        startForegroundService()
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected")
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        
        Log.d(TAG, "Notification received from: ${sbn.packageName}")
        
        // 카카오페이 알림만 처리
        if (sbn.packageName != KAKAO_PAY_PACKAGE) {
            Log.d(TAG, "Not KakaoPay, skipping...")
            return
        }
        
        Log.d(TAG, "Processing KakaoPay notification")
        
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
            // Clean old entries if too many
            if (recentNotifications.size > 100) {
                val iterator = recentNotifications.iterator()
                repeat(50) {
                    if (iterator.hasNext()) {
                        iterator.next()
                        iterator.remove()
                    }
                }
            }
            
            Log.d(TAG, "KakaoPay notification - Title: $title, Text: $bigText")
            
            // 파싱 로직 (입금 관련 메시지인 경우에만)
            val parsedData = if (bigText.contains("입금") || bigText.contains("원") || bigText.contains("잔액")) {
                parseKakaoTalkMessage(bigText)
            } else {
                // 일반 메시지는 파싱하지 않음
                null
            }
            
            // 모든 카카오페이 메시지를 Flutter로 전송
            sendToFlutter(title, bigText, parsedData, sbn.packageName)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
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
                
                // 모든 카카오톡 메시지를 서버로 전송 (파싱 실패해도 전송)
                Log.d(TAG, "Attempting to send message to server...")
                sendToServer(message, parsedData ?: emptyMap())
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending to Flutter", e)
            }
        }
    }
    
    private fun sendToServer(message: String, parsedData: Map<String, String>) {
        scope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "=== SEND TO SERVER START (NotificationService) ===")
                
                // SharedPreferences에서 액세스 토큰과 shop_code 가져오기
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val accessToken = prefs.getString("flutter.access_token", null)
                val shopCode = prefs.getString("flutter.shop_code", null)
                
                Log.d(TAG, "Access token exists: ${accessToken != null}")
                Log.d(TAG, "Shop code: $shopCode")
                
                if (accessToken == null) {
                    Log.w(TAG, "No access token found, sending without authentication")
                    // 액세스 토큰이 없어도 API Key로 전송 시도
                }
                
                if (shopCode == null) {
                    Log.w(TAG, "No shop code found, cannot send notification")
                    return@launch
                }
                
                // API 호출을 위한 데이터 준비
                val notificationData = JSONObject().apply {
                    put("message", message)
                    put("shop_code", shopCode)
                }
                
                Log.d(TAG, "Sending data: $notificationData")
                
                // HTTP 요청 직접 수행
                val url = java.net.URL("https://admin-api.snappay.online/api/kakao-deposits/webhook")
                val connection = url.openConnection() as java.net.HttpURLConnection
                
                try {
                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("X-API-Key", "KkP_Wh_9Qm7@L8xN3vR5tY1uE4wS6aD2fG7hJ9kM8nB5cX1zV4qP0oI3uY6tR9eW2sA7dF")
                    if (accessToken != null) {
                        connection.setRequestProperty("Authorization", "Bearer $accessToken")
                        Log.d(TAG, "Authorization header added")
                    }
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
                    } else {
                        val errorStream = connection.errorStream
                        val response = if (errorStream != null) {
                            errorStream.bufferedReader().use { it.readText() }
                        } else {
                            "No error response"
                        }
                        Log.e(TAG, "❌ Server error ($responseCode): $response")
                        
                        // 실패 시 큐에 추가
                        val failedNotification = FailedNotification(
                            message = message,
                            shopCode = shopCode,
                            timestamp = System.currentTimeMillis()
                        )
                        saveFailedNotification(failedNotification)
                        Log.w(TAG, "Added to retry queue due to server error: $responseCode")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Connection error: ${e.message}", e)
                    
                    // 네트워크 오류 등으로 실패 시 큐에 추가
                    val failedNotification = FailedNotification(
                        message = message,
                        shopCode = shopCode,
                        timestamp = System.currentTimeMillis()
                    )
                    saveFailedNotification(failedNotification)
                    Log.w(TAG, "Added to retry queue due to exception: ${e.message}")
                } finally {
                    connection.disconnect()
                }
                
                Log.d(TAG, "=== SEND TO SERVER END ===")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending to server: ${e.message}", e)
                e.printStackTrace()
            }
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        // Handle notification removal if needed
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        retryTimer?.cancel()
        scope.cancel()
        Log.d(TAG, "NotificationService destroyed")
        
        // 서비스가 종료되면 다시 시작하도록 알람 설정
        val restartIntent = Intent(applicationContext, NotificationService::class.java)
        val restartPendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.set(
            android.app.AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 1000,
            restartPendingIntent
        )
    }
    
    // 재시도 타이머 시작
    private fun startRetryTimer() {
        Log.d(TAG, "Starting retry timer")
        retryTimer = Timer()
        retryTimer?.scheduleAtFixedRate(60000, 60000) { // 1분 후 시작, 1분마다 실행
            processFailedQueue()
        }
    }
    
    // 실패한 알림을 큐에 저장
    private fun saveFailedNotification(notification: FailedNotification) {
        try {
            val prefs = getSharedPreferences("NotificationQueue", Context.MODE_PRIVATE)
            val existingQueue = prefs.getString("failed_notifications", "[]") ?: "[]"
            
            val queueArray = JSONArray(existingQueue)
            queueArray.put(notification.toJson())
            
            prefs.edit()
                .putString("failed_notifications", queueArray.toString())
                .apply()
                
            Log.d(TAG, "Saved failed notification to queue. Queue size: ${queueArray.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving failed notification", e)
        }
    }
    
    // 큐에서 실패한 알림들 가져오기
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
    
    // 큐에서 특정 알림 제거
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
    
    // 재시도 가능 여부 확인
    private fun shouldRetry(notification: FailedNotification): Boolean {
        val maxRetries = 5
        val maxAge = 24 * 60 * 60 * 1000L // 24시간
        
        // 최대 재시도 횟수 초과
        if (notification.retryCount >= maxRetries) {
            Log.w(TAG, "Max retries exceeded for notification ${notification.id}")
            removeFromQueue(notification.id)
            return false
        }
        
        // 24시간 경과
        if (System.currentTimeMillis() - notification.createdAt > maxAge) {
            Log.w(TAG, "Notification ${notification.id} expired (24h)")
            removeFromQueue(notification.id)
            return false
        }
        
        // 백오프 전략 제거 - 항상 재시도 가능
        return true
    }
    
    // 실패한 큐 처리
    private fun processFailedQueue() {
        scope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "Processing failed notification queue")
                val failedNotifications = getFailedNotifications()
                
                if (failedNotifications.isEmpty()) {
                    return@launch
                }
                
                Log.d(TAG, "Found ${failedNotifications.size} failed notifications")
                
                failedNotifications.forEach { notification ->
                    if (shouldRetry(notification)) {
                        retryNotification(notification)
                        // 각 알림 사이에 1초 지연
                        delay(1000)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing failed queue", e)
            }
        }
    }
    
    // 알림 재전송
    private fun retryNotification(notification: FailedNotification) {
        Log.d(TAG, "Retrying notification ${notification.id} (attempt ${notification.retryCount + 1})")
        
        try {
            // SharedPreferences에서 액세스 토큰 가져오기
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val accessToken = prefs.getString("flutter.access_token", null)
            
            val notificationData = JSONObject().apply {
                put("message", notification.message)
                put("shop_code", notification.shopCode)
            }
            
            val url = URL("https://admin-api.snappay.online/api/kakao-deposits/webhook")
            val connection = url.openConnection() as HttpURLConnection
            
            try {
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("X-API-Key", "KkP_Wh_9Qm7@L8xN3vR5tY1uE4wS6aD2fG7hJ9kM8nB5cX1zV4qP0oI3uY6tR9eW2sA7dF")
                if (accessToken != null) {
                    connection.setRequestProperty("Authorization", "Bearer $accessToken")
                }
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                connection.doOutput = true
                connection.doInput = true
                connection.useCaches = false
                
                connection.outputStream.use { os ->
                    val input = notificationData.toString().toByteArray(charset("utf-8"))
                    os.write(input, 0, input.size)
                }
                
                val responseCode = connection.responseCode
                
                if (responseCode == 200 || responseCode == 201) {
                    Log.d(TAG, "✅ Retry successful for notification ${notification.id}")
                    removeFromQueue(notification.id)
                } else {
                    Log.e(TAG, "❌ Retry failed with code $responseCode")
                    // 재시도 카운트 증가하여 다시 저장
                    val updatedNotification = notification.copy(
                        retryCount = notification.retryCount + 1,
                        lastRetryTime = System.currentTimeMillis()
                    )
                    updateNotificationInQueue(updatedNotification)
                }
            } finally {
                connection.disconnect()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Retry error: ${e.message}", e)
            // 재시도 카운트 증가하여 다시 저장
            val updatedNotification = notification.copy(
                retryCount = notification.retryCount + 1,
                lastRetryTime = System.currentTimeMillis()
            )
            updateNotificationInQueue(updatedNotification)
        }
    }
    
    // 큐에서 알림 업데이트
    private fun updateNotificationInQueue(notification: FailedNotification) {
        removeFromQueue(notification.id)
        saveFailedNotification(notification)
    }
}