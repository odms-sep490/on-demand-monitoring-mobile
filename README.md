# ODMS Mobile — Flutter / Dart

Ứng dụng Android và iOS cho **Customer và Staff**. Giao diện được thiết kế lại cho điện thoại, giữ nhận diện ODMS, font Be Vietnam Pro, nội dung và các luồng chính từ website. Không dùng WebView để bọc website.

## Chạy ứng dụng

Yêu cầu Flutter **3.51.0-0.2.pre**, JDK 21 cho Android, và Xcode đầy đủ cho iOS.

```sh
flutter pub get
cp config/development.example.json config/development.json
flutter run --dart-define-from-file=config/development.json
```

Chỉnh `API_BASE_URL` trong file cấu hình:

- Android emulator: `http://10.0.2.2:8080`.
- iOS simulator: `http://localhost:8080`.
- Điện thoại thật: URL backend mà điện thoại truy cập được, không dùng `localhost` của máy tính.
- Release: HTTPS. Các file cấu hình riêng, mật khẩu và khóa ký không được đưa vào Git.

Có thể nối Android qua ADB khi backend chạy trên máy phát triển. Ví dụ với backend thử nghiệm ở cổng 18080:

```sh
adb reverse tcp:18080 tcp:18080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

Kiểm thử tích hợp dùng **database cô lập** vì có tạo đơn và thêm, sửa, xóa lịch bận. Cấu hình `ODMS_SMOKE_BASE_URL` và `ODMS_SMOKE_PASSWORD` trong môi trường chạy rồi gọi `flutter test test/live_order_smoke_test.dart`. Bài kiểm thử lịch bận tự dọn mục sau khi chạy.

Backend phải chạy và có tài khoản hợp lệ. Với backend HTTP ở môi trường phát triển, cấu hình `auth.refresh-token-cookie.secure=false` để cookie phiên có thể hoạt động; production giữ HTTPS và Secure cookie.

Google sign-in cần `COGNITO_DOMAIN`, `COGNITO_CLIENT_ID`, và callback `odms://auth/callback` được thêm vào Cognito. Thanh toán và dữ liệu media sử dụng dịch vụ hiện có của backend.

## Cấu trúc

```text
lib/
  app/       # Khởi tạo, router, theme
  core/      # HTTP, phiên, cấu hình, phân quyền
  shared/    # Điều hướng mobile, form, card, map, localization
  features/  # Auth, customer, manager, staff, support, media...
assets/      # Logo website và font có giấy phép
config/      # Ví dụ cấu hình theo môi trường
test/      # Unit và widget tests
```

Điều hướng dưới thay đổi theo vai trò. Staff không có kết nối drone, handover, preflight, điều khiển bay hoặc postflight. Các quyền nghiệp vụ vẫn do backend kiểm tra; app không tự mở quyền CRUD vượt quá website.

## Kiểm tra và build

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --concurrency=1
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/development.json
flutter build ios --no-codesign --dart-define-from-file=config/development.json
```

Xuất ảnh kiểm tra UI bằng dữ liệu test:

```sh
flutter test test/redesign_test.dart --concurrency=1 --dart-define=EXPORT_PREVIEWS=true
```

Ảnh nằm trong `build/previews/`. Đây là dữ liệu kiểm thử, không phải ảnh chụp một phiên backend thật.

Xem [các chức năng và giới hạn](docs/features.md), [kiến trúc](docs/architecture.md), và [kết quả kiểm tra](docs/verification.md).

Git chỉ làm việc local: nhánh `feat/*`, commit theo chức năng, merge vào `dev`. Không cấu hình remote hoặc push.
