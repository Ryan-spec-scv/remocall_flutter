# 서비스 안정성 개선 사항 (2025-07-29)

## 목표
- 카카오톡/카카오페이 알림을 100% 수신 보장
- 앱 오류 시 즉시 자동 재시작
- 배터리 효율보다 안정성 우선

## 주요 변경 사항

### 1. NotificationServiceWatchdog.kt 수정
**파일**: `android/app/src/main/kotlin/com/remocall/remocall_flutter/NotificationServiceWatchdog.kt`
- **변경 라인**: 20번째 줄
- **변경 내용**: 체크 간격 30초 → 10초로 단축
```kotlin
// Before
private const val CHECK_INTERVAL = 30 * 1000L // 30초마다 확인

// After  
private const val CHECK_INTERVAL = 10 * 1000L // 10초마다 확인 (배터리 걱정 없이 최대 안정성)
```

### 2. NotificationService.kt WakeLock 강화
**파일**: `android/app/src/main/kotlin/com/remocall/remocall_flutter/NotificationService.kt`

#### 2-1. 영구 WakeLock 설정 (328-340줄)
```kotlin
// Before
acquire(10 * 60 * 1000L) // 10분간 유지

// After
acquire() // 영구적으로 유지 (timeout 없음)
```

#### 2-2. WakeLock 갱신 로직 개선 (838-859줄)
- `@Synchronized` 추가로 Thread-safe 보장
- 불필요한 release/acquire 제거
- WakeLock 상태 체크 후 필요시에만 재획득

#### 2-3. Thread-Safe 중복 알림 방지 (279줄)
```kotlin
// Before
private val recentNotifications = mutableSetOf<String>()

// After
private val recentNotifications = ConcurrentHashMap.newKeySet<String>() // Thread-safe 중복 방지
```

#### 2-4. Import 추가 (25줄)
```kotlin
import java.util.concurrent.ConcurrentHashMap
```

#### 2-5. onDestroy 즉시 재시작 (1134줄)
```kotlin
// Before
android.os.SystemClock.elapsedRealtime() + 1000, // 1초 후

// After
android.os.SystemClock.elapsedRealtime() + 500, // 0.5초 후 즉시 재시작 (배터리 걱정 없음)
```

## 기대 효과
- **10초 이내 장애 감지**: JobScheduler가 10초마다 서비스 상태 확인
- **0.5초 내 자동 복구**: 서비스 종료 시 즉시 재시작
- **무중단 알림 수신**: 영구 WakeLock으로 시스템 절전 모드에서도 동작
- **동시성 안정성**: Thread-safe 처리로 크래시 방지

## 주의사항
- 배터리 소모가 증가할 수 있음 (배터리 효율보다 안정성 우선)
- 사용자에게 배터리 최적화 예외 설정을 안내하는 것을 권장