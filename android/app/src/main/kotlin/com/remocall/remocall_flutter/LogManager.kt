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
import java.util.Collections

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
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone("Asia/Seoul")
    }
    private val fileNameFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone("Asia/Seoul")
    }
    private var currentLogFile: File? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var githubUploader: GitHubUploader? = null
    private val uploadTrackingPrefs = context.getSharedPreferences("LogUploadTracking", Context.MODE_PRIVATE)
    private val pendingLogs = Collections.synchronizedList(mutableListOf<JSONObject>())  // 업로드 대기중인 로그
    
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
        
        // 주기적 업로드 - 5분마다
        scope.launch {
            while (isActive) {
                delay(5 * 60 * 1000L) // 5분 대기
                try {
                    uploadToGitHub()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in periodic upload", e)
                }
            }
        }
        
        // 주기적으로 오래된 로그 정리 (더 자주)
        scope.launch {
            while (isActive) {
                cleanOldLogs()
                delay(60 * 60 * 1000L) // 1시간마다
            }
        }
    }
    
    // 서비스 라이프사이클 로그 (모든 이벤트)
    fun logServiceLifecycle(event: String, details: String = "") {
        val log = JSONObject().apply {
            put("type", "서비스상태")
            put("event", event)
            if (details.isNotEmpty()) put("details", details)
        }
        writeLog(log)
    }
    
    // 알림 인식 로그
    fun logNotificationReceived(
        packageName: String,
        title: String,
        message: String,
        extras: JSONObject? = null
    ) {
        val simplifiedPackageName = when(packageName) {
            "com.kakaopay.app" -> "카카오페이"
            "com.kakao.talk" -> "카카오톡"
            "com.remocall.remocall_flutter" -> "스냅페이"
            "com.test.kakaonotifier.kakao_test_notifier" -> "테스트앱"
            else -> packageName
        }
        
        val log = JSONObject().apply {
            put("type", "알림인식")
            put("앱", simplifiedPackageName)
            if (title.isNotEmpty()) put("title", title)
            if (message.isNotEmpty()) put("message", message)
            if (extras != null && extras.length() > 0) {
                put("extras", extras)
            }
        }
        writeLog(log)
    }
    
    // 토큰 갱신 로그
    fun logTokenRefresh(
        event: String,  // "시작", "성공", "실패", "401재시도"
        reason: String = "",  // "주기적", "401에러", "수동"
        errorMessage: String = "",
        oldTokenExpiry: Long = 0,
        newTokenExpiry: Long = 0
    ) {
        val log = JSONObject().apply {
            put("type", "토큰갱신")
            put("event", event)
            if (reason.isNotEmpty()) put("reason", reason)
            if (errorMessage.isNotEmpty()) put("error", errorMessage)
            if (oldTokenExpiry > 0) put("oldExpiry", dateFormat.format(Date(oldTokenExpiry)))
            if (newTokenExpiry > 0) put("newExpiry", dateFormat.format(Date(newTokenExpiry)))
        }
        writeLog(log)
    }
    
    // 큐 처리 로그
    fun logQueueProcessing(
        event: String,  // "시작", "항목완료", "완료"
        message: String = "",
        queueSize: Int = 0,
        status: String = "",
        retryCount: Int = 0
    ) {
        val log = JSONObject().apply {
            put("type", "큐처리")
            put("event", event)
            if (message.isNotEmpty()) put("message", message)
            if (queueSize > 0) put("queueSize", queueSize)
            if (status.isNotEmpty()) put("status", status)
            if (retryCount > 0) put("retryCount", retryCount)
        }
        writeLog(log)
    }
    
    // 시스템 오류 로그
    fun logError(location: String, error: Exception, context: String = "") {
        val log = JSONObject().apply {
            put("type", "시스템오류")
            put("위치", location)
            put("메시지", error.message ?: "Unknown error")
            put("클래스", error.javaClass.simpleName)
            if (context.isNotEmpty()) put("상황", context)
        }
        writeLog(log)
        
        // 시스템 오류 발생 시 즉시 업로드
        triggerImmediateUpload()
    }
    
    // 서비스 헬스체크 로그 - 제거 (불필요)
    
    // 큐 처리 시간 로그 - 제거 (불필요)
    
    private fun writeLog(logData: JSONObject) {
        scope.launch {
            try {
                val now = Date()
                val dateStr = fileNameFormat.format(now)  // yyyy-MM-dd 형식
                val logFileName = "${dateStr}.log"
                
                if (currentLogFile?.name != logFileName) {
                    currentLogFile = File(logDir, logFileName)
                }
                
                // 파일 크기 체크 (5MB 제한)
                if (currentLogFile!!.exists() && currentLogFile!!.length() > 5 * 1024 * 1024) {
                    Log.w(TAG, "Log file size exceeds 5MB, triggering immediate upload")
                    triggerImmediateUpload()
                    return@launch  // 업로드 후 새 파일에 기록되도록
                }
                
                // 포맷된 로그 라인 생성
                val datetime = dateFormat.format(now)
                val type = logData.getString("type")
                val formattedLog = formatLogLine(type, datetime, logData)
                
                // 로그 추가
                currentLogFile!!.appendText(formattedLog + "\n")
                
                // 타임스탬프 추가하여 업로드 대기 목록에 추가
                logData.put("timestamp", now.time)
                pendingLogs.add(logData)
                
                // 디버그용 로그 출력
                Log.d(TAG, "Log written: $type")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error writing log", e)
            }
        }
    }
    
    // 주기적 업로드 제거 - 사용하지 않음
    
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
                
                // 마지막 업로드 시간 확인
                val lastUploadTimestamp = uploadTrackingPrefs.getLong("last_uploaded_timestamp", 0L)
                val lastUploadDate = uploadTrackingPrefs.getString("last_uploaded_date", "") ?: ""
                val currentDate = fileNameFormat.format(Date())
                
                Log.d(TAG, "Last upload timestamp: $lastUploadTimestamp, date: $lastUploadDate")
                Log.d(TAG, "Current date: $currentDate")
                
                // 날짜가 변경되었으면 새로운 파일로 시작
                val isNewDay = lastUploadDate != currentDate
                if (isNewDay) {
                    Log.d(TAG, "New day detected, will create new file")
                }
                
                // 프로덕션/개발 모드 확인
                val isProduction = prefs.getBoolean("flutter.is_production", true)
                Log.d(TAG, "Upload mode: ${if (isProduction) "PRODUCTION" else "DEVELOPMENT"}")
                
                // 업로드할 로그 준비
                val logsToUpload = mutableListOf<JSONObject>()
                
                // 오늘 날짜의 로그 파일 찾기
                val today = fileNameFormat.format(Date())
                val todayFiles = logDir.listFiles()?.filter { file ->
                    file.name.startsWith(today) && (file.name.endsWith(".log") || file.name.endsWith(".json"))
                } ?: emptyList()
                
                // 포맷된 로그 파일 처리 (.log 파일)
                val logFile = todayFiles.find { it.name.endsWith(".log") }
                if (logFile != null && logFile.exists()) {
                    try {
                        // 파일 전체를 읽어서 업로드 (timestamp 기반 필터링 안 함)
                        val logContent = logFile.readText()
                        if (logContent.isNotEmpty()) {
                            // 로그를 직접 업로드
                            Log.d(TAG, "Found log file with ${logFile.length()} bytes")
                            
                            // 임시 파일 생성
                            val tempFile = File(logDir, "upload_temp_${System.currentTimeMillis()}.log")
                            tempFile.writeText(logContent)
                            
                            try {
                                Log.d(TAG, "Uploading to GitHub...")
                                val success = githubUploader!!.uploadFile(
                                    file = tempFile,
                                    shopCode = shopCode,
                                    isProduction = isProduction,
                                    isNewDay = isNewDay,
                                    lastUploadTimestamp = System.currentTimeMillis()
                                )
                                
                                if (success) {
                                    Log.d(TAG, "✅ Successfully uploaded to GitHub")
                                    
                                    // 업로드 성공 시 추적 정보 업데이트
                                    uploadTrackingPrefs.edit()
                                        .putLong("last_uploaded_timestamp", System.currentTimeMillis())
                                        .putString("last_uploaded_date", currentDate)
                                        .apply()
                                    
                                    Log.d(TAG, "Updated last upload timestamp")
                                    
                                    // 업로드 완료 후 파일 즉시 삭제
                                    if (logFile.delete()) {
                                        Log.d(TAG, "✅ Immediately deleted local file: ${logFile.name}")
                                        // 대기 중인 로그도 초기화
                                        pendingLogs.clear()
                                    } else {
                                        Log.w(TAG, "⚠️ Failed to delete local file: ${logFile.name}")
                                    }
                                } else {
                                    Log.e(TAG, "❌ Failed to upload to GitHub")
                                }
                            } finally {
                                // 임시 파일 삭제
                                tempFile.delete()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing log file", e)
                    }
                } else {
                    Log.d(TAG, "No log file found for today")
                }
                
                // GitHub 연결 테스트
                Log.d(TAG, "Testing GitHub connection...")
                if (!githubUploader!!.testConnection()) {
                    Log.e(TAG, "GitHub connection test failed")
                    return@withContext
                }
                Log.d(TAG, "GitHub connection test passed")
                
                // 레거시 JSON 파일 삭제
                val jsonFile = todayFiles.find { it.name.endsWith(".json") }
                if (jsonFile != null && jsonFile.exists()) {
                    jsonFile.delete()
                    Log.d(TAG, "Deleted legacy JSON file: ${jsonFile.name}")
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
    
    // 즉시 업로드 트리거 (비정상 상황 발생 시)
    private fun triggerImmediateUpload() {
        Log.d(TAG, "Immediate upload triggered due to abnormal situation")
        scope.launch {
            try {
                uploadToGitHub()
            } catch (e: Exception) {
                Log.e(TAG, "Error in immediate upload", e)
            }
        }
    }
    
    // 로그 파일 목록 가져오기
    fun getLogFiles(): List<File> {
        return logDir.listFiles()?.filter { it.name.endsWith(".log") || it.name.endsWith(".json") }
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
    
    // 오래된 로그 정리 (더 엄격하게)
    fun cleanOldLogs(daysToKeep: Int = 1) {
        scope.launch {
            try {
                // 1일 이상 된 파일 삭제 (기본값 변경)
                val cutoffTime = System.currentTimeMillis() - (daysToKeep * 24 * 60 * 60 * 1000L)
                var totalSize = 0L
                val files = logDir.listFiles()?.sortedByDescending { it.lastModified() } ?: emptyList()
                
                files.forEach { file ->
                    totalSize += file.length()
                    
                    // 1일 이상 된 파일이거나 전체 크기가 10MB를 초과하면 삭제
                    if (file.lastModified() < cutoffTime || totalSize > 10 * 1024 * 1024) {
                        if (file.delete()) {
                            Log.d(TAG, "Deleted old log file: ${file.name}")
                        }
                    }
                }
                
                // 현재 로그 파일도 크기 체크
                currentLogFile?.let { file ->
                    if (file.exists() && file.length() > 5 * 1024 * 1024) {
                        // 5MB 초과 시 즉시 업로드 트리거
                        Log.w(TAG, "Current log file exceeds 5MB, triggering upload")
                        triggerImmediateUpload()
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
    
    private fun formatLogLine(type: String, datetime: String, data: JSONObject): String {
        val parts = mutableListOf<String>()
        
        // 타입별 이모지 추가
        val emoji = when(type) {
            "알림인식" -> "🔔"
            "서비스상태" -> "⚫"
            "큐처리" -> "🟡"
            "토큰갱신" -> "🔑"
            "시스템오류" -> "🔴"
            "중요이벤트" -> "📌"
            else -> "⚪"
        }
        
        parts.add(emoji)
        parts.add("[$type]")
        parts.add("[$datetime]")
        
        when (type) {
            "알림인식" -> {
                val appName = data.optString("앱")
                appName.takeIf { it.isNotEmpty() }?.let { parts.add("[$it]") }
                data.optString("title").takeIf { it.isNotEmpty() }?.let { parts.add("[title:$it]") }
                data.optString("message").takeIf { it.isNotEmpty() }?.let { parts.add("[message:$it]") }
                
                val extras = data.optJSONObject("extras")
                if (extras != null) {
                    // 카카오페이 알림인 경우 추가 정보 표시
                    if (appName == "카카오페이") {
                        extras.optString("key").takeIf { it != "null" }?.let { parts.add("[key:$it]") }
                        extras.optString("groupKey").takeIf { it != "null" }?.let { parts.add("[group:$it]") }
                        extras.optInt("flags", -1).takeIf { it >= 0 }?.let { parts.add("[flags:$it]") }
                        extras.optBoolean("isGroupSummary", false).let { 
                            if (it) parts.add("[그룹요약]") 
                        }
                    }
                    parts.add("[extras:$extras]")
                }
            }
            "서비스상태" -> {
                data.optString("event").takeIf { it.isNotEmpty() }?.let { parts.add("[이벤트:$it]") }
                data.optString("details").takeIf { it.isNotEmpty() }?.let { parts.add("[상세:$it]") }
            }
            "큐처리" -> {
                data.optString("event").takeIf { it.isNotEmpty() }?.let { parts.add("[이벤트:$it]") }
                data.optString("message").takeIf { it.isNotEmpty() }?.let { parts.add("[message:$it]") }
                data.optInt("queueSize", 0).takeIf { it > 0 }?.let { parts.add("[큐사이즈:$it]") }
                data.optString("status").takeIf { it.isNotEmpty() }?.let { parts.add("[상태:$it]") }
                data.optInt("retryCount", 0).takeIf { it > 0 }?.let { parts.add("[재시도:$it]") }
            }
            "토큰갱신" -> {
                data.optString("event").takeIf { it.isNotEmpty() }?.let { parts.add("[이벤트:$it]") }
                data.optString("reason").takeIf { it.isNotEmpty() }?.let { parts.add("[이유:$it]") }
                data.optString("error").takeIf { it.isNotEmpty() }?.let { parts.add("[에러:$it]") }
                data.optString("oldExpiry").takeIf { it.isNotEmpty() }?.let { parts.add("[이전만료:$it]") }
                data.optString("newExpiry").takeIf { it.isNotEmpty() }?.let { parts.add("[새만료:$it]") }
            }
            "시스템오류" -> {
                data.optString("위치").takeIf { it.isNotEmpty() }?.let { parts.add("[위치:$it]") }
                data.optString("메시지").takeIf { it.isNotEmpty() }?.let { parts.add("[메시지:$it]") }
                data.optString("클래스").takeIf { it.isNotEmpty() }?.let { parts.add("[클래스:$it]") }
                data.optString("상황").takeIf { it.isNotEmpty() }?.let { parts.add("[상황:$it]") }
            }
            "중요이벤트" -> {
                data.optString("event").takeIf { it.isNotEmpty() }?.let { parts.add("[이벤트:$it]") }
                data.optString("details").takeIf { it.isNotEmpty() }?.let { parts.add("[상세:$it]") }
            }
            else -> {
                // 기타 타입은 모든 필드를 표시
                val iter = data.keys()
                while (iter.hasNext()) {
                    val key = iter.next()
                    if (key != "type" && key != "timestamp") {
                        val value = data.get(key)
                        parts.add("[$key:$value]")
                    }
                }
            }
        }
        
        return parts.joinToString(" ")
    }
    
    fun destroy() {
        scope.cancel()
    }
}