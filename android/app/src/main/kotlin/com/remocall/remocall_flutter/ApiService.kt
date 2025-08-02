package com.remocall.remocall_flutter

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * API 통신을 담당하는 서비스
 * - 알림 서버 전송
 * - 응답 처리
 * - 토큰 검증 및 갱신
 */
class ApiService(private val context: Context) {
    
    companion object {
        private const val TAG = "ApiService"
        private const val CONNECT_TIMEOUT = 30000
        private const val READ_TIMEOUT = 30000
        
        @Volatile
        private var instance: ApiService? = null
        
        fun getInstance(context: Context): ApiService {
            return instance ?: synchronized(this) {
                instance ?: ApiService(context.applicationContext).also { instance = it }
            }
        }
    }
    
    private val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private val logManager = LogManager.getInstance(context)
    private val tokenManager = TokenManager.getInstance(context)
    
    /**
     * 알림을 서버로 전송
     * @return Pair<성공여부, 중복여부>
     */
    fun sendNotification(message: String): Pair<Boolean, Boolean> {
        val startTime = System.currentTimeMillis()
        try {
            Log.d(TAG, "Sending notification to server: $message")
            
            // 토큰 확인
            val accessToken = tokenManager.getAccessToken()
            if (accessToken.isNullOrEmpty()) {
                Log.e(TAG, "No access token available")
                
                // 토큰 갱신 시도
                if (tokenManager.refreshToken("401에러")) {
                    return sendNotificationWithToken(message, tokenManager.getAccessToken()!!)
                }
                
                return Pair(false, false)
            }
            
            return sendNotificationWithToken(message, accessToken)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending notification", e)
            logManager.logError("sendNotification", e, message)
            return Pair(false, false)
        }
    }
    
    /**
     * 토큰과 함께 알림 전송
     */
    private fun sendNotificationWithToken(
        message: String, 
        accessToken: String,
        isRetry: Boolean = false
    ): Pair<Boolean, Boolean> {
        
        val isProduction = prefs.getBoolean("flutter.is_production", true)
        val apiUrl = if (isProduction) {
            "https://admin-api.snappay.online/api/kakao-deposits/webhook"
        } else {
            "https://kakaopay-admin-api.flexteam.kr/api/kakao-deposits/webhook"
        }
        
        Log.d(TAG, "Using API URL: $apiUrl (Production: $isProduction)")
        
        val url = URL(apiUrl)
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            // 요청 설정
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.connectTimeout = CONNECT_TIMEOUT
            connection.readTimeout = READ_TIMEOUT
            connection.doOutput = true
            
            // 요청 데이터
            val requestData = JSONObject().apply {
                put("message", message)
                put("timestamp", System.currentTimeMillis())
            }
            
            // 요청 전 로그 - 제거 (불필요한 정보)
            
            // 요청 전송
            connection.outputStream.use { os ->
                val input = requestData.toString().toByteArray(charset("utf-8"))
                os.write(input, 0, input.size)
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Response code: $responseCode")
            
            when (responseCode) {
                200, 201 -> {
                    // 성공
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    return handleSuccessResponse(response, apiUrl, requestData, responseCode)
                }
                401 -> {
                    // 토큰 만료
                    Log.e(TAG, "401 Unauthorized - Token expired")
                    
                    if (!isRetry) {
                        logManager.logTokenRefresh("401재시도", "401에러", "알림 전송 중 토큰 만료")
                        if (tokenManager.refreshToken("401에러")) {
                            // 토큰 갱신 성공, 재시도
                            val newToken = tokenManager.getAccessToken()
                            if (!newToken.isNullOrEmpty()) {
                                Log.d(TAG, "Retrying with new token")
                                return sendNotificationWithToken(message, newToken, true)
                            }
                        }
                    }
                    
                    return Pair(false, false)
                }
                else -> {
                    // 기타 오류
                    val errorResponse = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: "No error response"
                    Log.e(TAG, "Server error ($responseCode): $errorResponse")
                    
                    // 로그 제거 - 불필요
                    
                    return Pair(false, false)
                }
            }
            
        } finally {
            connection.disconnect()
        }
    }
    
    /**
     * 성공 응답 처리
     */
    private fun handleSuccessResponse(
        response: String,
        apiUrl: String,
        requestData: JSONObject,
        responseCode: Int
    ): Pair<Boolean, Boolean> {
        try {
            val jsonResponse = JSONObject(response)
            val success = jsonResponse.optBoolean("success", false)
            val data = jsonResponse.optJSONObject("data")
            val matchStatus = data?.optString("match_status", "unknown") ?: "unknown"
            
            // 서버 응답 상세 정보 추출
            val transactionId = data?.optString("transaction_id", null)
            val depositId = data?.optString("deposit_id", null)
            val errorDetail = data?.optString("error_detail", null)
            
            // 로그 제거 - 불필요
            
            val isDuplicate = matchStatus == "duplicate"
            val isSuccess = success && matchStatus != "failed"
            
            if (isDuplicate) {
                Log.d(TAG, "Server says notification is duplicate")
            }
            
            return Pair(isSuccess, isDuplicate)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing response", e)
            logManager.logError("handleSuccessResponse", e, "Response: $response")
            return Pair(true, false) // 파싱 에러는 성공으로 처리
        }
    }
    
    /**
     * API 연결 테스트
     */
    fun testConnection(): Boolean {
        return try {
            val isProduction = prefs.getBoolean("flutter.is_production", true)
            val apiUrl = if (isProduction) {
                "https://admin-api.snappay.online/health"
            } else {
                "https://kakaopay-admin-api.flexteam.kr/health"
            }
            
            val url = URL(apiUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            
            val responseCode = connection.responseCode
            connection.disconnect()
            
            responseCode == 200
        } catch (e: Exception) {
            Log.e(TAG, "Connection test failed", e)
            false
        }
    }
}