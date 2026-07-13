-- ============================================================
-- Tambah status 'archived' ke constraint yang udah ada
-- ============================================================
alter table habits drop constraint if exists habits_status_check;
alter table habits add constraint habits_status_check
  check (status in ('active', 'maintenance', 'paused', 'archived'));

-- ============================================================
-- archive_habit: soft-delete -- riwayat check_ins/habit_stages
-- tetap utuh, cuma disembunyikan dari daftar aktif
-- ============================================================
create or replace function archive_habit(p_habit_id uuid)
returns habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
begin
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  update habits set status = 'archived' where id = p_habit_id
  returning * into v_habit;

  return v_habit;
end;
$$;

grant execute on function archive_habit(uuid) to authenticated;