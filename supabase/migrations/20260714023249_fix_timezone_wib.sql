-- ============================================================
-- today_wib(): "hari ini" versi WIB, bukan bergantung timezone
-- session yang ambigu (ALTER ROLE vs SET ROLE). Sengaja hardcode
-- 'Asia/Jakarta' -- ini MVP single-tenant (cuma Farid), bukan app
-- multi-timezone. Kalau nanti ada user lain di zona beda, ini perlu
-- jadi per-user setting.
-- ============================================================
create or replace function today_wib()
returns date
language sql
stable
as $$
  select (now() at time zone 'Asia/Jakarta')::date;
$$;

grant execute on function today_wib() to authenticated;

create or replace function evaluate_habit_lazy(p_habit_id uuid)
returns habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_day date;
  v_ada_checkin boolean;
  v_state habit_state;
  v_today date := today_wib();
begin
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then raise exception 'habit not found or access denied'; end if;
  if v_habit.status <> 'active' then return v_habit; end if;

  v_day := v_habit.last_evaluated_date;

  while v_day < v_today loop
    select exists (select 1 from check_ins where habit_id = v_habit.id and tanggal = v_day) into v_ada_checkin;
    if not v_ada_checkin then
      v_state := apply_one_day_failure(v_habit.id, v_habit.stage_saat_ini, v_habit.nyawa_tersisa, v_habit.progress_hari_sukses);
      v_habit.stage_saat_ini := v_state.stage_saat_ini;
      v_habit.nyawa_tersisa := v_state.nyawa_tersisa;
      v_habit.progress_hari_sukses := v_state.progress_hari_sukses;
      v_habit.status := v_state.status;
      if v_habit.status = 'paused' then exit; end if;
    end if;
    v_day := v_day + 1;
  end loop;

  v_habit.last_evaluated_date := v_today;

  update habits set
    stage_saat_ini = v_habit.stage_saat_ini, status = v_habit.status,
    nyawa_tersisa = v_habit.nyawa_tersisa, progress_hari_sukses = v_habit.progress_hari_sukses,
    last_evaluated_date = v_habit.last_evaluated_date
  where id = v_habit.id;

  return v_habit;
end;
$$;
grant execute on function evaluate_habit_lazy(uuid) to authenticated;

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
  v_state habit_state;
  v_today date := today_wib();
  c_durasi_hari constant int := 7;
begin
  if p_status not in ('berhasil', 'gagal') then raise exception 'status harus berhasil atau gagal'; end if;
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then raise exception 'habit not found or access denied'; end if;
  if v_habit.status = 'paused' then raise exception 'habit sedang paused, restart dulu sebelum check-in'; end if;

  insert into check_ins (habit_id, tanggal, status) values (v_habit.id, v_today, p_status)
  returning * into v_checkin;

  if p_status = 'berhasil' and v_habit.status = 'active' then
    if v_habit.progress_hari_sukses + 1 < c_durasi_hari then
      v_event := 'progress';
      update habits set progress_hari_sukses = progress_hari_sukses + 1 where id = v_habit.id returning * into v_habit;
    else
      select max(stage_number) into v_max_stage from habit_stages where habit_id = v_habit.id;
      if v_habit.stage_saat_ini < v_max_stage then
        v_event := 'stage_up';
        select nyawa_maks into v_next_nyawa_maks from habit_stages
        where habit_id = v_habit.id and stage_number = v_habit.stage_saat_ini + 1;
        update habits set stage_saat_ini = v_habit.stage_saat_ini + 1, nyawa_tersisa = coalesce(v_next_nyawa_maks, 3), progress_hari_sukses = 0
        where id = v_habit.id returning * into v_habit;
      else
        v_event := 'endgame';
        update habits set status = 'maintenance', progress_hari_sukses = 0 where id = v_habit.id returning * into v_habit;
      end if;
    end if;
  elsif p_status = 'gagal' and v_habit.status = 'active' then
    v_state := apply_one_day_failure(v_habit.id, v_habit.stage_saat_ini, v_habit.nyawa_tersisa, v_habit.progress_hari_sukses);
    v_event := case
      when v_state.status = 'paused' then 'paused'
      when v_state.stage_saat_ini < v_habit.stage_saat_ini then 'stage_down'
      else 'life_lost'
    end;
    update habits set stage_saat_ini = v_state.stage_saat_ini, nyawa_tersisa = v_state.nyawa_tersisa,
      progress_hari_sukses = v_state.progress_hari_sukses, status = v_state.status
    where id = v_habit.id returning * into v_habit;
  end if;

  return (v_checkin, v_event, v_habit)::check_in_result;
end;
$$;
grant execute on function create_check_in(uuid, text) to authenticated;

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
  if not found then raise exception 'habit not found or access denied'; end if;
  if v_habit.status <> 'paused' then raise exception 'habit tidak dalam status paused, tidak perlu restart'; end if;

  select nyawa_maks into v_stage1_nyawa_maks from habit_stages where habit_id = v_habit.id and stage_number = 1;

  update habits set status = 'active', stage_saat_ini = 1, nyawa_tersisa = coalesce(v_stage1_nyawa_maks, 3),
    progress_hari_sukses = 0, last_evaluated_date = today_wib()
  where id = v_habit.id returning * into v_habit;

  return v_habit;
end;
$$;
grant execute on function restart_habit(uuid) to authenticated;

create or replace function create_habit_with_stages(
  p_nama text, p_target_akhir_nilai numeric, p_target_akhir_unit text, p_stage_targets numeric[]
)
returns habits
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_habit habits%rowtype;
  v_user_id uuid := auth.uid();
  i int;
  v_jumlah_stage int := array_length(p_stage_targets, 1);
begin
  if v_user_id is null then raise exception 'harus login dulu'; end if;
  if v_jumlah_stage is null or v_jumlah_stage < 1 then
    raise exception 'minimal 1 stage (kirim [target_akhir] kalau mau skip jadi habit statis)';
  end if;

  insert into habits (user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
  values (v_user_id, p_nama, p_target_akhir_nilai, p_target_akhir_unit, 1, 'active', 3, 0, today_wib())
  returning * into v_habit;

  for i in 1..v_jumlah_stage loop
    insert into habit_stages (habit_id, stage_number, target_harian, nyawa_maks)
    values (v_habit.id, i, p_stage_targets[i], 3);
  end loop;

  return v_habit;
end;
$$;
grant execute on function create_habit_with_stages(text, numeric, text, numeric[]) to authenticated;

alter table habits alter column last_evaluated_date set default today_wib();