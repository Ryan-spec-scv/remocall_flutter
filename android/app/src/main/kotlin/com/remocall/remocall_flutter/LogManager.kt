package com.remocall.remocall_flutter

import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import android.util.Base64
import java.io.FileInputStream

class LogManager(private val context: Context) {
    
    companion object {
        private const val TAG = "LogManager"
        private const val LOG_DIR = "app_logs"
        private var instance: LogManager? = null
        
        fun getInstance(context: Context): LogManager {
            if (instance == null) {
                instance = LogManager(context.applicationContext)
            }
            return instance!!
        }
    }
    
    private val logDir: File = File(context.filesDir, LOG_DIR)
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private val fileNameFormat = SimpleDateFormat("yyyy-MM-dd_HH", Locale.getDefault())
    private var currentLogFile: File? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var githubUploader: GitHubUploader? = null
    
    init {
        if (!logDir.exists()) {
            logDir.mkdirs()
        }
        
        // GitHub 업로더 초기화
        try {
            githubUploader = GitHubUploader(context)
            Log.d(TAG, "GitHubUploader initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize GitHubUploader", e)
        }
        
        // 매 시간마다 GitHub 업로드 타이머 설정
        scheduleHourlyUpload()
        
        // 주기적으로 오래된 로그 정리
        scope.launch {
            while (isActive) {
                cleanOldLogs()
                delay(24 * 60 * 60 * 1000L) // 하루에 한 번
            }
        }
    }
    
    // 서비스 생명주기 로그
    fun logServiceLifecycle(event: String, details: String = "") {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "SERVICE_LIFECYCLE")
            put("event", event)
            put("details", details)
        }
        writeLog(log)
    }
    
    // 카카오페이 알림 수신 로그
    fun logNotificationReceived(
        title: String,
        message: String,
        packageName: String,
        notificationId: Int,
        postTime: Long
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "NOTIFICATION_RECEIVED")
            put("packageName", packageName)
            put("notificationId", notificationId)
            put("postTime", postTime)
            put("title", title)
            put("message", message)
        }
        writeLog(log)
    }
    
    // 알림 패턴 필터링 결과 로그
    fun logPatternFilter(message: String, isDeposit: Boolean, reason: String = "") {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "PATTERN_FILTER")
            put("message", message)
            put("isDeposit", isDeposit)
            put("reason", reason)
        }
        writeLog(log)
    }
    
    // 서버 전송 로그
    fun logServerRequest(
        url: String,
        requestData: JSONObject,
        responseCode: Int,
        responseBody: String,
        success: Boolean
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "SERVER_REQUEST")
            put("url", url)
            put("request", requestData)
            put("responseCode", responseCode)
            put("responseBody", responseBody)
            put("success", success)
        }
        writeLog(log)
    }
    
    // 실패 큐 로그
    fun logFailedQueue(
        action: String, // "ADD", "RETRY", "REMOVE"
        notificationId: String,
        message: String,
        retryCount: Int,
        queueSize: Int
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "FAILED_QUEUE")
            put("action", action)
            put("notificationId", notificationId)
            put("message", message)
            put("retryCount", retryCount)
            put("queueSize", queueSize)
        }
        writeLog(log)
    }
    
    // 토큰 갱신 로그
    fun logTokenRefresh(success: Boolean, errorMessage: String = "") {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "TOKEN_REFRESH")
            put("success", success)
            if (!success) put("error", errorMessage)
        }
        writeLog(log)
    }
    
    // 큐 처리 시작/완료 로그
    fun logQueueProcessing(event: String, queueSize: Int, details: String = "") {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "QUEUE_PROCESSING")
            put("event", event) // "START", "COMPLETE", "ITEM_START", "ITEM_COMPLETE", "ITEM_FAILED"
            put("queueSize", queueSize)
            put("details", details)
        }
        writeLog(log)
    }
    
    // 알림 파싱 상세 로그
    fun logNotificationParsing(
        originalMessage: String,
        parsedAmount: String?,
        parsedSender: String?,
        isDeposit: Boolean,
        parseResult: String
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "NOTIFICATION_PARSING")
            put("originalMessage", originalMessage)
            put("parsedAmount", parsedAmount ?: "null")
            put("parsedSender", parsedSender ?: "null")
            put("isDeposit", isDeposit)
            put("parseResult", parseResult)
        }
        writeLog(log)
    }
    
    // 서버 응답 상세 로그 (기존 메소드 확장)
    fun logServerResponseDetail(
        matchStatus: String,
        transactionId: String?,
        depositId: String?,
        errorDetail: String?
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "SERVER_RESPONSE_DETAIL")
            put("matchStatus", matchStatus)
            put("transactionId", transactionId ?: "null")
            put("depositId", depositId ?: "null")
            put("errorDetail", errorDetail ?: "null")
        }
        writeLog(log)
    }
    
    // 에러 로그 (스택 트레이스 포함)
    fun logError(location: String, error: Exception, context: String = "") {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "ERROR")
            put("location", location)
            put("errorMessage", error.message ?: "Unknown error")
            put("errorClass", error.javaClass.simpleName)
            put("stackTrace", error.stackTraceToString())
            put("context", context)
        }
        writeLog(log)
    }
    
    // 서비스 헬스체크 로그
    fun logHealthCheck(
        lastNotificationTime: Long,
        isServiceRunning: Boolean,
        hasNotificationPermission: Boolean,
        queueSize: Int
    ) {
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "HEALTH_CHECK")
            put("lastNotificationTime", lastNotificationTime)
            put("timeSinceLastNotification", System.currentTimeMillis() - lastNotificationTime)
            put("isServiceRunning", isServiceRunning)
            put("hasNotificationPermission", hasNotificationPermission)
            put("queueSize", queueSize)
        }
        writeLog(log)
    }
    
    // 큐 처리 시간 측정 로그
    fun logQueueItemTiming(
        notificationId: String,
        startTime: Long,
        endTime: Long,
        success: Boolean,
        retryCount: Int
    ) {
        val processingTime = endTime - startTime
        val log = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "QUEUE_ITEM_TIMING")
            put("notificationId", notificationId)
            put("processingTimeMs", processingTime)
            put("success", success)
            put("retryCount", retryCount)
        }
        writeLog(log)
    }
    
    private fun writeLog(logData: JSONObject) {
        scope.launch {
            try {
                val now = Date()
                val hourFormat = SimpleDateFormat("yyyy-MM-dd_HH", Locale.getDefault())
                val minuteFormat = SimpleDateFormat("mm", Locale.getDefault())
                val currentHour = hourFormat.format(now)
                val minute = minuteFormat.format(now).toInt()
                val segment = minute / 10  // 0-5 for each 10-minute segment
                val logFileName = "log_${currentHour}_${segment}.json"
                
                if (currentLogFile?.name != logFileName) {
                    currentLogFile = File(logDir, logFileName)
                }
                
                // 파일 크기 체크 (10MB 제한)
                if (currentLogFile!!.exists() && currentLogFile!!.length() > 10 * 1024 * 1024) {
                    Log.w(TAG, "Log file size exceeds 10MB, creating new file")
                    val timestamp = System.currentTimeMillis()
                    currentLogFile = File(logDir, "log_${currentHour}_${segment}_$timestamp.json")
                }
                
                // 로그 추가 (한 줄에 하나의 JSON)
                val logLine = logData.toString() + "\n"
                currentLogFile!!.appendText(logLine)
                
                // 디버그용 로그 출력
                Log.d(TAG, "Log written: ${logData.getString("type")}")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error writing log", e)
            }
        }
    }
    
    private fun scheduleHourlyUpload() {
        scope.launch {
            while (isActive) {
                delay(600000) // 10분
                uploadToGitHub()
            }
        }
    }
    
    private suspend fun uploadToGitHub() {
        withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "=== GITHUB UPLOAD START ===")
                
                if (githubUploader == null) {
                    Log.e(TAG, "GitHubUploader not initialized")
                    return@withContext
                }
                
                // 매장 코드 가져오기
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                Log.d(TAG, "Reading shop code from SharedPreferences...")
                val shopCode = prefs.getString("flutter.shop_code", "unknown") ?: "unknown"
                Log.d(TAG, "Shop code from preferences: $shopCode")
                
                // 다른 키 값들도 확인 (디버깅용)
                val allKeys = prefs.all.keys
                Log.d(TAG, "All SharedPreferences keys: ${allKeys.joinToString(", ")}")
                
                // 로그 디렉토리 확인
                Log.d(TAG, "Log directory: ${logDir.absolutePath}")
                Log.d(TAG, "Log directory exists: ${logDir.exists()}")
                
                val allFiles = logDir.listFiles() ?: emptyArray()
                Log.d(TAG, "Total files in log directory: ${allFiles.size}")
                allFiles.forEach { file ->
                    Log.d(TAG, "File: ${file.name}, Size: ${file.length()}, Modified: ${Date(file.lastModified())}")
                }
                
                // 수동 업로드인 경우 모든 파일 업로드 (테스트용)
                Log.d(TAG, "Manual upload - uploading all files")
                
                val filesToUpload = logDir.listFiles()?.filter { file ->
                    file.name.endsWith(".json")
                } ?: emptyList()
                
                if (filesToUpload.isEmpty()) {
                    Log.d(TAG, "No log files to upload")
                    return@withContext
                }
                
                Log.d(TAG, "Found ${filesToUpload.size} files to upload for shop: $shopCode")
                filesToUpload.forEach { file ->
                    Log.d(TAG, "Will upload: ${file.name}")
                }
                
                // GitHub 연결 테스트
                Log.d(TAG, "Testing GitHub connection...")
                if (!githubUploader!!.testConnection()) {
                    Log.e(TAG, "GitHub connection test failed")
                    return@withContext
                }
                Log.d(TAG, "GitHub connection test passed")
                
                // 각 파일 GitHub 업로드
                filesToUpload.forEach { file ->
                    try {
                        Log.d(TAG, "Uploading ${file.name} to GitHub...")
                        val success = githubUploader!!.uploadFile(file, shopCode)
                        if (success) {
                            Log.d(TAG, "✅ Successfully uploaded ${file.name} to GitHub")
                            file.delete() // 업로드 성공 시 파일 삭제
                            Log.d(TAG, "Deleted local file: ${file.name}")
                        } else {
                            Log.e(TAG, "❌ Failed to upload ${file.name} to GitHub")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error uploading ${file.name} to GitHub", e)
                        e.printStackTrace()
                    }
                }
                
                Log.d(TAG, "=== GITHUB UPLOAD END ===")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error in uploadToGitHub", e)
                e.printStackTrace()
            }
        }
    }
    
    private fun uploadFileToServer(file: File, shopCode: String, isProduction: Boolean): Boolean {
        try {
            // API URL 설정
            val apiUrl = if (isProduction) {
                "https://admin-api.snappay.online/api/app/logs/upload"
            } else {
                "https://kakaopay-admin-api.flexteam.kr/api/app/logs/upload"
            }
            
            val url = URL(apiUrl)
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            connection.doOutput = true
            
            // 파일 내용을 Base64로 인코딩
            val fileBytes = file.readBytes()
            val encodedContent = Base64.encodeToString(fileBytes, Base64.NO_WRAP)
            
            // JSON 요청 생성
            val requestData = JSONObject().apply {
                put("shopCode", shopCode)
                put("fileName", file.name)
                put("fileSize", file.length())
                put("content", encodedContent)
                put("timestamp", System.currentTimeMillis())
                put("deviceId", getDeviceId())
            }
            
            // 요청 전송
            connection.outputStream.use { os ->
                val input = requestData.toString().toByteArray(charset("utf-8"))
                os.write(input, 0, input.size)
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Upload response code: $responseCode")
            
            return responseCode == 200 || responseCode == 201
            
        } catch (e: Exception) {
            Log.e(TAG, "Error uploading file to server", e)
            return false
        }
    }
    
    private fun getDeviceId(): String {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var deviceId = prefs.getString("device_id", null)
            
            if (deviceId == null) {
                deviceId = UUID.randomUUID().toString()
                prefs.edit().putString("device_id", deviceId).apply()
            }
            
            deviceId
        } catch (e: Exception) {
            "unknown"
        }
    }
    
    // 수동 업로드 트리거
    fun triggerUpload() {
        Log.d(TAG, "Manual upload triggered")
        scope.launch {
            try {
                Log.d(TAG, "Starting manual upload in coroutine")
                uploadToGitHub()
            } catch (e: Exception) {
                Log.e(TAG, "Error in manual upload", e)
            }
        }
    }
    
    // 로그 파일 목록 가져오기
    fun getLogFiles(): List<File> {
        return logDir.listFiles()?.filter { it.name.endsWith(".json") }
            ?.sortedByDescending { it.lastModified() } ?: emptyList()
    }
    
    // 로그 파일 내용 읽기
    fun readLogFile(fileName: String): List<JSONObject> {
        val file = File(logDir, fileName)
        if (!file.exists()) return emptyList()
        
        return try {
            file.readLines()
                .filter { it.isNotBlank() }
                .map { JSONObject(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading log file", e)
            emptyList()
        }
    }
    
    // 오래된 로그 정리
    fun cleanOldLogs(daysToKeep: Int = 7) {
        scope.launch {
            try {
                val cutoffTime = System.currentTimeMillis() - (daysToKeep * 24 * 60 * 60 * 1000L)
                var totalSize = 0L
                val files = logDir.listFiles()?.sortedByDescending { it.lastModified() } ?: emptyList()
                
                files.forEach { file ->
                    totalSize += file.length()
                    
                    // 7일 이상 된 파일이거나 전체 크기가 100MB를 초과하면 삭제
                    if (file.lastModified() < cutoffTime || totalSize > 100 * 1024 * 1024) {
                        file.delete()
                        Log.d(TAG, "Deleted log file: ${file.name}")
                        totalSize -= file.length()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning old logs", e)
            }
        }
    }
    
    // 최근 로그 가져오기 (테스트용)
    fun getRecentLogs(limit: Int = 50): String {
        return try {
            val allLogs = mutableListOf<JSONObject>()
            
            // 모든 로그 파일에서 로그 읽기
            getLogFiles().take(3).forEach { file -> // 최신 3개 파일만
                val fileLogs = readLogFile(file.name)
                allLogs.addAll(fileLogs)
            }
            
            // 시간순으로 정렬하고 최근 limit개만 가져오기 
            val recentLogs = allLogs
                .sortedByDescending { it.optLong("timestamp", 0) }
                .take(limit)
            
            // JSON 배열로 변환
            val jsonArray = JSONArray()
            recentLogs.forEach { jsonArray.put(it) }
            
            jsonArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting recent logs", e)
            "[]"
        }
    }
    
    fun destroy() {
        scope.cancel()
    }
}