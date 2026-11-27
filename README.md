# 📱 ODMS Mobile

**Đặt yêu cầu giám sát, theo dõi tiến độ và xem kết quả trên điện thoại.**

ODMS Mobile là ứng dụng Flutter cho Android và iOS của **On-Demand Monitoring System**. App kết nối với backend ODMS và dùng chung dữ liệu nghiệp vụ với website.

## ✨ Tính năng

| Vai trò | Có thể làm gì? |
| --- | --- |
| **Customer** | Tạo yêu cầu giám sát qua 6 bước, chọn vị trí và vùng giám sát trên bản đồ ở bước 2, theo dõi đơn, xem báo giá và kết quả, mở thư viện ảnh/video, dùng FAQ và gửi yêu cầu hỗ trợ. |
| **Staff** | Xem nhiệm vụ được giao và thực hiện các thao tác CRUD được cấp quyền với hạng mục kiểm tra, minh chứng, lịch bận và các hồ sơ nghiệp vụ liên quan. |

Trong thư viện Customer, mục **AI phân tích thay đổi** cho phép chọn hai ảnh, gửi yêu cầu và xem lịch sử phân tích. Backend cần worker xử lý ảnh để tạo kết quả mới. Staff không có chức năng điều khiển bay.

## ⚡ Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Ứng dụng | Flutter 3.51.0-0.2.pre, Dart với SDK constraint `^3.14.0` |
| Giao diện | Material UI, Be Vietnam Pro, giao diện sáng và tối, tiếng Việt và tiếng Anh |
| Trạng thái và điều hướng | Riverpod, GoRouter |
| Backend và phiên | Dio, Flutter Secure Storage, Cognito cho Google sign-in |
| Bản đồ | flutter_map, latlong2 |

## 🚀 Chạy trên máy phát triển

### 1. Chuẩn bị

Cài Flutter theo phiên bản ở trên, Android SDK và JDK 21 cho Android hoặc Xcode đầy đủ cho iOS. Khởi động backend ODMS và chuẩn bị tài khoản Customer hoặc Staff hợp lệ.

### 2. Cấu hình backend

```bash
flutter pub get
cp config/development.example.json config/development.json
```

Chỉnh `API_BASE_URL` trong `config/development.json`.

| Thiết bị | Ví dụ URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080` |
| iOS Simulator | `http://localhost:8080` |
| Điện thoại thật | URL backend mà thiết bị truy cập được, ví dụ `http://192.168.1.10:8080` |
| Bản release | URL HTTPS của backend, theo mẫu [production.example.json](config/production.example.json) |

Với backend HTTP chạy local, đặt `auth.refresh-token-cookie.secure=false` trong môi trường phát triển để cookie làm mới phiên hoạt động. Bản release dùng HTTPS và cookie Secure. Giữ cấu hình riêng, mật khẩu và khóa ký ngoài Git.

Nếu dùng Google sign-in, điền `COGNITO_DOMAIN` và `COGNITO_CLIENT_ID` rồi đăng ký callback `odms://auth/callback` trong Cognito.

### 3. Khởi động app

```bash
flutter devices
flutter run --dart-define-from-file=config/development.json
```

Nếu Android cần đi qua ADB tới backend local ở cổng `18080`, dùng:

```bash
adb reverse tcp:18080 tcp:18080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

## 📂 Cấu trúc source

Source được tổ chức theo tính năng. Mỗi trang tải hoặc nhận dữ liệu, ghép các component và điều hướng sang các màn liên quan.

| Thư mục | Trách nhiệm |
| --- | --- |
| `lib/app/` | Khởi tạo ứng dụng, khai báo route và theme |
| `lib/core/` | API client, cấu hình, provider dùng chung, kiểu dữ liệu và chính sách quyền |
| `lib/features/` | Các màn và component theo tính năng như Customer, Staff, xác thực, hồ sơ, thông báo và hỗ trợ |
| `lib/shared/` | Widget, form, bản đồ và tiện ích dùng chung |
| `assets/` | Logo, hình ảnh và font |
| `config/` | Mẫu cấu hình kết nối backend |
| `test/` | Unit test, widget test và smoke test backend |

**Đặt code mới ở đâu?**

- Component chỉ phục vụ một nghiệp vụ đặt cạnh trang trong `lib/features/<tính năng>/`. Ví dụ, chi tiết đơn Customer có file riêng cho tổng quan, bản đồ và báo cáo.
- Widget thực sự dùng ở nhiều tính năng đặt trong `lib/shared/`.
- Cấu hình môi trường, xử lý lỗi HTTP và chính sách quyền dùng chung đặt trong `lib/core/`. Quyền thực hiện thao tác vẫn do backend kiểm tra.

## 🎨 Giao diện

Dùng màu, kiểu chữ và khoảng cách từ theme ODMS. Giữ nội dung và thứ tự các bước nghiệp vụ đồng bộ với web. Khi sửa component, kiểm tra cả giao diện sáng và tối, tiếng Việt và tiếng Anh, cùng trạng thái đang tải, trống và lỗi trên màn hình điện thoại.

## 🧪 Kiểm tra và build

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --concurrency=1
```

Để chạy smoke test với backend, đặt `ODMS_SMOKE_BASE_URL` và `ODMS_SMOKE_PASSWORD` trong môi trường chạy. Dùng database thử nghiệm vì test tạo một đơn Customer và kiểm tra thêm, sửa, xóa lịch bận Staff. Test lịch bận tự dọn bản ghi sau khi chạy.

```bash
flutter test test/live_order_smoke_test.dart
```

Build thử cho Android và iOS:

```bash
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/development.json
flutter build ios --no-codesign --dart-define-from-file=config/development.json
```

Xuất ảnh giao diện với dữ liệu kiểm thử vào `build/previews/`:

```bash
flutter test test/redesign_test.dart --concurrency=1 --dart-define=EXPORT_PREVIEWS=true
```

Xem thêm [tính năng và giới hạn](docs/features.md), [kiến trúc](docs/architecture.md) và [kết quả kiểm tra](docs/verification.md).

## 🛠️ Đóng góp

1. Tạo nhánh từ `dev`, ví dụ `feat/customer-gallery`, `fix/staff-availability` hoặc `docs/update-readme`.
2. Commit theo từng chức năng hoặc nhóm thay đổi. Dùng Conventional Commits, ví dụ `feat(customer): add gallery filters` hoặc `refactor(staff): extract mission filters`.
3. Chạy formatter, analyzer và các test liên quan.
4. Push nhánh và mở pull request vào `dev` để review. Nhánh `main` nhận bản đã được duyệt.
