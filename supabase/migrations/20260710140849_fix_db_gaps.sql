-- ============================================================
-- Composite type: hasil create_check_in, termasuk info transisi
-- ============================================================
create type check_in_result as (
  check_in check_ins,
  event text,            -- 'none' | 'progress' | 'stage_up' | 'endgame'
  habit habits            -- state habit TERBARU setelah check-in diproses
);

-- ============================================================
-- create_check_in v3: + row lock, + return event transisi
-- ============================================================
create or replace function create_check_in(p_habit_id uuid, p_status text)
returns check_in_result
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_checkin check_ins%rowtype;
  v_max_stage int;
  v_next_nyawa_maks int;
  v_event text := 'none';
  c_durasi_hari constant int := 7;
begin
  if p_status not in ('berhasil', 'gagal') then
    raise exception 'status harus berhasil atau gagal';
  end if;

  -- 'for update' mengunci row ini sampai transaksi selesai:
  -- request kedua yang datang bersamaan menunggu, bukan baca data basi
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  if v_habit.status = 'paused' then
    raise exception 'habit sedang paused, restart dulu sebelum check-in';
  end if;

  insert into check_ins (habit_id, tanggal, status)
  values (v_habit.id, current_date, p_status)
  returning * into v_checkin;

  if p_status = 'berhasil' and v_habit.status = 'active' then
    if v_habit.progress_hari_sukses + 1 < c_durasi_hari then
      v_event := 'progress';
      update habits set
        progress_hari_sukses = progress_hari_sukses + 1
      where id = v_habit.id
      returning * into v_habit;
    else
      select max(stage_number) into v_max_stage
      from habit_stages where habit_id = v_habit.id;

      if v_habit.stage_saat_ini < v_max_stage then
        v_event := 'stage_up';
        select nyawa_maks into v_next_nyawa_maks
        from habit_stages
        where habit_id = v_habit.id and stage_number = v_habit.stage_saat_ini + 1;

        update habits set
          stage_saat_ini = v_habit.stage_saat_ini + 1,
          nyawa_tersisa = coalesce(v_next_nyawa_maks, 3),
          progress_hari_sukses = 0
        where id = v_habit.id
        returning * into v_habit;
      else
        v_event := 'endgame';
        update habits set
          status = 'maintenance',
          progress_hari_sukses = 0
        where id = v_habit.id
        returning * into v_habit;
      end if;
    end if;
  end if;

  return (v_checkin, v_event, v_habit)::check_in_result;
end;
$$;

grant execute on function create_check_in(uuid, text) to authenticated;

-- ============================================================
-- restart_habit: pulihkan habit dari status 'paused'
-- kembali ke stage 1, nyawa penuh, progress 0 (mulai ulang total)
-- ============================================================
create or replace function restart_habit(p_habit_id uuid)
returns habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_stage1_nyawa_maks int;
begin
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  if v_habit.status <> 'paused' then
    raise exception 'habit tidak dalam status paused, tidak perlu restart';
  end if;

  select nyawa_maks into v_stage1_nyawa_maks
  from habit_stages where habit_id = v_habit.id and stage_number = 1;

  update habits set
    status = 'active',
    stage_saat_ini = 1,
    nyawa_tersisa = coalesce(v_stage1_nyawa_maks, 3),
    progress_hari_sukses = 0,
    last_evaluated_date = current_date
  where id = v_habit.id
  returning * into v_habit;

  return v_habit;
end;
$$;

grant execute on function restart_habit(uuid) to authenticated;

-- ============================================================
-- Constraint: stage_saat_ini harus valid, menunjuk stage_number
-- yang benar-benar ada dan milik habit yang sama (gap #6)
--
-- 'deferrable initially deferred': pengecekan ditunda sampai akhir
-- transaksi -- WAJIB kalau proses "create habit" insert row habits
-- dan row habit_stages dalam transaksi yang sama (insert habit dulu
-- baru insert stages, keduanya harus satu transaksi/RPC, bukan dua
-- request terpisah -- kalau terpisah, insert habit akan ditolak
-- karena belum ada stage sama sekali di momen itu).
-- ============================================================
alter table habits
  add constraint stage_saat_ini_exists
  foreign key (id, stage_saat_ini)
  references habit_stages (habit_id, stage_number)
  deferrable initially deferred;