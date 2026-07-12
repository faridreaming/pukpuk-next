create type habit_state as (
  stage_saat_ini int,
  nyawa_tersisa int,
  progress_hari_sukses int,
  status text
);

create or replace function apply_one_day_failure(
  p_habit_id uuid,
  p_stage_saat_ini int,
  p_nyawa_tersisa int,
  p_progress_hari_sukses int
)
returns habit_state
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_result habit_state;
  v_new_stage int;
  v_new_nyawa_maks int;
begin
  v_result.stage_saat_ini := p_stage_saat_ini;
  v_result.nyawa_tersisa := p_nyawa_tersisa - 1;
  v_result.progress_hari_sukses := p_progress_hari_sukses;
  v_result.status := 'active';

  if v_result.nyawa_tersisa <= 0 then
    if p_stage_saat_ini > 1 then
      v_new_stage := p_stage_saat_ini - 1;
      select nyawa_maks into v_new_nyawa_maks
      from habit_stages where habit_id = p_habit_id and stage_number = v_new_stage;
      v_result.stage_saat_ini := v_new_stage;
      v_result.nyawa_tersisa := coalesce(v_new_nyawa_maks, 3);
      v_result.progress_hari_sukses := 0;
    else
      v_result.status := 'paused';
      v_result.nyawa_tersisa := 0;
    end if;
  end if;

  return v_result;
end;
$$;

grant execute on function apply_one_day_failure(uuid, int, int, int) to authenticated;

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
begin
  select * into v_habit from habits where id = p_habit_id for update;
  if not found then
    raise exception 'habit not found or access denied';
  end if;

  if v_habit.status <> 'active' then
    return v_habit;
  end if;

  v_day := v_habit.last_evaluated_date;

  while v_day < current_date loop
    -- cek ADA CHECK-IN SAMA SEKALI (bukan cuma "ada yang berhasil") --
    -- kalau ada baris 'gagal', itu udah diproses immediate di create_check_in,
    -- jadi di sini WAJIB di-skip biar nggak kepotong dua kali
    select exists (
      select 1 from check_ins where habit_id = v_habit.id and tanggal = v_day
    ) into v_ada_checkin;

    if not v_ada_checkin then
      v_state := apply_one_day_failure(
        v_habit.id, v_habit.stage_saat_ini, v_habit.nyawa_tersisa, v_habit.progress_hari_sukses
      );
      v_habit.stage_saat_ini := v_state.stage_saat_ini;
      v_habit.nyawa_tersisa := v_state.nyawa_tersisa;
      v_habit.progress_hari_sukses := v_state.progress_hari_sukses;
      v_habit.status := v_state.status;
      if v_habit.status = 'paused' then exit; end if;
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
  c_durasi_hari constant int := 7;
begin
  if p_status not in ('berhasil', 'gagal') then
    raise exception 'status harus berhasil atau gagal';
  end if;

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
      update habits set progress_hari_sukses = progress_hari_sukses + 1
      where id = v_habit.id returning * into v_habit;
    else
      select max(stage_number) into v_max_stage from habit_stages where habit_id = v_habit.id;
      if v_habit.stage_saat_ini < v_max_stage then
        v_event := 'stage_up';
        select nyawa_maks into v_next_nyawa_maks from habit_stages
        where habit_id = v_habit.id and stage_number = v_habit.stage_saat_ini + 1;
        update habits set
          stage_saat_ini = v_habit.stage_saat_ini + 1,
          nyawa_tersisa = coalesce(v_next_nyawa_maks, 3),
          progress_hari_sukses = 0
        where id = v_habit.id returning * into v_habit;
      else
        v_event := 'endgame';
        update habits set status = 'maintenance', progress_hari_sukses = 0
        where id = v_habit.id returning * into v_habit;
      end if;
    end if;

  elsif p_status = 'gagal' and v_habit.status = 'active' then
    -- BARU: nyawa langsung berkurang, pakai fungsi yang SAMA dengan
    -- yang dipakai evaluate_habit_lazy -- nol duplikasi logic
    v_state := apply_one_day_failure(
      v_habit.id, v_habit.stage_saat_ini, v_habit.nyawa_tersisa, v_habit.progress_hari_sukses
    );
    v_event := case
      when v_state.status = 'paused' then 'paused'
      when v_state.stage_saat_ini < v_habit.stage_saat_ini then 'stage_down'
      else 'life_lost'
    end;
    update habits set
      stage_saat_ini = v_state.stage_saat_ini,
      nyawa_tersisa = v_state.nyawa_tersisa,
      progress_hari_sukses = v_state.progress_hari_sukses,
      status = v_state.status
    where id = v_habit.id returning * into v_habit;
  end if;

  return (v_checkin, v_event, v_habit)::check_in_result;
end;
$$;

grant execute on function create_check_in(uuid, text) to authenticated;