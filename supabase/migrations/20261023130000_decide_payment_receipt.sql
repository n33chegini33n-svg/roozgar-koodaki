-- تصمیم مدیر دربارهٔ رسید پرداخت ولی (تأیید یا رد).
-- فقط مدیر و ادمین. اجرا نشده؛ ابتدا باید بازبینی شود.

create or replace function public.decide_payment_receipt(
  p_receipt uuid,
  p_approve boolean,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receipt public.payment_receipts%rowtype;
  v_tuition uuid;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.active = true
      and p.role in ('admin', 'manager')
  ) then
    raise exception 'اجازهٔ این کار را ندارید';
  end if;

  select * into v_receipt
  from public.payment_receipts
  where id = p_receipt
  for update;

  if not found then
    raise exception 'رسید پیدا نشد';
  end if;

  if v_receipt.state <> 'pending' then
    raise exception 'این رسید قبلاً بررسی شده است';
  end if;

  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'برای رد، دلیل را بنویسید';
  end if;

  update public.payment_receipts
  set state = case when p_approve then 'approved' else 'rejected' end,
      decision_note = coalesce(p_note, ''),
      decided_by = auth.uid(),
      decided_at = now()
  where id = p_receipt;

  if p_approve then
    -- فقط اگر دقیقاً یک فاکتور باز با همان مبلغ باشد، تسویه می‌شود.
    select t.id into v_tuition
    from public.tuition_records t
    where t.student_id = v_receipt.student_id
      and t.amount = v_receipt.amount
      and t.status in ('pending', 'overdue')
    order by t.created_at
    limit 1;

    if v_tuition is not null
       and (
         select count(*) from public.tuition_records t
         where t.student_id = v_receipt.student_id
           and t.amount = v_receipt.amount
           and t.status in ('pending', 'overdue')
       ) = 1 then
      update public.tuition_records
      set status = 'paid'
      where id = v_tuition;
    end if;
  end if;

  perform public.write_audit(
    case when p_approve then 'تأیید رسید پرداخت' else 'رد رسید پرداخت' end,
    'رسید ' || v_receipt.reference_no || ' • مبلغ ' || v_receipt.amount
  );
end;
$$;

revoke all on function public.decide_payment_receipt(uuid, boolean, text) from public;
grant execute on function public.decide_payment_receipt(uuid, boolean, text) to authenticated;