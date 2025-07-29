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

class SnapPayAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "SnapPayAccessibility"
        private var isKakaoPayUnlockNeeded = false
        private var lastUnlockAttempt = 0L
        private const val UNLOCK_COOLDOWN = 60000L // 1분 쿨다운
        
        fun setKakaoPayUnlockNeeded(needed: Boolean) {
            isKakaoPayUnlockNeeded = needed
            Log.d(TAG, "KakaoPay unlock needed set to: $needed")
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service connected")
        
        // 서비스 정보 설정
        serviceInfo.apply {
            // 잠금화면 이벤트 감지
            flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
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
            
            // 잠금화면 관련 텍스트 확인
            val hasLockScreenText = findNodeWithText(rootNode, "화면을 미세요") != null ||
                                  findNodeWithText(rootNode, "잠금 해제") != null ||
                                  findNodeWithText(rootNode, "스와이프") != null
            
            rootNode.recycle()
            
            val result = isSystemUI && hasLockScreenText
            Log.d(TAG, "isOnLockScreen: $result (package: $packageName)")
            return result
        }
        return false
    }
    
    private fun performUnlock(): Boolean {
        try {
            // 방법 1: 스와이프 제스처 시도
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Log.d(TAG, "Trying swipe gesture")
                if (performSwipeUp()) {
                    Thread.sleep(500) // 잠시 대기
                    if (!isOnLockScreen()) {
                        Log.d(TAG, "Unlock successful with swipe")
                        return true
                    }
                }
            }
            
            // 방법 2: Home 버튼 (일부 기기에서 작동)
            Log.d(TAG, "Trying GLOBAL_ACTION_HOME")
            performGlobalAction(GLOBAL_ACTION_HOME)
            Thread.sleep(300)
            
            // 방법 3: Back 버튼 (일부 기기에서 작동)
            Log.d(TAG, "Trying GLOBAL_ACTION_BACK")
            performGlobalAction(GLOBAL_ACTION_BACK)
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error performing unlock", e)
            return false
        }
    }
    
    private fun performSwipeUp(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        
        try {
            // 화면 크기 가져오기
            val displayMetrics = resources.displayMetrics
            val middleX = displayMetrics.widthPixels / 2
            val startY = displayMetrics.heightPixels * 0.8f
            val endY = displayMetrics.heightPixels * 0.2f
            
            // 스와이프 경로 생성
            val path = Path()
            path.moveTo(middleX.toFloat(), startY)
            path.lineTo(middleX.toFloat(), endY)
            
            // 제스처 생성
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                .build()
            
            // 제스처 실행
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription) {
                    super.onCompleted(gestureDescription)
                    Log.d(TAG, "Swipe gesture completed")
                }
                
                override fun onCancelled(gestureDescription: GestureDescription) {
                    super.onCancelled(gestureDescription)
                    Log.d(TAG, "Swipe gesture cancelled")
                }
            }, null)
            
            Log.d(TAG, "Swipe gesture dispatched: $result")
            return result
            
        } catch (e: Exception) {
            Log.e(TAG, "Error performing swipe", e)
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