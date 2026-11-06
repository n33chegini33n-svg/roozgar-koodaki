-- مدرک دیده‌شده توسط مدیر تا از شمارندهٔ کارتابل کسر شود.
-- اجرا فقط با تأیید صریح؛ این فایل به‌تنهایی روی سرور اعمال نمی‌شود.

alter table public.registration_records
  add column if not exists attachment_seen_at timestamptz;
