#!/bin/bash

# SnapPay 실시간 모니터링 스크립트

echo "📱 SnapPay 모니터링 도구"
echo "========================"
echo ""
echo "사용 가능한 모니터링 옵션:"
echo "1. 실시간 로그 (Logcat)"
echo "2. 메모리 사용량"
echo "3. CPU 사용률"
echo "4. 화면 미러링 (scrcpy)"
echo "5. 종합 모니터링 (모든 창 열기)"
echo ""
echo -n "옵션을 선택하세요 (1-5): "
read option

case $option in
    1)
        echo "📋 실시간 로그 모니터링 시작..."
        echo "zsh 사용자는 따옴표를 사용해야 합니다:"
        echo ""
        echo "adb logcat -s 'NotificationService:*' 'LogManager:*' 'ApiService:*' 'NotificationQueueService:*'"
        echo ""
        echo "또는 grep 사용:"
        echo "adb logcat | grep -E 'NotificationService|LogManager|ApiService|NotificationQueueService'"
        echo ""
        echo "로그 모니터링을 시작합니다..."
        adb logcat | grep -E 'NotificationService|LogManager|ApiService|NotificationQueueService'
        ;;
    2)
        echo "💾 메모리 모니터링 시작..."
        while true; do
            clear
            echo "=== SnapPay 메모리 사용량 ==="
            echo "시간: $(date)"
            echo ""
            adb shell dumpsys meminfo com.remocall.remocall_flutter | grep -E "TOTAL|Native Heap|Dalvik Heap|TOTAL PSS"
            echo ""
            echo "시스템 메모리:"
            adb shell cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable"
            sleep 5
        done
        ;;
    3)
        echo "⚡ CPU 모니터링 시작..."
        adb shell top -d 2 | grep -E "com.remocall|CPU"
        ;;
    4)
        echo "🖥️ 화면 미러링 시작..."
        if command -v scrcpy &> /dev/null; then
            scrcpy --always-on-top --max-size 800
        else
            echo "❌ scrcpy가 설치되어 있지 않습니다."
            echo "설치: brew install scrcpy"
        fi
        ;;
    5)
        echo "🚀 종합 모니터링 시작..."
        
        # Terminal 1: Logcat
        osascript -e 'tell app "Terminal" to do script "adb logcat -s NotificationService:* LogManager:* ApiService:*"'
        
        # Terminal 2: 메모리 모니터링
        osascript -e 'tell app "Terminal" to do script "while true; do clear; echo \"=== SnapPay 메모리 사용량 ===\"; date; adb shell dumpsys meminfo com.remocall.remocall_flutter | grep -E \"TOTAL|Native Heap|Dalvik Heap\"; sleep 5; done"'
        
        # Terminal 3: CPU 모니터링
        osascript -e 'tell app "Terminal" to do script "adb shell top -d 2 | grep remocall"'
        
        # Terminal 4: 화면 미러링 (scrcpy가 설치된 경우)
        if command -v scrcpy &> /dev/null; then
            osascript -e 'tell app "Terminal" to do script "scrcpy --always-on-top --max-size 800"'
        fi
        
        echo "✅ 모든 모니터링 창이 열렸습니다."
        ;;
    *)
        echo "❌ 잘못된 옵션입니다."
        ;;
esac