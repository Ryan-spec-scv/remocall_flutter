#!/bin/bash

echo "🔧 Fixing CocoaPods PATH..."

# CocoaPods 경로 추가
echo 'export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"' >> ~/.zshrc

# 즉시 적용
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# 확인
echo "✅ CocoaPods path added to ~/.zshrc"
echo ""
echo "CocoaPods version:"
/opt/homebrew/lib/ruby/gems/3.4.0/bin/pod --version
echo ""
echo "Now run:"
echo "source ~/.zshrc"
echo "./build_macos.sh"