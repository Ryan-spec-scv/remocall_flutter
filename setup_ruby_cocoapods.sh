#!/bin/bash

echo "🔧 Setting up Ruby and CocoaPods for macOS development..."
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Homebrew로 Ruby 설치
echo -e "${YELLOW}1. Installing Ruby via Homebrew...${NC}"
brew install ruby

# 2. Ruby 경로 설정
echo -e "${YELLOW}2. Setting up Ruby PATH...${NC}"
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# 3. 현재 Ruby 버전 확인
echo -e "${YELLOW}3. Checking Ruby version...${NC}"
/opt/homebrew/opt/ruby/bin/ruby --version

# 4. gem 업데이트
echo -e "${YELLOW}4. Updating RubyGems...${NC}"
/opt/homebrew/opt/ruby/bin/gem update --system

# 5. CocoaPods 설치
echo -e "${YELLOW}5. Installing CocoaPods...${NC}"
/opt/homebrew/opt/ruby/bin/gem install cocoapods

# 6. CocoaPods 설정
echo -e "${YELLOW}6. Setting up CocoaPods...${NC}"
export PATH="$HOME/.gem/ruby/3.3.0/bin:$PATH"
echo 'export PATH="$HOME/.gem/ruby/3.3.0/bin:$PATH"' >> ~/.zshrc

# 7. 설치 확인
if /opt/homebrew/opt/ruby/bin/gem list cocoapods -i; then
    echo -e "${GREEN}✅ CocoaPods installed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Important: Please run the following command to reload your shell:${NC}"
    echo -e "${GREEN}source ~/.zshrc${NC}"
    echo ""
    echo -e "${YELLOW}Then you can run:${NC}"
    echo -e "${GREEN}./build_macos.sh${NC}"
else
    echo -e "${RED}❌ CocoaPods installation failed!${NC}"
    exit 1
fi