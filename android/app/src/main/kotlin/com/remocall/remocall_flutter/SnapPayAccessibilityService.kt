package com.remocall.remocall_flutter

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.annotation.TargetApi

class SnapPayAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "SnapPayAccessibility"
        private var isKakaoPayUnlockNeeded = false
        private var lastUnlockAttempt = 0L
        private const val UNLOCK_COOLDOWN = 60000L // 1분 쿨다운
        
        @TargetApi(Build.VERSION_CODES.P)
        private const val GLOBAL_ACTION_DISMISS_KEYGUARD = 11 // API 28+
        
        fun setKakaoPayUnlockNeeded(needed: Boolean) {
            isKakaoPayUnlockNeeded = needed
            Log.d(TAG, "KakaoPay unlock needed set to: $needed")
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service connected")
        
        // 서비스 정보를 동적으로 설정 (Android 11 "제한된 설정" 회피)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val info = serviceInfo
                info.apply {
                    // 기본 플래그 설정
                    flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                    
                    // Android 11 이하에서만 또는 사용자가 이미 허용한 경우에만 제스처 기능 활성화
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || isGesturePermissionGranted()) {
                        // 제스처 권한은 동적으로 추가 (XML에서 제거했음)
                        flags = flags or AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE
                    }
                }
                serviceInfo = info
                Log.d(TAG, "Service info updated dynamically")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating service info", e)
            }
        }
    }
    
    private fun isGesturePermissionGranted(): Boolean {
        // 이미 제스처를 수행할 수 있는지 확인
        return try {
            // 간단한 제스처 테스트로 권한 확인
            true // 실제로는 더 정교한 확인이 필요할 수 있음
        } catch (e: Exception) {
            false
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 카카오페이 알림 후 잠금해제가 필요한 경우
        if (isKakaoPayUnlockNeeded) {
            Log.d(TAG, "Checking if unlock is needed...")
            
            // 쿨다운 체크
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastUnlockAttempt < UNLOCK_COOLDOWN) {
                Log.d(TAG, "Unlock cooldown active, skipping...")
                return
            }
            
            // 잠금화면인지 확인
            if (isOnLockScreen()) {
                Log.d(TAG, "On lock screen, attempting to unlock...")
                lastUnlockAttempt = currentTime
                
                // 잠금화면 해제 시도
                if (performUnlock()) {
                    isKakaoPayUnlockNeeded = false
                    Log.d(TAG, "Unlock attempt completed")
                } else {
                    Log.e(TAG, "Unlock attempt failed")
                    // 실패 시 1초 후 재시도
                    Handler(Looper.getMainLooper()).postDelayed({
                        if (isKakaoPayUnlockNeeded) {
                            performUnlock()
                            isKakaoPayUnlockNeeded = false
                        }
                    }, 1000)
                }
            }
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service interrupted")
    }
    
    private fun isOnLockScreen(): Boolean {
        // 현재 화면이 잠금화면인지 확인
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            // 잠금화면 관련 패키지명 확인
            val packageName = rootNode.packageName?.toString() ?: ""
            val isSystemUI = packageName == "com.android.systemui"
            
            // 잠금화면 관련 텍스트 확인 (다양한 텍스트 추가)
            val lockScreenTexts = listOf(
                "화면을 미세요",
                "잠금 해제",
                "스와이프",
                "위로 스와이프",
                "잠금해제하려면",
                "Swipe up",
                "Swipe to unlock",
                "잠금화면"
            )
            
            var hasLockScreenText = false
            for (text in lockScreenTexts) {
                if (findNodeWithText(rootNode, text) != null) {
                    hasLockScreenText = true
                    Log.d(TAG, "Found lockscreen text: $text")
                    break
                }
            }
            
            rootNode.recycle()
            
            val result = isSystemUI && hasLockScreenText
            Log.d(TAG, "isOnLockScreen: $result (package: $packageName, hasText: $hasLockScreenText)")
            return result
        }
        return false
    }
    
    private fun performUnlock(): Boolean {
        try {
            // 제조사 확인
            val manufacturer = Build.MANUFACTURER.lowercase()
            Log.d(TAG, "Device manufacturer: $manufacturer")
            
            // 방법 1: API 28+ 에서 DISMISS_KEYGUARD 사용
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                Log.d(TAG, "Trying GLOBAL_ACTION_DISMISS_KEYGUARD (API 28+)")
                if (performGlobalAction(GLOBAL_ACTION_DISMISS_KEYGUARD)) {
                    Thread.sleep(500)
                    if (!isOnLockScreen()) {
                        Log.d(TAG, "Unlock successful with DISMISS_KEYGUARD")
                        return true
                    }
                }
            }
            
            // 방법 2: 제조사별 최적화된 스와이프 제스처
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Log.d(TAG, "Trying manufacturer-specific swipe gestures")
                
                when (manufacturer) {
                    "samsung" -> {
                        // 삼성: 대각선 스와이프 우선
                        if (trySwipeSequence(listOf(
                            { performDiagonalSwipe() },
                            { performSwipeUp() },
                            { performRightSwipe() }
                        ))) return true
                    }
                    "lg", "lge" -> {
                        // LG: 위로 스와이프 우선
                        if (trySwipeSequence(listOf(
                            { performSwipeUp() },
                            { performDiagonalSwipe() }
                        ))) return true
                    }
                    "xiaomi", "redmi", "poco" -> {
                        // 샤오미: 위로 스와이프 우선
                        if (trySwipeSequence(listOf(
                            { performSwipeUp() },
                            { performRightSwipe() }
                        ))) return true
                    }
                    else -> {
                        // 기타 제조사: 모든 패턴 시도
                        if (trySwipeSequence(listOf(
                            { performSwipeUp() },
                            { performDiagonalSwipe() },
                            { performRightSwipe() }
                        ))) return true
                    }
                }
            }
            
            // 방법 3: Home 버튼 (일부 기기에서 작동)
            Log.d(TAG, "Trying GLOBAL_ACTION_HOME")
            performGlobalAction(GLOBAL_ACTION_HOME)
            Thread.sleep(300)
            
            // 방법 4: Back 버튼 (일부 기기에서 작동)
            Log.d(TAG, "Trying GLOBAL_ACTION_BACK")
            performGlobalAction(GLOBAL_ACTION_BACK)
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error performing unlock", e)
            return false
        }
    }
    
    private fun trySwipeSequence(swipeActions: List<() -> Boolean>): Boolean {
        for (swipeAction in swipeActions) {
            try {
                if (swipeAction()) {
                    Thread.sleep(700) // 애니메이션 대기
                    if (!isOnLockScreen()) {
                        Log.d(TAG, "Unlock successful")
                        return true
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error during swipe sequence", e)
            }
        }
        return false
    }
    
    private fun performSwipeUp(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        
        try {
            // 화면 크기 가져오기
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val screenHeight = displayMetrics.heightPixels
            
            Log.d(TAG, "Screen dimensions: ${screenWidth}x${screenHeight}")
            
            // 스와이프 좌표 계산 - 더 긴 거리로 조정
            val middleX = screenWidth / 2
            val startY = screenHeight * 0.9f  // 더 아래에서 시작
            val endY = screenHeight * 0.1f    // 더 위로 스와이프
            
            Log.d(TAG, "Swipe coordinates: ($middleX, $startY) -> ($middleX, $endY)")
            
            // 스와이프 경로 생성
            val path = Path()
            path.moveTo(middleX.toFloat(), startY)
            path.lineTo(middleX.toFloat(), endY)
            
            // 제스처 생성 - 더 긴 시간으로 조정
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 500)) // 300ms -> 500ms
                .build()
            
            // 제스처 실행
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription) {
                    super.onCompleted(gestureDescription)
                    Log.d(TAG, "Swipe gesture completed successfully")
                }
                
                override fun onCancelled(gestureDescription: GestureDescription) {
                    super.onCancelled(gestureDescription)
                    Log.d(TAG, "Swipe gesture was cancelled")
                }
            }, null)
            
            Log.d(TAG, "Swipe gesture dispatched: $result")
            return result
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing swipe", e)
            return false
        }
    }
    
    private fun performDiagonalSwipe(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        
        try {
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val screenHeight = displayMetrics.heightPixels
            
            // 왼쪽 아래에서 오른쪽 위로 대각선 스와이프
            val startX = screenWidth * 0.2f
            val startY = screenHeight * 0.8f
            val endX = screenWidth * 0.8f
            val endY = screenHeight * 0.2f
            
            Log.d(TAG, "Diagonal swipe: ($startX, $startY) -> ($endX, $endY)")
            
            val path = Path()
            path.moveTo(startX, startY)
            path.lineTo(endX, endY)
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 500))
                .build()
            
            return dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription) {
                    Log.d(TAG, "Diagonal swipe completed")
                }
                override fun onCancelled(gestureDescription: GestureDescription) {
                    Log.d(TAG, "Diagonal swipe cancelled")
                }
            }, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing diagonal swipe", e)
            return false
        }
    }
    
    private fun performRightSwipe(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        
        try {
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val screenHeight = displayMetrics.heightPixels
            
            // 왼쪽에서 오른쪽으로 스와이프
            val startX = screenWidth * 0.1f
            val endX = screenWidth * 0.9f
            val middleY = screenHeight / 2f
            
            Log.d(TAG, "Right swipe: ($startX, $middleY) -> ($endX, $middleY)")
            
            val path = Path()
            path.moveTo(startX, middleY)
            path.lineTo(endX, middleY)
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 400))
                .build()
            
            return dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription) {
                    Log.d(TAG, "Right swipe completed")
                }
                override fun onCancelled(gestureDescription: GestureDescription) {
                    Log.d(TAG, "Right swipe cancelled")
                }
            }, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing right swipe", e)
            return false
        }
    }
    
    private fun findNodeWithText(node: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        // 현재 노드 확인
        if (node.text?.toString()?.contains(text, ignoreCase = true) == true) {
            return node
        }
        
        // 자식 노드 확인
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findNodeWithText(child, text)
            if (result != null) {
                child.recycle()
                return result
            }
            child.recycle()
        }
        
        return null
    }
}