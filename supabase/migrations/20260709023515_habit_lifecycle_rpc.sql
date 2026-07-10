-- ============================================================
-- Kolom baru: tracking progress akumulasi hari sukses per stage
-- ============================================================
alter table habits
  add column progress_hari_sukses int not null default 0;

-- ============================================================
-- evaluate_habit_lazy: turun stage (lazy, dipicu tiap app dibuka)
-- ============================================================
create or replace function evaluate_habit_lazy(p_habit_id uuid)
returns habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_day date;
  v_has_success boolean;
  v_new_stage int;
  v_new_nyawa_maks int;
begin
  select * into v_habit from habits where id = p_habit_id;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  -- maintenance/paused: nyawa dimatikan total, skip evaluasi
  if v_habit.status <> 'active' then
    return v_habit;
  end if;

  v_day := v_habit.last_evaluated_date;

  while v_day < current_date loop
    select exists (
      select 1 from check_ins
      where habit_id = v_habit.id and tanggal = v_day and status = 'berhasil'
    ) into v_has_success;

    -- kosong dihitung sama dengan gagal
    if not v_has_success then
      v_habit.nyawa_tersisa := v_habit.nyawa_tersisa - 1;

      if v_habit.nyawa_tersisa <= 0 then
        if v_habit.stage_saat_ini > 1 then
          v_new_stage := v_habit.stage_saat_ini - 1;
          select nyawa_maks into v_new_nyawa_maks
          from habit_stages where habit_id = v_habit.id and stage_number = v_new_stage;
          v_habit.stage_saat_ini := v_new_stage;
          v_habit.nyawa_tersisa := coalesce(v_new_nyawa_maks, 3);
          v_habit.progress_hari_sukses := 0;  -- masuk-ulang stage ini, progress mulai dari 0
        else
          v_habit.status := 'paused';
          v_habit.nyawa_tersisa := 0;
          exit;  -- histori yang udah kejadian nggak dievaluasi ulang
        end if;
      end if;
    end if;

    v_day := v_day + 1;
  end loop;

  v_habit.last_evaluated_date := current_date;

  update habits set
    stage_saat_ini = v_habit.stage_saat_ini,
    status = v_habit.status,
    nyawa_tersisa = v_habit.nyawa_tersisa,
    progress_hari_sukses = v_habit.progress_hari_sukses,
    last_evaluated_date = v_habit.last_evaluated_date
  where id = v_habit.id;

  return v_habit;
end;
$$;

grant execute on function evaluate_habit_lazy(uuid) to authenticated;

-- ============================================================
-- evaluate_all_habits_lazy: wrapper, evaluasi semua habit aktif
-- milik user dalam satu round-trip (panggil sekali tiap app dibuka)
-- ============================================================
create or replace function evaluate_all_habits_lazy()
returns setof habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  for v_id in select id from habits where user_id = auth.uid() and status = 'active'
  loop
    return next evaluate_habit_lazy(v_id);
  end loop;
  return;
end;
$$;

grant execute on function evaluate_all_habits_lazy() to authenticated;

-- ============================================================
-- create_check_in: catat check-in + evaluasi naik stage
-- ============================================================
create or replace function create_check_in(p_habit_id uuid, p_status text)
returns check_ins
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_checkin check_ins%rowtype;
  v_max_stage int;
  v_next_nyawa_maks int;
  c_durasi_hari constant int := 7;  -- konstanta MVP (Opsi B) — belum per-stage
begin
  if p_status not in ('berhasil', 'gagal') then
    raise exception 'status harus berhasil atau gagal';
  end if;

  select * into v_habit from habits where id = p_habit_id;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  if v_habit.status = 'paused' then
    raise exception 'habit sedang paused, restart dulu sebelum check-in';
  end if;

  -- tanggal diisi server, bukan parameter client:
  -- otomatis menegakkan "nggak bisa checkin tanggal depan" + "satu entri per hari"
  insert into check_ins (habit_id, tanggal, status)
  values (v_habit.id, current_date, p_status)
  returning * into v_checkin;

  if p_status = 'berhasil' and v_habit.status = 'active' then
    if v_habit.progress_hari_sukses + 1 < c_durasi_hari then
      -- belum cukup, cuma nambah progress
      update habits set
        progress_hari_sukses = progress_hari_sukses + 1
      where id = v_habit.id;
    else
      -- syarat durasi terpenuhi -> naik stage atau endgame
      select max(stage_number) into v_max_stage
      from habit_stages where habit_id = v_habit.id;

      if v_habit.stage_saat_ini < v_max_stage then
        select nyawa_maks into v_next_nyawa_maks
        from habit_stages
        where habit_id = v_habit.id and stage_number = v_habit.stage_saat_ini + 1;

        update habits set
          stage_saat_ini = v_habit.stage_saat_ini + 1,
          nyawa_tersisa = coalesce(v_next_nyawa_maks, 3),
          progress_hari_sukses = 0
        where id = v_habit.id;
      else
        update habits set
          status = 'maintenance',
          progress_hari_sukses = 0
        where id = v_habit.id;
      end if;
    end if;
  end if;

  return v_checkin;
end;
$$;

grant execute on function create_check_in(uuid, text) to authenticated;