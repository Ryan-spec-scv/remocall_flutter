package com.remocall.remocall_flutter

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Timer
import java.util.TimerTask
import kotlin.concurrent.timerTask

/**
 * 토큰 관리를 전담하는 클래스
 * - JWT 토큰 갱신
 * - WorkManager를 통한 주기적 갱신
 * - 토큰 저장 및 조회
 */
class TokenManager(private val context: Context) {
    
    companion object {
        private const val TAG = "TokenManager"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        
        @Volatile
        private var refreshTimer: Timer? = null
        
        @Volatile
        private var isSchedulerRunning = false
        
        @Volatile
        private var instance: TokenManager? = null
        
        fun getInstance(context: Context): TokenManager {
            return instance ?: synchronized(this) {
                instance ?: TokenManager(context.applicationContext).also { instance = it }
            }
        }
    }
    
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * 토큰 갱신 수행
     */
    fun refreshToken(): Boolean {
        try {
            Log.d(TAG, "Starting token refresh...")
            
            val refreshToken = getRefreshToken()
            if (refreshToken.isNullOrEmpty()) {
                Log.e(TAG, "No refresh token available")
                return false
            }
            
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
                        saveTokens(newAccessToken, newRefreshToken)
                        
                        Log.d(TAG, "✅ Token refresh successful")
                        return true
                    }
                }
                
                Log.e(TAG, "Token refresh failed with status code: $responseCode")
                return false
                
            } finally {
                connection.disconnect()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing token", e)
            return false
        }
    }
    
    /**
     * 액세스 토큰 가져오기
     */
    fun getAccessToken(): String? {
        return prefs.getString("flutter.access_token", null)
    }
    
    /**
     * 리프레시 토큰 가져오기
     */
    fun getRefreshToken(): String? {
        return prefs.getString("flutter.refresh_token", null)
    }
    
    /**
     * 토큰 저장
     */
    fun saveTokens(accessToken: String, refreshToken: String) {
        prefs.edit()
            .putString("flutter.access_token", accessToken)
            .putString("flutter.refresh_token", refreshToken)
            .putLong("flutter.last_token_refresh", System.currentTimeMillis())
            .apply()
    }
    
    /**
     * 주기적 토큰 갱신 스케줄링
     */
    fun schedulePeriodicRefresh() {
        synchronized(this) {
            // 이미 실행 중이면 스킵
            if (isSchedulerRunning) {
                Log.d(TAG, "Token refresh scheduler is already running, skipping")
                return
            }
            
            val isProduction = prefs.getBoolean("flutter.is_production", true)
            val intervalMillis = if (isProduction) 60L * 60 * 1000 else 5L * 60 * 1000 // 프로덕션: 1시간, 개발: 5분
            
            Log.d(TAG, "Scheduling periodic token refresh every ${intervalMillis / 1000 / 60} minutes")
            
            cancelPeriodicRefresh()
            
            refreshTimer = Timer("TokenRefreshTimer")
            refreshTimer?.scheduleAtFixedRate(timerTask {
                Log.d(TAG, "Running scheduled token refresh")
                refreshToken()
            }, intervalMillis, intervalMillis)
            
            isSchedulerRunning = true
            Log.d(TAG, "Token refresh scheduler started successfully")
        }
    }
    
    /**
     * 토큰 갱신 작업 취소
     */
    fun cancelPeriodicRefresh() {
        synchronized(this) {
            refreshTimer?.cancel()
            refreshTimer = null
            isSchedulerRunning = false
            Log.d(TAG, "Token refresh scheduler cancelled")
        }
    }
    
    /**
     * 토큰 유효성 확인
     */
    fun isTokenValid(): Boolean {
        val accessToken = getAccessToken()
        if (accessToken.isNullOrEmpty()) return false
        
        // 마지막 갱신 시간 확인 (간단한 유효성 체크)
        val lastRefresh = prefs.getLong("flutter.last_token_refresh", 0)
        val hoursSinceRefresh = (System.currentTimeMillis() - lastRefresh) / (1000 * 60 * 60)
        
        return hoursSinceRefresh < 24 // 24시간 이내면 유효하다고 가정
    }
}