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
import org.json.JSONArray

class GitHubUploader(private val context: Context) {
    
    companion object {
        private const val TAG = "GitHubUploader"
        
        // GitHub 설정 - GitHubSecrets 파일에서 가져오기
        private const val GITHUB_TOKEN = GitHubSecrets.GITHUB_TOKEN
        private const val GITHUB_OWNER = GitHubSecrets.GITHUB_OWNER
        private const val GITHUB_REPO = GitHubSecrets.GITHUB_REPO
        private const val GITHUB_API_BASE = "https://api.github.com"
    }
    
    fun uploadFile(
        file: File, 
        shopCode: String, 
        isProduction: Boolean = true,
        isNewDay: Boolean = false,
        lastUploadTimestamp: Long = 0L
    ): Boolean {
        try {
            Log.d(TAG, "Uploading file to GitHub: ${file.name}")
            
            // 환경별로 경로 구분: logs/environment/shopCode/YYYY-MM-DD.json
            val environment = if (isProduction) "production" else "development"
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply {
                timeZone = TimeZone.getTimeZone("Asia/Seoul")
            }
            val dateStr = dateFormat.format(Date())
            val filePath = "logs/$environment/$shopCode/${dateStr}.log"
            
            Log.d(TAG, "Upload path: $filePath (Environment: $environment)")
            
            // 파일 내용 읽기
            val fileContent = file.readText()
            if (fileContent.isBlank()) {
                Log.d(TAG, "No content to upload")
                return true
            }
            
            // 기존 파일이 있는지 확인 (가볍게 SHA만 확인)
            val existingSha = getFileSha(filePath)
            
            if (existingSha != null) {
                // 기존 파일이 있음
                if (isNewDay || lastUploadTimestamp == 0L) {
                    // 새로운 날짜거나 첫 업로드면 파일을 덮어쓰기
                    Log.d(TAG, "Overwriting existing file for new day or first upload")
                    return updateFile(filePath, fileContent, existingSha, shopCode)
                } else {
                    // 기존 파일에 append
                    return appendToFile(filePath, fileContent, existingSha, shopCode)
                }
            } else {
                // 새 파일 생성
                Log.d(TAG, "Creating new file")
                return createFile(filePath, fileContent, shopCode)
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
    
    private fun appendToFile(filePath: String, newContent: String, sha: String, shopCode: String): Boolean {
        try {
            // 기존 파일 내용 가져오기
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$filePath"
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            
            val responseCode = connection.responseCode
            if (responseCode != 200) {
                Log.e(TAG, "Failed to get existing file content")
                return false
            }
            
            val response = connection.inputStream.bufferedReader().readText()
            val responseJson = JSONObject(response)
            val encodedContent = responseJson.getString("content")
            
            // Base64 디코딩
            val existingContent = String(Base64.decode(encodedContent, Base64.DEFAULT))
            
            // 기존 로그와 새 로그 병합 (텍스트 형식)
            val mergedContent = existingContent.trimEnd() + "\n" + newContent
            
            // 업데이트
            return updateFile(filePath, mergedContent, sha, shopCode)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error appending to file", e)
            return false
        }
    }
    
    private fun createFile(filePath: String, content: String, shopCode: String): Boolean {
        try {
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$filePath"
            val encodedContent = Base64.encodeToString(content.toByteArray(), Base64.NO_WRAP)
            
            val requestData = JSONObject().apply {
                put("message", "Create log file for shop $shopCode")
                put("content", encodedContent)
            }
            
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "PUT"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            connection.doOutput = true
            
            connection.outputStream.use { outputStream ->
                val input = requestData.toString().toByteArray(Charsets.UTF_8)
                outputStream.write(input, 0, input.size)
            }
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Create file response code: $responseCode")
            
            if (responseCode == 201) {
                Log.d(TAG, "✅ Successfully created new file")
                return true
            } else {
                val errorResponse = connection.errorStream?.bufferedReader()?.readText() ?: "No error details"
                Log.e(TAG, "❌ Failed to create file: $errorResponse")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating file", e)
            return false
        }
    }
    
    private fun updateFile(filePath: String, content: String, sha: String, shopCode: String): Boolean {
        try {
            val apiUrl = "$GITHUB_API_BASE/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$filePath"
            val encodedContent = Base64.encodeToString(content.toByteArray(), Base64.NO_WRAP)
            
            val requestData = JSONObject().apply {
                put("message", "Update log file for shop $shopCode")
                put("content", encodedContent)
                put("sha", sha)
            }
            
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "PUT"
            connection.setRequestProperty("Authorization", "token $GITHUB_TOKEN")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "SnapPay-Logger/1.0")
            connection.doOutput = true
            
            connection.outputStream.use { outputStream ->
                val input = requestData.toString().toByteArray(Charsets.UTF_8)
                outputStream.write(input, 0, input.size)
            }
            
            val responseCode = connection.responseCode
            return responseCode == 200
        } catch (e: Exception) {
            Log.e(TAG, "Error updating file", e)
            return false
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