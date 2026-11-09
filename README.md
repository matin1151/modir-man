# کارتابل — MVP مدیریت پروژه و وظایف

سامانه فارسی و چندمستاجری برای مدیریت پروژه، سفارش و وظایف تیم‌های فریلنسری و تولید محتوا. ابزار تولید محتوا، تدوین، قالب و انتشار اجتماعی خارج از محدوده‌اند.

ساختار: `backend/` (FastAPI/PostgreSQL/REST نسخه‌دار)، `mobile/` (Flutter/RTL)، و `docker-compose.yml`.

```bash
cp backend/.env.example backend/.env
python3 -m venv .venv && . .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --reload
pytest -q
```

MCP در این مرحله فقط به‌صورت قرارداد آینده در نظر گرفته می‌شود و پس از تثبیت MVP فعال خواهد شد.
