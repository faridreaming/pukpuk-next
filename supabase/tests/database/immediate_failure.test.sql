begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('44444444-4444-4444-4444-444444444444', 'test4@pukpuk.test');

insert into public.habits
  (id, user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444',
   'lari', 5, 'km', 2, 'active', 1, 3, current_date - 1);

insert into public.habit_stages (habit_id, stage_number, target_harian, nyawa_maks) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 1, 3),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 2, 3, 3);

set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

-- Test 1-2: nyawa=1, klik gagal -> langsung turun stage + event stage_down
select results_eq(
  $$ select (create_check_in('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'gagal')).event $$,
  $$ values ('stage_down'::text) $$,
  'Gagal saat nyawa=1: langsung turun stage'
);

select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa from habits where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ values (1, 3) $$,
  'Turun ke stage 1, nyawa refresh ke nyawa_maks stage 1'
);

-- Test 3-4: evaluate_habit_lazy jalan buat KEMARIN (yang udah ada check-in gagal)
-- harusnya TIDAK motong nyawa lagi -- ini test double-count
update habits set last_evaluated_date = current_date - 1
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select evaluate_habit_lazy('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

select results_eq(
  $$ select nyawa_tersisa from habits where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ values (3) $$,
  'evaluate_habit_lazy TIDAK motong nyawa lagi untuk hari yang udah ada check-in gagal'
);

select results_eq(
  $$ select stage_saat_ini from habits where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ values (1) $$,
  'Stage juga tidak ikut turun lagi (bukti tidak diproses dua kali)'
);

select * from finish();
rollback;