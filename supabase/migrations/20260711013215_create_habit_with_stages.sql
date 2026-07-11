create or replace function create_habit_with_stages(
  p_nama text,
  p_target_akhir_nilai numeric,
  p_target_akhir_unit text,
  p_stage_targets numeric[]
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
  if v_user_id is null then
    raise exception 'harus login dulu';
  end if;

  if v_jumlah_stage is null or v_jumlah_stage < 1 then
    raise exception 'minimal 1 stage (kirim [target_akhir] kalau mau skip jadi habit statis)';
  end if;

  insert into habits
    (user_id, nama, target_akhir_nilai, target_akhir_unit,
     stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
  values
    (v_user_id, p_nama, p_target_akhir_nilai, p_target_akhir_unit,
     1, 'active', 3, 0, current_date)
  returning * into v_habit;

  for i in 1..v_jumlah_stage loop
    insert into habit_stages (habit_id, stage_number, target_harian, nyawa_maks)
    values (v_habit.id, i, p_stage_targets[i], 3);
  end loop;

  return v_habit;
end;
$$;

grant execute on function create_habit_with_stages(text, numeric, text, numeric[]) to authenticated;