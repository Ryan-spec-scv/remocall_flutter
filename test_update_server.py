#!/usr/bin/env python3
"""
로컬 업데이트 테스트 서버
사용법: python3 test_update_server.py
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import json
import os

class UpdateHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/app/version':
            # 버전 정보 응답
            response = {
                "latest_version": "1.0.2",  # 현재 앱 버전보다 높게 설정
                "download_url": "https://ddae773977bf.ngrok-free.app/app/latest.apk",
                "release_notes": "테스트 업데이트\\n- 버그 수정\\n- 성능 개선"
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
            
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
                self.send_error(404, f"APK file not found at {apk_path}")
        else:
            super().do_GET()

if __name__ == '__main__':
    server_address = ('0.0.0.0', 8888)
    httpd = HTTPServer(server_address, UpdateHandler)
    
    # 로컬 IP 주소 확인
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print(f"Update test server running on http://{local_ip}:8888")
    print(f"Version endpoint: http://{local_ip}:8888/api/app/version")
    print(f"APK download: http://{local_ip}:8888/app/latest.apk")
    print("\nMake sure to update the IP address in update_service.dart")
    print("Press Ctrl+C to stop the server")
    
    httpd.serve_forever()