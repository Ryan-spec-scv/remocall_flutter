# 알림 전송 큐 시스템 구현 (2025-07-29)

## 목표
- 알림을 순서대로 큐에 저장하고 순차적으로 서버 전송
- 전송 실패 시 큐의 끝으로 이동하여 재시도
- 알림 순서 보장 및 100% 전송 보장

## 주요 변경 사항

### 1. NotificationService.kt Import 추가
**파일**: `android/app/src/main/kotlin/com/remocall/remocall_flutter/NotificationService.kt`
- **변경 라인**: 26-28번째 줄
```kotlin
import java.util.concurrent.ConcurrentLinkedQueue
import kotlinx.coroutines.delay
```

### 2. 큐 시스템 변수 추가 (281-288줄)
```kotlin
// 알림 전송 큐 - 순서 보장을 위한 Thread-safe 큐
private val notificationQueue = ConcurrentLinkedQueue<FailedNotification>()
private var isProcessingQueue = false
```

### 3. onNotificationPosted 수정 (583-585줄)
```kotlin
// Before
sendToFlutter(title, bigText, null, sbn.packageName)

// After  
// 알림을 큐에 추가 (즉시 전송하지 않음)
Log.d(TAG, "Adding notification to queue for ${sbn.packageName}")
addToQueue(title, bigText, sbn.packageName)
```

### 4. 새로운 메서드 추가 (846-1011줄)

#### 4-1. addToQueue 메서드
- 알림을 큐에 추가
- SharedPreferences에도 저장 (앱 재시작 대응)
- 큐 처리가 중지되어 있으면 재시작

#### 4-2. startQueueProcessing 메서드
- 큐 처리 프로세스 시작
- 중복 실행 방지

#### 4-3. processQueue 메서드
- 큐의 첫 번째 항목을 전송 시도
- 성공: 큐에서 제거
- 실패: 큐 끝으로 이동
- 재시도 대기 시간 적용

#### 4-4. getRetryDelay 메서드
```kotlin
private fun getRetryDelay(retryCount: Int): Long {
    return when (retryCount) {
        0 -> 0L
        1 -> 5000L  // 5초
        2 -> 10000L // 10초
        else -> 30000L // 30초
    }
}
```

#### 4-5. sendNotificationToServer 메서드
- 실제 서버 전송 로직 래퍼

#### 4-6. sendNotificationDirect 메서드
- HTTP 직접 전송
- 입금 알림이 아니면 성공 처리하여 큐에서 제거

### 5. 큐 복구 로직 추가 (359-363줄)
```kotlin
// 큐 처리 시작
startQueueProcessing()

// 앱 재시작 시 기존 큐 복구
loadQueueFromPreferences()
```

### 6. loadQueueFromPreferences 메서드 추가 (968-986줄)
- SharedPreferences에서 실패한 알림 로드
- 메모리 큐로 복구
- 큐 처리 재시작

### 7. 기존 sendToServer 수정 (771-775줄)
```kotlin
// 기존 sendToServer - 큐 시스템으로 대체됨 (호환성을 위해 유지)
private fun sendToServer(message: String, parsedData: Map<String, String>) {
    // 큐에 추가하도록 변경
    addToQueue("", message, SNAPPAY_PACKAGE)
}
```

### 8. sendToFlutter 내 서버 전송 제거 (725줄)
```kotlin
// Before
sendToServer(message, parsedData ?: emptyMap())

// After
// 서버로 전송하지 않음 - 큐에서 처리됨
```

## 아키텍처 변경

### 이전 방식
```
알림 수신 → 즉시 서버 전송 → 실패 시 별도 큐 저장
```

### 새로운 방식
```
알림 수신 → 큐에 추가 → 순서대로 처리 → 실패 시 큐 끝으로 이동
```

## 기대 효과
- **순서 보장**: FIFO 방식으로 알림 순서 유지
- **100% 전송**: 성공할 때까지 무한 재시도
- **단순한 로직**: 복잡한 실패 처리 대신 단순 재배치
- **앱 재시작 대응**: SharedPreferences로 큐 상태 영속화

## 주의사항
- 큐가 계속 쌓이면 메모리 사용량 증가 가능
- 네트워크 오류 시 큐가 계속 순환할 수 있음
- 입금 알림이 아닌 경우 자동으로 성공 처리하여 큐에서 제거