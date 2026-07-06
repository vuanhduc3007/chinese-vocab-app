# Ứng dụng học từ vựng tiếng Trung (Flutter)

Flashcard + SM-2 spaced repetition, một codebase Flutter chạy trên **Android** và **Windows**.

## 1. Vì sao chỉ có `lib/` và `pubspec.yaml`?

Mình không có Flutter SDK để chạy `flutter create` trong môi trường tạo code này, nên
project ở đây chỉ gồm **mã nguồn Dart** (`lib/`) + `pubspec.yaml` + dữ liệu mẫu.
Các thư mục nền tảng (`android/`, `windows/`, `ios/`...) do chính `flutter create` sinh ra
tự động và không nên viết tay, nên bạn cần tự sinh chúng bằng 2 lệnh dưới đây (chỉ mất ~30 giây).

## 2. Cài đặt lần đầu

Yêu cầu: đã cài [Flutter SDK](https://docs.flutter.dev/get-started/install) (kênh stable),
và đã bật Developer Mode trên Windows nếu muốn build Windows desktop.

```bash
# 1. Giải nén project này ra một thư mục, ví dụ chinese_vocab_app/
cd chinese_vocab_app

# 2. Sinh ra các thư mục nền tảng Android + Windows còn thiếu
#    (lệnh này sẽ KHÔNG đụng tới lib/ và pubspec.yaml đã có sẵn)
flutter create --platforms=android,windows --project-name chinese_vocab_app .

# 3. Cài dependencies
flutter pub get

# 4. Kiểm tra thiết bị/emulator đang có
flutter devices

# 5a. Chạy trên Android (điện thoại/emulator đã kết nối)
flutter run -d <android-device-id>

# 5b. Chạy trên Windows desktop
flutter run -d windows
```

> Nếu `flutter create` báo project name không hợp lệ vì thư mục đã có file, cứ chạy đè -
> nó chỉ thêm các file nền tảng còn thiếu, không xóa `lib/` của bạn.

## 3. Thử ngay với dữ liệu mẫu

Có sẵn file mẫu ở `sample_data/hsk1_sample.txt`. Mở app lên, vào tab **Bộ từ**, bấm nút
import (icon 📤 trên AppBar) và chọn file đó để thấy app hoạt động ngay với ~15 từ.

Định dạng file txt (mỗi dòng 1 từ):
```
临;lín [đt.]: đến, tới
你好;nǐ hǎo: xin chào     <- không có [loại từ] vẫn hợp lệ
```
Dòng bắt đầu bằng `#` bị bỏ qua (dùng làm comment).

## 4. Kiến trúc (Clean Architecture)

```
lib/
  models/         Word, Deck  (thuần dữ liệu, không phụ thuộc DB/UI)
  database/       DatabaseHelper - schema SQLite, mobile (sqflite) & desktop (sqflite_common_ffi)
  parser/         VocabParser - parse file .txt -> ParsedEntry
  srs/            SM2Algorithm - MODULE ĐỘC LẬP, chỉ nơi duy nhất biết công thức SM-2
  repositories/   WordRepository, DeckRepository - toàn bộ SQL nằm ở đây
  services/       LearningQueueService (hàng đợi học), TtsService, DailyStatsService, BackupService
  providers/      State management (package:provider): LearningProvider, DeckProvider,
                  StatsProvider, SettingsProvider
  ui/screens/     Learning, Stats, Search, Deck, Settings, Home (bottom nav)
  ui/widgets/     FlashcardWidget, AnswerButtons
  utils/          AppConstants, AppDateUtils
```

**Vì sao tách `srs/` riêng?** Toàn bộ phần còn lại của app (providers, repositories, UI)
chỉ nói chuyện với các field trên `Word` (easeFactor, interval, repetition, nextReview...)
và với enum `ReviewResult`. Không có nơi nào khác trong code biết công thức SM-2. Muốn đổi
sang thuật toán khác (ví dụ FSRS) sau này, chỉ cần viết lại `srs/sm2_algorithm.dart`.

**Learning Queue (`services/learning_queue_service.dart`)** cài đúng thứ tự ưu tiên trong
spec: (1) từ đến hạn SM-2 → (2) từ mới → (3) tự động chuyển Random Review khi hết cả hai,
không có màn hình "hết bài" nào cả. Quy tắc "Quên" (quay lại sau 8-12 câu) và quy tắc
Random Review (không lặp trong 30-50 câu, tự co giãn khi ít từ) đều nằm trong file này,
được đặt tên hằng số ở `utils/constants.dart` để dễ tinh chỉnh.

## 5. Phím tắt Desktop

| Phím | Hành động |
|---|---|
| Space | Hiện đáp án |
| Enter | Đã nhớ |
| Backspace | Quên |
| Esc | Thoát màn hình học |

## 6. TTS (Text-to-Speech)

`flutter_tts` được dùng với `zh-CN` để phát âm chữ Hán. Trên Android, plugin sẽ ưu tiên
engine on-device nếu máy có sẵn (thường là Google Speech Services đã cài offline voice
tiếng Trung trong Settings > Accessibility > Text-to-speech). Trên Windows, dùng engine
SAPI5 mặc định của hệ thống - nếu máy chưa có giọng tiếng Trung, vào Windows Settings >
Time & Language > Speech để cài thêm.

## 7. Dữ liệu & mở rộng sau này

- Import lại file .txt lớn hơn (ví dụ 5000 → 5200 từ): app tự nhận diện từ đã tồn tại
  (so khớp hanzi+pinyin trong cùng deck) và CHỈ thêm từ mới, giữ nguyên toàn bộ lịch sử SRS.
- Export/Import Progress ở tab Cài đặt dùng file JSON, độc lập với format DB, nên nâng cấp
  schema sau này không làm hỏng file backup cũ.
- Kiến trúc đã tách sẵn để bổ sung các kiểu câu hỏi khác (trắc nghiệm, điền pinyin, gõ chữ
  Hán, nghe chọn nghĩa...) mà không cần đụng vào `srs/` hay `repositories/` - chỉ cần thêm
  1 provider + 1 screen mới tái sử dụng `WordRepository` và `SM2Algorithm` hiện có.

## 8. Việc mình chưa thể làm ở đây

Vì sandbox tạo code này không có Flutter SDK / không truy cập được pub.dev, mình **không**
build hay chạy thử được project. Mã nguồn được viết theo đúng API của các package đã khai
báo trong `pubspec.yaml` (provider, sqflite, sqflite_common_ffi, flutter_tts, file_picker,
fl_chart) tại phiên bản đã ghim, nhưng bạn nên chạy `flutter pub get` + `flutter run` và
báo lại nếu gặp lỗi biên dịch cụ thể nào - mình sẽ sửa ngay.
