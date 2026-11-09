# مدیر من — نسخه شخصی آفلاین

اپ Flutter فارسی برای مدیریت پروژه و وظیفه بدون حساب، سرور یا اتصال اینترنت. داده‌ها در SQLite خصوصی برنامه نگهداری می‌شوند.

ساختار: `mobile/` (Flutter/RTL/SQLite). وضعیت پیاده‌سازی و آزمون در `PROJECT_PROGRESS.md` ثبت می‌شود.

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

فایل نصب آزمایشی در `mobile/build/app/outputs/flutter-apk/app-debug.apk` ساخته می‌شود. نسخه Release امضاشده هنوز منتشر نشده است.

مسیر توسعه آینده در `FUTURE_ROADMAP.md` آمده است.
