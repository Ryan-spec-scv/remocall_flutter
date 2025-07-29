# Google Drive 서비스 계정 키 파일 위치

이 폴더에 Google Cloud Console에서 다운로드한 서비스 계정 JSON 키 파일을 넣어주세요.

## 파일명
`google_drive_service_account.json`

## 파일 위치
`/android/app/src/main/assets/google_drive_service_account.json`

## 주의사항
- 이 파일은 Git에 커밋하지 마세요
- .gitignore에 추가하는 것을 권장합니다
- 보안을 위해 이 파일을 안전하게 관리하세요

## 파일 형식 예시
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "service-account-email@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```