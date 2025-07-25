#!/usr/bin/env python3
"""
APK에서 릴리즈 노트 추출
"""

import zipfile
import json
import sys
import re
import os
import hashlib
from datetime import datetime

def extract_from_apk(apk_path):
    """APK에서 릴리즈 정보 추출"""
    release_info = {}
    
    with zipfile.ZipFile(apk_path, 'r') as apk:
        # 1. assets/flutter_assets/CHANGELOG.md 읽기
        try:
            # Flutter 앱의 경우 assets는 이 경로에 있음
            changelog_path = 'assets/flutter_assets/assets/CHANGELOG.md'
            changelog = apk.read(changelog_path).decode('utf-8')
            release_info['changelog'] = parse_changelog(changelog)
            release_info['full_changelog'] = changelog
            print(f"✓ CHANGELOG.md found and extracted")
        except KeyError:
            print(f"✗ CHANGELOG.md not found in APK")
            # APK 내부 파일 목록 출력 (디버깅용)
            print("\nFiles in APK:")
            for file in apk.namelist():
                if 'CHANGELOG' in file or 'changelog' in file:
                    print(f"  - {file}")
        
        # 2. aapt로 버전 정보 추출
        try:
            import subprocess
            aapt_path = '/Users/gwang/Library/Android/sdk/build-tools/36.0.0/aapt'
            
            result = subprocess.run(
                [aapt_path, 'dump', 'badging', apk_path],
                capture_output=True,
                text=True
            )
            
            # 버전 정보 파싱
            version_match = re.search(r"versionName='([^']+)'", result.stdout)
            if version_match:
                release_info['version'] = version_match.group(1)
                
            code_match = re.search(r"versionCode='([^']+)'", result.stdout)
            if code_match:
                release_info['versionCode'] = code_match.group(1)
                
            # 패키지명
            package_match = re.search(r"package: name='([^']+)'", result.stdout)
            if package_match:
                release_info['packageName'] = package_match.group(1)
                
            print(f"✓ Version info extracted: {release_info.get('version', 'N/A')}")
        except Exception as e:
            print(f"✗ Could not extract version info: {e}")
    
    return release_info

def parse_changelog(changelog_text):
    """CHANGELOG.md 파싱"""
    # 가장 최신 버전의 변경사항만 추출
    lines = changelog_text.split('\n')
    current_version = None
    current_changes = []
    
    for line in lines:
        if line.startswith('## ['):
            if current_version:
                break
            version_match = re.match(r'## \[([^\]]+)\]', line)
            if version_match:
                current_version = version_match.group(1)
        elif current_version and line.strip().startswith('-'):
            current_changes.append(line.strip()[2:])
    
    return {
        'version': current_version,
        'changes': current_changes
    }

def generate_release_json(apk_path):
    """릴리즈 정보를 JSON으로 생성"""
    info = extract_from_apk(apk_path)
    
    # 추가 정보
    import os
    import hashlib
    from datetime import datetime
    
    # 파일 크기
    info['fileSize'] = os.path.getsize(apk_path)
    
    # MD5 해시
    with open(apk_path, 'rb') as f:
        info['md5'] = hashlib.md5(f.read()).hexdigest()
    
    # 타임스탬프
    info['uploadDate'] = datetime.now().isoformat()
    
    return info

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python extract_release_notes.py <apk_file>")
        sys.exit(1)
    
    apk_file = sys.argv[1]
    release_info = generate_release_json(apk_file)
    
    # JSON 파일로 저장
    output_file = apk_file.replace('.apk', '_release.json')
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(release_info, f, indent=2, ensure_ascii=False)
    
    print(f"Release info saved to: {output_file}")
    print(json.dumps(release_info, indent=2, ensure_ascii=False))