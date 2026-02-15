# Mobile (Flutter)

The Flutter project is initialized in the `mobile` directory.

## Setup
```bash
cd /Users/admin/Desktop/run-with-codeX/mobile
flutter pub get
```

## Run
```bash
flutter run
```

## Build APK
### 1) Debug APK (quick testing)
```bash
flutter build apk --debug
```
Output:
`build/app/outputs/flutter-apk/app-debug.apk`

### 2) Release APK (QA / internal distribution)
```bash
flutter build apk --release
```
Output:
`build/app/outputs/flutter-apk/app-release.apk`

### 3) Split by ABI (smaller per-architecture artifacts)
```bash
flutter build apk --release --split-per-abi
```
Output:
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Integration goals
- Reuse the same backend APIs:
  - Auth: login/register/refresh/profile
  - Products
  - Orders
  - Livestream room APIs
- Use Socket.IO namespace `/livestream` for chat and signaling.

# product-v1-mobile
