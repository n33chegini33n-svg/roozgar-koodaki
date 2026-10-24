-- رسید پرداخت ولی: ولی ثبت می‌کند، مدیر تأیید یا رد می‌کند.

create table if not exists public.payment_receipts (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references auth.users(id),
  student_id uuid not null references public.students(id),
  amount bigint not null check (amount > 0),
  reference_no text not null check (length(trim(reference_no)) >= 4),
  state text not null default 'pending'
    check (state in ('pending', 'approved', 'rejected')),
  decision_note text not null default '',
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.payment_receipts enable row level security;

-- ولی: فقط رسیدهای خودش را می‌بیند.
create policy receipts_parent_select on public.payment_receipts
  for select to authenticated
  using (parent_id = auth.uid());

-- ولی: فقط برای فرزند خودش و فقط با وضعیت «در انتظار» ثبت می‌کند.
create policy receipts_parent_insert on public.payment_receipts
  for insert to authenticated
  with check (
    parent_id = auth.uid()
    and state = 'pending'
    and decided_by is null
    and student_id in (
      select ps.student_id from public.parent_students ps
      where ps.parent_id = auth.uid()
    )
  );

-- مدیر و ادمین: همه را می‌بینند.
create policy receipts_staff_select on public.payment_receipts
  for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.active = true
        and p.role in ('admin', 'manager')
    )
  );

-- مدیر و ادمین: فقط تصمیم را ثبت می‌کنند.
create policy receipts_staff_update on public.payment_receipts
  for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.active = true
        and p.role in ('admin', 'manager')
    )
  )
  with check (state in ('approved', 'rejected'));

-- حذف برای هیچ‌کس مجاز نیست (سابقهٔ مالی).