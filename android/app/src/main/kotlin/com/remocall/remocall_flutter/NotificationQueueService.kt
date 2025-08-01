package com.remocall.remocall_flutter

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 알림 큐 관리 서비스
 * - 알림 큐 저장 및 관리
 * - WorkManager를 통한 큐 처리
 * - 재시도 로직 관리
 */
class NotificationQueueService(private val context: Context) {
    
    companion object {
        private const val TAG = "NotificationQueueService"
        private const val PREFS_NAME = "NotificationQueue"
        private const val QUEUE_KEY = "failed_notifications"
        private const val MAX_QUEUE_SIZE = 1000
        
        @Volatile
        private var instance: NotificationQueueService? = null
        
        fun getInstance(context: Context): NotificationQueueService {
            return instance ?: synchronized(this) {
                instance ?: NotificationQueueService(context.applicationContext).also { instance = it }
            }
        }
    }
    
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val logManager = LogManager.getInstance(context)
    private val tokenManager = TokenManager.getInstance(context)
    private val apiService = ApiService.getInstance(context)
    
    private var queueProcessorTimer: Timer? = null
    private val isProcessing = AtomicBoolean(false)
    
    /**
     * 알림을 큐에 추가
     * @return notification ID 또는 null (실패시)
     */
    fun enqueue(message: String): String? {
        try {
            // 입금 알림인지 확인
            if (!isDepositNotification(message)) {
                Log.d(TAG, "Not a deposit notification, not adding to queue")
                return null
            }
            
            val notification = QueuedNotification(
                id = UUID.randomUUID().toString(),
                message = message,
                timestamp = System.currentTimeMillis(),
                retryCount = 0,
                lastRetryTime = 0,
                createdAt = System.currentTimeMillis()
            )
            
            // 큐에 저장
            saveNotification(notification)
            
            val queueSize = getQueueSize()
            Log.d(TAG, "Added notification to queue. Queue size: $queueSize")
            
            // 로그 제거 - 불필요
            
            return notification.id
        } catch (e: Exception) {
            Log.e(TAG, "Error adding to queue", e)
            logManager.logError("enqueue", e, "Message: $message")
            return null
        }
    }
    
    /**
     * 독립적인 큐 프로세서 시작
     */
    fun startQueueProcessor() {
        synchronized(this) {
            if (queueProcessorTimer != null) {
                Log.d(TAG, "Queue processor already running")
                return
            }
            
            queueProcessorTimer = Timer("QueueProcessorTimer", true)
            queueProcessorTimer?.scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    checkAndProcessQueue()
                }
            }, 0, 1000)  // 즉시 시작, 1초마다 확인
            
            Log.d(TAG, "Queue processor started")
        }
    }
    
    /**
     * 큐 프로세서 중지
     */
    fun stopQueueProcessor() {
        synchronized(this) {
            queueProcessorTimer?.cancel()
            queueProcessorTimer = null
            Log.d(TAG, "Queue processor stopped")
        }
    }
    
    /**
     * 큐 확인 및 처리
     */
    private fun checkAndProcessQueue() {
        if (isProcessing.get()) {
            return  // 이미 처리 중이면 스킵
        }
        
        val queueSize = getQueueSize()
        if (queueSize == 0) {
            return  // 큐가 비어있으면 스킵
        }
        
        // 처리 시작
        if (isProcessing.compareAndSet(false, true)) {
            try {
                Log.d(TAG, "Processing queue with $queueSize items")
                processAllQueueItems()
            } finally {
                isProcessing.set(false)
            }
        }
    }
    
    /**
     * 알림 저장
     */
    private fun saveNotification(notification: QueuedNotification) {
        synchronized(this) {
            val existingQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            
            queueArray.put(notification.toJson())
            
            // 큐 크기 제한
            if (queueArray.length() > MAX_QUEUE_SIZE) {
                Log.w(TAG, "Queue size exceeds $MAX_QUEUE_SIZE, removing oldest items")
                val newArray = JSONArray()
                for (i in queueArray.length() - MAX_QUEUE_SIZE until queueArray.length()) {
                    newArray.put(queueArray.getJSONObject(i))
                }
                prefs.edit().putString(QUEUE_KEY, newArray.toString()).apply()
            } else {
                prefs.edit().putString(QUEUE_KEY, queueArray.toString()).apply()
            }
        }
    }
    
    /**
     * 큐에서 알림 제거
     */
    fun removeFromQueue(notificationId: String) {
        synchronized(this) {
            val existingQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            val newArray = JSONArray()
            
            for (i in 0 until queueArray.length()) {
                val notification = queueArray.getJSONObject(i)
                if (notification.getString("id") != notificationId) {
                    newArray.put(notification)
                }
            }
            
            prefs.edit().putString(QUEUE_KEY, newArray.toString()).apply()
            Log.d(TAG, "Removed notification from queue. New size: ${newArray.length()}")
        }
    }
    
    /**
     * 큐의 모든 알림 가져오기
     */
    fun getAllNotifications(): List<QueuedNotification> {
        return try {
            val queueJson = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val queueArray = JSONArray(queueJson)
            val notifications = mutableListOf<QueuedNotification>()
            
            for (i in 0 until queueArray.length()) {
                val notificationJson = queueArray.getJSONObject(i)
                notifications.add(QueuedNotification.fromJson(notificationJson))
            }
            
            notifications
        } catch (e: Exception) {
            Log.e(TAG, "Error getting notifications", e)
            emptyList()
        }
    }
    
    /**
     * 큐 크기 가져오기
     */
    fun getQueueSize(): Int {
        return try {
            val queueJson = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            JSONArray(queueJson).length()
        } catch (e: Exception) {
            0
        }
    }
    
    /**
     * 알림 업데이트
     */
    fun updateNotification(notification: QueuedNotification) {
        synchronized(this) {
            val existingQueue = prefs.getString(QUEUE_KEY, "[]") ?: "[]"
            val queueArray = JSONArray(existingQueue)
            val newArray = JSONArray()
            
            for (i in 0 until queueArray.length()) {
                val item = queueArray.getJSONObject(i)
                if (item.getString("id") == notification.id) {
                    newArray.put(notification.toJson())
                } else {
                    newArray.put(item)
                }
            }
            
            prefs.edit().putString(QUEUE_KEY, newArray.toString()).apply()
        }
    }
    
    /**
     * 입금 알림 패턴 확인
     */
    private fun isDepositNotification(message: String): Boolean {
        val depositPattern = Regex(".*\\(.*\\*.*\\)님이\\s*[0-9,]+원을\\s*(보냈어요|보냈습니다).*")
        val excludePatterns = listOf(
            "송금했어요", "이체했어요", "계좌로", "출금", "결제", "환불", "취소"
        )
        
        val matchesPattern = message.matches(depositPattern)
        val containsExcludePattern = excludePatterns.any { message.contains(it) }
        
        return matchesPattern && !containsExcludePattern
    }
    
    /**
     * 모든 큐 항목 처리
     */
    private fun processAllQueueItems() {
        val notifications = getAllNotifications()
        if (notifications.isEmpty()) {
            return
        }
        
        // 로그 제거 - 불필요
        
        for (notification in notifications) {
            try {
                // API 호출
                val (success, isDuplicate) = apiService.sendNotification(notification.message)
                
                if (success || isDuplicate) {
                    // 성공 또는 중복: 큐에서 제거
                    removeFromQueue(notification.id)
                    Log.d(TAG, "Queue item processed successfully: ${notification.id}")
                } else {
                    // 실패: 큐에 남겨둠 (다음 주기에 재시도)
                    val updated = notification.copy(
                        retryCount = notification.retryCount + 1,
                        lastRetryTime = System.currentTimeMillis()
                    )
                    updateNotification(updated)
                    Log.w(TAG, "Queue item failed, will retry: ${notification.id}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing notification ${notification.id}", e)
                logManager.logError("processAllQueueItems", e, "ID: ${notification.id}")
            }
        }
    }
}

/**
 * 큐에 저장되는 알림 데이터
 */
data class QueuedNotification(
    val id: String,
    val message: String,
    val timestamp: Long,
    val retryCount: Int,
    val lastRetryTime: Long,
    val createdAt: Long
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("message", message)
            put("timestamp", timestamp)
            put("retryCount", retryCount)
            put("lastRetryTime", lastRetryTime)
            put("createdAt", createdAt)
        }
    }
    
    companion object {
        fun fromJson(json: JSONObject): QueuedNotification {
            return QueuedNotification(
                id = json.getString("id"),
                message = json.getString("message"),
                timestamp = json.getLong("timestamp"),
                retryCount = json.getInt("retryCount"),
                lastRetryTime = json.getLong("lastRetryTime"),
                createdAt = json.getLong("createdAt")
            )
        }
    }
}

