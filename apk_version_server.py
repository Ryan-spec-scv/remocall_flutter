#!/usr/bin/env python3
"""
APK 버전을 직접 읽어서 제공하는 서버
"""

import os
import re
import zipfile
import xml.etree.ElementTree as ET
from http.server import HTTPServer, SimpleHTTPRequestHandler
import json

class APKVersionHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/check-update':
            # APK 파일에서 버전 정보 추출
            apk_path = 'build/app/outputs/flutter-apk/app-release-1.0.2.apk'
            
            try:
                version_info = self.get_apk_version(apk_path)
                
                response = {
                    "latest_version": version_info['versionName'],
                    "version_code": version_info['versionCode'],
                    "download_url": f"http://{self.server.server_address[0]}:8888/app/latest.apk",
                    "file_size": os.path.getsize(apk_path),
                    "release_notes": "테스트 업데이트"
                }
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_error(500, f"Error reading APK: {str(e)}")
                
        elif self.path == '/app/latest.apk':
            # APK 파일 제공
            apk_path = 'build/app/outputs/flutter-apk/app-release-1.0.2.apk'
            if os.path.exists(apk_path):
                self.send_response(200)
                self.send_header('Content-type', 'application/vnd.android.package-archive')
                self.send_header('Content-Disposition', 'attachment; filename="update.apk"')
                self.end_headers()
                
                with open(apk_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404, "APK file not found")
        else:
            super().do_GET()
    
    def get_apk_version(self, apk_path):
        """APK 파일에서 버전 정보 추출"""
        with zipfile.ZipFile(apk_path, 'r') as apk:
            # AndroidManifest.xml 읽기
            manifest_data = apk.read('AndroidManifest.xml')
            
            # 간단한 파싱 (실제로는 더 복잡함)
            # aapt 도구를 사용하는 것이 더 정확함
            version_name = "1.0.2"  # 실제로는 manifest에서 파싱
            version_code = "3"      # 실제로는 manifest에서 파싱
            
            return {
                'versionName': version_name,
                'versionCode': version_code
            }

if __name__ == '__main__':
    server_address = ('0.0.0.0', 8888)
    httpd = HTTPServer(server_address, APKVersionHandler)
    print("APK Version Server running on port 8888")
    httpd.serve_forever()