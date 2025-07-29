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
    
    private fun writeLog(logData: JSONObject) {
        scope.launch {
            try {
                val currentHour = fileNameFormat.format(Date())
                val logFileName = "log_$currentHour.json"
                
                if (currentLogFile?.name != logFileName) {
                    currentLogFile = File(logDir, logFileName)
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
                delay(3600000) // 1시간
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
                val shopCode = prefs.getString("flutter.shop_code", "unknown") ?: "unknown"
                Log.d(TAG, "Shop code: $shopCode")
                
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
                logDir.listFiles()?.forEach { file ->
                    if (file.lastModified() < cutoffTime) {
                        file.delete()
                        Log.d(TAG, "Deleted old log file: ${file.name}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning old logs", e)
            }
        }
    }
    
    fun destroy() {
        scope.cancel()
    }
}