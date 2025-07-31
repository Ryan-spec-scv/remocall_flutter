package com.remocall.remocall_flutter

import android.content.Context
import android.util.Log
import android.util.Base64
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class GitHubUploader(private val context: Context) {
    
    companion object {
        private const val TAG = "GitHubUploader"
        
        // GitHub 설정 - GitHubSecrets 파일에서 가져오기
        private const val GITHUB_TOKEN = GitHubSecrets.GITHUB_TOKEN
        private const val GITHUB_OWNER = GitHubSecrets.GITHUB_OWNER
        private const val GITHUB_REPO = GitHubSecrets.GITHUB_REPO
        private const val GITHUB_API_BASE = "https://api.github.com"
    }
    
    fun uploadFile(file: File, shopCode: String, isProduction: Boolean = true): Boolean {
        try {
            Log.d(TAG, "Uploading file to GitHub: ${file.name}")
            
            // 환경별로 경로 구분: logs/environment/shopCode/YYYY-MM-DD/filename
            val environment = if (isProduction) "production" else "development"
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val dateFolder = dateFormat.format(Date())
            val filePath = "logs/$environment/$shopCode/$dateFolder/${file.name}"
            
            Log.d(TAG, "Upload path: $filePath (Environment: $environment)")
            
            // 파일 내용을 Base64로 인코딩
            val fileContent = Base64.encodeToString(file.readBytes(), Base64.NO_WRAP)
            
            // GitHub API URL
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$filePath"
            
            // 기존 파일 SHA 확인 (파일이 이미 존재하는 경우)
            val existingSha = getFileSha(filePath)
            
            // JSON 요청 생성
            val requestData = JSONObject().apply {
                put("message", "Upload log file: ${file.name} from shop $shopCode")
                put("content", fileContent)
                if (existingSha != null) {
                    put("sha", existingSha) // 기존 파일 업데이트시 필요
                }
            }
            
            // HTTP 연결 설정
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "PUT"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            connection.doOutput = true
            
            // 요청 전송
            connection.outputStream.use { outputStream ->
                val input = requestData.toString().toByteArray(Charsets.UTF_8)
                outputStream.write(input, 0, input.size)
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "GitHub API response code: $responseCode")
            
            if (responseCode == 200 || responseCode == 201) {
                val response = connection.inputStream.bufferedReader().readText()
                val responseJson = JSONObject(response)
                val downloadUrl = responseJson.getJSONObject("content").getString("download_url")
                
                Log.d(TAG, "✅ File uploaded successfully to GitHub")
                Log.d(TAG, "File URL: $downloadUrl")
                return true
            } else {
                val errorResponse = connection.errorStream?.bufferedReader()?.readText() ?: "No error details"
                Log.e(TAG, "❌ Upload failed with code $responseCode: $errorResponse")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error uploading file to GitHub", e)
        }
        
        return false
    }
    
    private fun getFileSha(filePath: String): String? {
        return try {
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$filePath"
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                val response = connection.inputStream.bufferedReader().readText()
                val responseJson = JSONObject(response)
                responseJson.getString("sha")
            } else {
                null // 파일이 존재하지 않음
            }
        } catch (e: Exception) {
            Log.d(TAG, "File does not exist, will create new: $filePath")
            null
        }
    }
    
    fun testConnection(): Boolean {
        return try {
            if (GITHUB_TOKEN.isEmpty() || GITHUB_TOKEN == "YOUR_GITHUB_TOKEN_HERE") {
                Log.e(TAG, "❌ GitHub token not configured")
                return false
            }
            
            // 리포지토리 정보 확인으로 연결 테스트
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO"
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            
            val responseCode = connection.responseCode
            Log.d(TAG, "GitHub connection test response code: $responseCode")
            
            if (responseCode == 200) {
                val response = connection.inputStream.bufferedReader().readText()
                val repoInfo = JSONObject(response)
                Log.d(TAG, "✅ GitHub connection test successful")
                Log.d(TAG, "Repository: ${repoInfo.getString("full_name")}")
                Log.d(TAG, "Private: ${repoInfo.getBoolean("private")}")
                true
            } else {
                val errorResponse = connection.errorStream?.bufferedReader()?.readText() ?: "No error details"
                Log.e(TAG, "❌ Connection test failed with code $responseCode: $errorResponse")
                false
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ GitHub connection test failed", e)
            false
        }
    }
}