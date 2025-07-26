package com.remocall.remocall_flutter

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import android.app.NotificationChannel
import android.app.PendingIntent
import androidx.core.app.NotificationCompat

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "com.remocall/notifications"
        private const val TEST_CHANNEL = "com.remocall.notification/test"
        private const val TAG = "MainActivity"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    }
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var testMethodChannel: MethodChannel
    private var notificationReceiver: BroadcastReceiver? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        testMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TEST_CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotificationPermission" -> {
                    // Check notification listener permission (NOT notification display permission)
                    val isEnabled = isNotificationListenerEnabled()
                    Log.d(TAG, "[MethodChannel] checkNotificationPermission result: $isEnabled")
                    result.success(isEnabled)
                }
                "requestNotificationPermission" -> {
                    requestNotificationAccess()
                    result.success(null)
                }
                "isServiceRunning" -> {
                    // Check if notification listener service is enabled
                    val isRunning = isNotificationListenerEnabled()
                    result.success(isRunning)
                }
                "onNotificationReceived" -> {
                    // 테스트 알림 처리
                    val data = call.arguments as? String
                    if (data != null) {
                        // Flutter로 다시 전송
                        runOnUiThread {
                            methodChannel.invokeMethod("onNotificationReceived", data)
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "sendTestWebhook" -> {
                    // 테스트용 알림 생성 (서버 전송은 NotificationService가 처리)
                    val message = call.argument<String>("message") ?: "테스트 메시지"
                    
                    // 로컬 알림만 생성
                    createTestNotification(message)
                    
                    // Flutter에 성공 응답 즉시 반환
                    result.success(mapOf(
                        "success" to true,
                        "message" to "테스트 알림이 생성되었습니다"
                    ))
                }
                "isKakaoPayNotificationEnabled" -> {
                    result.success(isKakaoPayNotificationEnabled())
                }
                "isBatteryOptimizationEnabled" -> {
                    result.success(isAppStandbyEnabled())
                }
                "getBatterySettings" -> {
                    result.success(getBatterySettings())
                }
                "openBatterySettings" -> {
                    openBatterySettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 테스트 채널 핸들러
        testMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendTestNotification" -> {
                    try {
                        val args = call.arguments as HashMap<*, *>
                        val notificationData = JSONObject().apply {
                            put("packageName", args["packageName"] as String)
                            put("sender", args["sender"] as String)
                            put("message", args["message"] as String)
                            put("timestamp", args["timestamp"] as Long)
                            put("parsedData", JSONObject(args["parsedData"] as HashMap<*, *>))
                        }
                        
                        Log.d(TAG, "Sending test notification: ${notificationData.toString()}")
                        
                        // Flutter로 알림 전송
                        runOnUiThread {
                            methodChannel.invokeMethod("onNotificationReceived", notificationData.toString())
                        }
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending test notification", e)
                        result.error("TEST_NOTIFICATION_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Request notification permission for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) 
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
        
        // Register broadcast receiver
        notificationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "BroadcastReceiver onReceive called")
                
                intent?.getStringExtra("data")?.let { data ->
                    Log.d(TAG, "Received notification data: $data")
                    
                    try {
                        // Send to Flutter directly
                        runOnUiThread {
                            Log.d(TAG, "Sending to Flutter via MethodChannel")
                            methodChannel.invokeMethod("onNotificationReceived", data)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing notification data", e)
                    }
                } ?: run {
                    Log.e(TAG, "No data in broadcast intent")
                }
            }
        }
        
        val filter = IntentFilter("com.remocall.NOTIFICATION_RECEIVED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
        
        // NotificationListenerService 권한 확인 및 서비스 시작 유도
        if (isNotificationServiceEnabled()) {
            Log.d(TAG, "Notification service is enabled")
            // 알림 접근 권한 재설정으로 서비스 재시작 유도
            tryRestartNotificationService()
        } else {
            Log.d(TAG, "Notification service is not enabled")
            // 권한 요청
            requestNotificationAccess()
        }
    }
    
    private fun tryRestartNotificationService() {
        try {
            // NotificationListenerService 재시작 유도
            val componentName = ComponentName(this, NotificationService::class.java)
            val pm = packageManager
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d(TAG, "Triggered NotificationService restart")
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting NotificationService", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        notificationReceiver?.let {
            unregisterReceiver(it)
        }
    }
    
    private fun isNotificationServiceEnabled(): Boolean {
        val componentName = ComponentName(this, NotificationService::class.java)
        val flatComponent = componentName.flattenToString()
        
        // Force re-read from settings
        contentResolver.notifyChange(Settings.Secure.getUriFor("enabled_notification_listeners"), null)
        
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        
        val isEnabled = if (!TextUtils.isEmpty(enabledListeners)) {
            // Check both flattened and short component name
            enabledListeners.contains(flatComponent) || 
            enabledListeners.contains(componentName.packageName + "/" + componentName.shortClassName)
        } else {
            false
        }
        
        Log.d(TAG, "isNotificationServiceEnabled: $isEnabled")
        Log.d(TAG, "Component name: $flatComponent")
        Log.d(TAG, "Enabled listeners: $enabledListeners")
        return isEnabled
    }
    
    private fun isNotificationListenerEnabled(): Boolean {
        // Check if notification listener permission is granted
        // This is different from notification display permission
        try {
            val componentName = ComponentName(this, NotificationService::class.java)
            val flatString = componentName.flattenToString()
            
            // Force fresh read from system settings
            val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            
            Log.d(TAG, "=== NOTIFICATION LISTENER CHECK ===")
            Log.d(TAG, "Looking for component: $flatString")
            Log.d(TAG, "Package name: $packageName")
            Log.d(TAG, "Service class: ${NotificationService::class.java.name}")
            Log.d(TAG, "Enabled listeners from Settings: $enabledListeners")
            
            if (enabledListeners.isNullOrEmpty()) {
                Log.d(TAG, "Result: No notification listeners enabled at all")
                return false
            }
            
            // Try multiple matching patterns
            val patterns = listOf(
                flatString,
                "$packageName/${NotificationService::class.java.name}",
                "$packageName/${NotificationService::class.java.simpleName}",
                "$packageName/.NotificationService"
            )
            
            var found = false
            for (pattern in patterns) {
                if (enabledListeners.contains(pattern)) {
                    Log.d(TAG, "Found match with pattern: $pattern")
                    found = true
                    break
                }
            }
            
            // Also check if any component starts with our package name
            if (!found) {
                val components = enabledListeners.split(":")
                for (component in components) {
                    if (component.trim().startsWith(packageName)) {
                        Log.d(TAG, "Found component starting with package name: ${component.trim()}")
                        found = true
                        break
                    }
                }
            }
            
            Log.d(TAG, "Result: Notification listener enabled = $found")
            Log.d(TAG, "=== END NOTIFICATION LISTENER CHECK ===")
            return found
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking notification listener", e)
            return false
        }
    }
    
    private fun getBatterySettings(): HashMap<String, Boolean> {
        val settings = HashMap<String, Boolean>()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                
                
                // 2. 절전 모드 활성화 여부 확인
                val isPowerSaveMode = powerManager.isPowerSaveMode()
                settings["powerSaveMode"] = isPowerSaveMode
                Log.d(TAG, "Power save mode enabled: $isPowerSaveMode")
                
                // 3. 백그라운드 제한 확인 (Android P 이상)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val isBackgroundRestricted = activityManager.isBackgroundRestricted()
                    settings["backgroundRestricted"] = isBackgroundRestricted
                    Log.d(TAG, "Background restricted: $isBackgroundRestricted")
                } else {
                    settings["backgroundRestricted"] = false
                }
                
                // 4. 사용하지 않는 앱을 절전 상태로 전환 (앱 대기 버킷)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
                    val appStandbyBucket = usageStatsManager.getAppStandbyBucket()
                    // ACTIVE(10), WORKING_SET(20), FREQUENT(30), RARE(40), RESTRICTED(45)
                    val isNotInStandby = appStandbyBucket <= android.app.usage.UsageStatsManager.STANDBY_BUCKET_FREQUENT
                    settings["appStandbyDisabled"] = isNotInStandby
                    Log.d(TAG, "App standby bucket: $appStandbyBucket, not in standby: $isNotInStandby")
                } else {
                    settings["appStandbyDisabled"] = true
                }
                
                // 5. 미사용 앱 자동으로 사용 해제 - Android에서 직접 확인 불가
                settings["unusedAppDisabled"] = true // 기본값
                
                Log.d(TAG, "Battery settings: $settings")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery settings", e)
        }
        
        return settings
    }
    
    private fun requestNotificationAccess() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }
    
    private fun openBatterySettings() {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                intent.action = Settings.ACTION_BATTERY_SAVER_SETTINGS
            } else {
                intent.action = Settings.ACTION_SETTINGS
            }
            startActivity(intent)
        } catch (e: Exception) {
            // 배터리 설정이 없으면 일반 설정으로
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }
    
    private fun isKakaoPayNotificationEnabled(): Boolean {
        // For now, return true as checking other app's notification status is restricted
        // This would require special permissions or root access
        return try {
            // Check if KakaoTalk is installed
            val pm = packageManager
            val appInfo = pm.getApplicationInfo("com.kakao.talk", 0)
            true // If app is installed, assume notifications are enabled
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "KakaoTalk not installed", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking KakaoTalk status", e)
            false
        }
    }
    
    private fun isAppStandbyEnabled(): Boolean {
        // '사용하지 않는 앱을 절전 상태로 전환' 메뉴의 '사용 안 함' 토글 상태 확인
        // true = 절전 모드 활성화 (앱이 절전 상태로 전환될 수 있음)
        // false = 절전 모드 비활성화 (앱이 계속 활성 상태)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                // 배터리 최적화 화이트리스트에 있으면 true
                val isIgnoringBatteryOptimizations = powerManager.isIgnoringBatteryOptimizations(packageName)
                
                Log.d(TAG, "isIgnoringBatteryOptimizations (whitelist): $isIgnoringBatteryOptimizations")
                
                // 화이트리스트에 없으면(false) 절전 모드가 활성화된 것(true)
                val isPowerSavingEnabled = !isIgnoringBatteryOptimizations
                Log.d(TAG, "절전 모드 활성화 상태: $isPowerSavingEnabled")
                
                return isPowerSavingEnabled
            } else {
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery optimization status", e)
            return false
        }
    }
    
    private fun createTestNotification(message: String) {
        try {
            // 알림 채널 생성 (Android O 이상)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channelId = "snappay_test_notifications"
                val channelName = "SnapPay 테스트 알림"
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel(channelId, channelName, importance).apply {
                    description = "테스트 알림을 표시합니다"
                    enableLights(true)
                    enableVibration(true)
                }
                
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
            
            // 알림 생성
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, "snappay_test_notifications")
                .setContentTitle("SnapPay")
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setContentIntent(pendingIntent)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .build()
            
            val notificationManager = NotificationManagerCompat.from(this)
            // 알림 ID는 현재 시간 기반으로 생성하여 중복 방지
            val notificationId = System.currentTimeMillis().toInt()
            
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                notificationManager.notify(notificationId, notification)
                Log.d(TAG, "Test notification created: $message")
            } else {
                Log.w(TAG, "POST_NOTIFICATIONS permission not granted")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating test notification", e)
        }
    }
    
    private fun sendTestNotificationToServer(message: String, result: MethodChannel.Result) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "=== SEND TEST WEBHOOK START ===")
                
                // SharedPreferences에서 액세스 토큰 가져오기
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val accessToken = prefs.getString("flutter.access_token", null)
                
                Log.d(TAG, "Access token exists: ${accessToken != null}")
                
                if (accessToken == null) {
                    Log.w(TAG, "No access token found, cannot send test notification")
                    result.success(mapOf(
                        "success" to false,
                        "message" to "인증 토큰이 필요합니다"
                    ))
                    return@launch
                }
                
                // 공통 함수 사용 (KST 타임스탬프 자동 적용)
                NotificationService.sendNotificationToServer(
                    context = this@MainActivity,
                    message = message,
                    accessToken = accessToken,
                    onResult = { success, responseMessage ->
                        // 파싱된 응답으로 Flutter에 결과 전달
                        result.success(mapOf(
                            "success" to success,
                            "message" to responseMessage,
                            "matchStatus" to when {
                                responseMessage.contains("매칭되어 거래가 완료") -> "matched"
                                responseMessage.contains("새 거래를 자동으로 생성") -> "auto_created"
                                responseMessage.contains("이미 처리된") -> "duplicate"
                                responseMessage.contains("실패") -> "failed"
                                else -> "unknown"
                            }
                        ))
                    }
                )
                
                Log.d(TAG, "=== SEND TEST WEBHOOK END ===")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending test webhook: ${e.message}", e)
                e.printStackTrace()
                result.success(mapOf(
                    "success" to false,
                    "message" to "전송 오류: ${e.message}"
                ))
            }
        }
    }
}
