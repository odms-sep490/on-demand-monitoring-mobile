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

## 🛠️ Workflow & Contributing / Quy trình đóng góp

### 🌳 Branch naming / Đặt tên nhánh

Create a branch from the latest `dev` and name it `type/description-slug`. Use lowercase English and separate words with hyphens.

Tạo nhánh từ `dev` mới nhất theo mẫu `type/mo-ta-ngan`. Dùng tiếng Anh viết thường và phân cách các từ bằng dấu gạch nối.

| Type / Loại | When to use (EN) | Khi nào dùng (VI) | Example / Ví dụ |
| --- | --- | --- | --- |
| `feat` | Add a user-facing feature | Thêm tính năng cho người dùng | `feat/customer-gallery-filters` |
| `fix` | Correct an existing bug | Sửa lỗi đang xảy ra | `fix/staff-availability-validation` |
| `design` | Update visual styling or interaction | Chỉnh giao diện, bố cục hoặc hiệu ứng tương tác | `design/order-detail-header` |
| `refactor` | Improve code structure while preserving behavior | Sắp xếp lại code và giữ nguyên hành vi | `refactor/split-mission-components` |
| `chore` | Maintain dependencies, tooling or build config | Bảo trì thư viện, công cụ hoặc cấu hình build | `chore/update-flutter-sdk` |
| `docs` | Update project documentation | Cập nhật tài liệu dự án | `docs/update-mobile-readme` |
| `test` | Add or improve automated tests | Thêm hoặc cải thiện kiểm thử tự động | `test/customer-order-flow` |

### 💬 Commit messages / Đặt tên commit

Use `type(scope): description` for feature-specific changes and `type: description` for project-wide changes. Write the description in lowercase English, start it with a verb, and omit the final period. Keep each commit focused on one feature or one related change.

Dùng `type(scope): description` cho thay đổi theo tính năng và `type: description` cho thay đổi cấp dự án. Viết mô tả bằng tiếng Anh thường, bắt đầu bằng động từ và bỏ dấu chấm cuối câu. Mỗi commit nên gom thay đổi của một tính năng hoặc một nhóm công việc liên quan.

| Scope / Phạm vi | Example / Ví dụ | Meaning / Ý nghĩa |
| --- | --- | --- |
| Customer | `feat(customer): add gallery filters` | Thêm bộ lọc thư viện |
| Staff | `fix(staff): validate availability dates` | Sửa kiểm tra ngày trong lịch bận |
| Shared UI | `refactor(ui): extract order status badge` | Tách component trạng thái đơn |
| Project / Toàn dự án | `chore: update flutter sdk` | Cập nhật Flutter SDK |

### 🚀 Pull requests / Quy trình mở PR

| Step / Bước | English | Tiếng Việt |
| --- | --- | --- |
| 1. Branch | Sync your local `dev`, then create a feature branch. | Đồng bộ `dev` local rồi tạo nhánh cho công việc. |
| 2. Verify | Run the formatter, analyzer and relevant tests. | Chạy formatter, analyzer và các test liên quan. |
| 3. Commit and push | Commit by feature and push your working branch. | Commit theo từng chức năng rồi push nhánh đang làm. |
| 4. Open a PR | Target `dev`. Summarize the changes, include verification results and attach screenshots for UI changes. | Mở PR vào `dev`. Ghi rõ nội dung thay đổi, kết quả kiểm thử và đính kèm ảnh nếu sửa giao diện. |
| 5. Review and merge | Request review and merge approved changes into `dev`. Promote reviewed versions to `main`. | Nhờ review rồi merge phần đã duyệt vào `dev`. Đưa bản đã duyệt lên `main`. |

Example / Ví dụ:

```bash
git switch dev
git switch -c feat/customer-gallery-filters
# After editing and testing / Sau khi sửa và kiểm thử
git add lib/features/customer/
git commit -m "feat(customer): add gallery filters"
git push -u origin feat/customer-gallery-filters
```
