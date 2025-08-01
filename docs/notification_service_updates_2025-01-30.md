# NotificationService 안정성 강화 업데이트 (2025-01-30)

## 변경 내용 요약

NotificationService에 크래시 복구 및 서비스 안정성 강화 기능을 추가했습니다.

## 주요 기능 추가

### 1. 재시작 감지 로직
- 서비스가 재시작될 때 이전 종료 이유와 경과 시간을 기록
- `SharedPreferences`를 통해 서비스 상태 추적
- `SERVICE_LIFECYCLE` 로그에 `RESTARTED` 이벤트 기록

### 2. 종료 이유 기록
- `onDestroy()`에서 정상 종료 시 이유 저장
- 다양한 종료 시나리오 추적 가능 (정상 종료, 크래시, 시스템 종료 등)

### 3. 크래시 핸들러
- `UncaughtExceptionHandler` 구현으로 크래시 정보 캡처
- 크래시 메시지와 스택 트레이스 저장 (최대 5000자)
- `Exception`과 `Throwable` 타입 구분 처리

### 4. 이전 크래시 정보 업로드
- 서비스 재시작 시 이전 크래시 정보 확인
- `LogManager`를 통해 `CRASH_RECOVERY` 이벤트로 기록
- 크래시 후 복구 시간 추적

### 5. 처리 중이던 알림 복구
- 처리 중이던 알림 ID를 `processingNotifications` Set에 보관
- 개별 알림 정보를 `SharedPreferences`에 백업
- 크래시/재시작 시 24시간 이내 알림만 복구
- 복구된 알림은 재시도 횟수를 1 증가시켜 큐에 재추가

## 기술적 세부사항

### 데이터 저장 구조
```kotlin
// ServiceState SharedPreferences
- service_was_running: Boolean
- last_stop_reason: String (NORMAL, CRASH, UNKNOWN)
- last_stop_time: Long
- last_crash_message: String
- last_crash_stack: String
- last_crash_time: Long
- processing_notifications: JSONArray (처리 중인 알림 ID 목록)
- notification_{id}: String (개별 알림 JSON 데이터)
```

### 복구 프로세스
1. 서비스 시작 시 이전 실행 상태 확인
2. 크래시 정보가 있으면 로그에 기록
3. 처리 중이던 알림 목록 로드
4. 각 알림의 개별 데이터 복구
5. 24시간 이내 알림만 큐에 재추가
6. 복구 완료 후 임시 데이터 정리

## 로그 예시

### 재시작 감지
```
SERVICE_LIFECYCLE: RESTARTED - Previous stop: CRASH, 45s ago
```

### 크래시 복구
```
SERVICE_LIFECYCLE: CRASH_RECOVERY - Message: NullPointerException, Time: 120s ago
```

### 알림 복구
```
SERVICE_LIFECYCLE: NOTIFICATIONS_RECOVERED - Count: 3
```

## 영향 범위
- 서비스 안정성 대폭 향상
- 크래시 시에도 알림 데이터 보존
- 시스템 재시작 후에도 미처리 알림 복구 가능
- 디버깅을 위한 상세한 크래시 정보 제공

## 테스트 시나리오
1. 알림 처리 중 앱 강제 종료
2. 시스템 재부팅
3. 메모리 부족으로 인한 서비스 종료
4. 예외 발생으로 인한 크래시

모든 시나리오에서 처리 중이던 알림이 성공적으로 복구되어야 합니다.