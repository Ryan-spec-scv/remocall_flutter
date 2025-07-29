#!/bin/bash

echo "📦 Preparing SnapPay.app for sharing..."
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. ZIP 파일로 압축 (검역 속성 제거 옵션)
echo -e "${YELLOW}Creating ZIP file without quarantine attributes...${NC}"
cd build/macos/Build/Products/Release/
zip -r SnapPay-macOS.zip SnapPay.app
mv SnapPay-macOS.zip ../../../../../
cd ../../../../../

echo -e "${GREEN}✅ Created: SnapPay-macOS.zip${NC}"
echo ""

# 2. 사용자에게 전달할 방법들
echo -e "${YELLOW}방법 1: USB나 로컬 네트워크로 전달${NC}"
echo "- USB 드라이브나 로컬 네트워크(SMB)로 전달하면 Gatekeeper 검사를 받지 않습니다"
echo ""

echo -e "${YELLOW}방법 2: 압축 파일 전달 후 터미널 명령어${NC}"
echo "받는 사람이 다음 명령어를 실행:"
echo -e "${GREEN}# 압축 해제${NC}"
echo "unzip SnapPay-macOS.zip"
echo -e "${GREEN}# 검역 속성 제거${NC}"
echo "xattr -cr SnapPay.app"
echo -e "${GREEN}# Applications 폴더로 이동${NC}"
echo "mv SnapPay.app /Applications/"
echo ""

echo -e "${YELLOW}방법 3: 개발자 모드 활성화 (받는 사람)${NC}"
echo "1. 터미널에서 실행:"
echo "   sudo spctl --master-disable"
echo "2. 시스템 설정 > 개인정보 및 보안 > 보안"
echo "3. '다음에서 다운로드한 앱 허용' > '모든 곳' 선택"
echo ""

echo -e "${YELLOW}방법 4: 앱 번들 직접 실행${NC}"
echo "터미널에서:"
echo "open SnapPay.app --args"
echo ""

# 3. 테스트용 스크립트 생성
cat > run_snappay.sh << 'EOF'
#!/bin/bash
# SnapPay 실행 스크립트

# 검역 속성 제거
xattr -cr SnapPay.app 2>/dev/null

# 앱 실행
open SnapPay.app
EOF

chmod +x run_snappay.sh

echo -e "${GREEN}✅ Created: run_snappay.sh${NC}"
echo "이 스크립트를 앱과 함께 전달하면 더 쉽게 실행할 수 있습니다."
echo ""

echo -e "${YELLOW}현재 생성된 파일들:${NC}"
ls -la SnapPay-macOS.zip run_snappay.sh