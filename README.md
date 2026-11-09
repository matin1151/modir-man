# کارتابل — MVP مدیریت پروژه و وظایف

نسخه آزمایشی فارسی برای مدیریت پروژه و وظیفه. این نسخه شامل حساب شخصی، ورود، پروژه، وظیفه، تغییر وضعیت، نمایش تاریخ شمسی و جداسازی داده بین حساب‌هاست. سفارش، همکاری تیمی، اشتراک، پرداخت کافه‌بازار و پنل مالک هنوز پیاده‌سازی نشده‌اند.

ساختار: `backend/` (FastAPI/PostgreSQL/REST نسخه‌دار)، `mobile/` (Flutter/RTL)، و `docker-compose.yml`.

```bash
docker compose up -d postgres
cp backend/.env.example backend/.env
# JWT_SECRET را در backend/.env با یک مقدار تصادفی امن جایگزین کنید.
python3 -m venv .venv && . .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
pytest -q
```

برای اجرای اندروید، در مسیر `mobile/` دستور `flutter run` را اجرا کنید. آدرس پیش‌فرض API در شبیه‌ساز Android برابر `http://10.0.2.2:8000` است. روی گوشی واقعی آدرس HTTPS سرور را در صفحه ورود وارد کنید. خروجی debug برای آزمایش است و نسخه انتشار امضا‌شده نیست.

API در `/docs` مستند می‌شود و همه مسیرهای دامنه زیر `/api/v1` قرار دارند. تست‌ها فعلاً روی SQLite اجرا می‌شوند؛ استقرار برنامه با PostgreSQL انجام می‌شود.

MCP در این مرحله فقط به‌صورت قرارداد آینده در نظر گرفته می‌شود و پس از تثبیت MVP فعال خواهد شد.
