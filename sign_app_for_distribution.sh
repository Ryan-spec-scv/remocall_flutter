#!/bin/bash

echo "🔐 Signing SnapPay for distribution..."
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. 사용 가능한 서명 인증서 확인
echo -e "${YELLOW}Available signing identities:${NC}"
security find-identity -v -p codesigning

echo ""
echo -e "${YELLOW}Instructions for distributing the app:${NC}"
echo ""
echo -e "${GREEN}Option 1: For users without Apple Developer Account${NC}"
echo "1. Share the DMG file with users"
echo "2. Users need to:"
echo "   - Right-click the app and select 'Open' (first time only)"
echo "   - Or go to System Settings > Privacy & Security"
echo "   - Click 'Open Anyway' next to the security warning"
echo ""
echo -e "${GREEN}Option 2: With Apple Developer Account (Recommended)${NC}"
echo "1. Sign up for Apple Developer Program ($99/year)"
echo "2. Create a Developer ID Application certificate"
echo "3. Run this command to sign:"
echo "   codesign --deep --force --verify --verbose --sign \"Developer ID Application: Your Name\" SnapPay.app"
echo "4. Notarize the app:"
echo "   xcrun notarytool submit SnapPay.dmg --apple-id your@email.com --team-id TEAMID --wait"
echo ""
echo -e "${GREEN}Option 3: Ad-hoc distribution (Current method)${NC}"
echo "The app is currently signed with an ad-hoc signature."
echo "Users can still run it by allowing it in Security settings."
echo ""

# 임시로 Gatekeeper 무시하고 실행하는 방법
echo -e "${YELLOW}Quick fix for testing:${NC}"
echo "Users can run this command in Terminal to bypass Gatekeeper:"
echo -e "${GREEN}xattr -cr /Applications/SnapPay.app${NC}"
echo ""
echo "Or right-click the app and select 'Open' while holding the Option key."