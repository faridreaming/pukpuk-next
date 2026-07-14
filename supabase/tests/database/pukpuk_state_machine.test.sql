begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

-- ============================================================
-- Setup: 2 test user (SEMUA insert ke auth.users di sini, SEBELUM
-- role di-switch ke 'authenticated' -- role itu memang nggak boleh
-- insert ke auth.users, jadi urutan ini penting)
-- ============================================================
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'test1@pukpuk.test'),
  ('22222222-2222-2222-2222-222222222222', 'test2@pukpuk.test');

insert into public.habits
  (id, user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111',
   'meditasi', 30, 'menit', 1, 'active', 3, 0, today_wib());

insert into public.habit_stages (habit_id, stage_number, target_harian, nyawa_maks) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1, 6, 3),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2, 12, 3);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- Test 1-2
select results_eq(
  $$ select (create_check_in('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'berhasil')).event $$,
  $$ values ('progress'::text) $$,
  'Check-in pertama: event = progress'
);

select results_eq(
  $$ select stage_saat_ini from habits where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ values (1) $$,
  'Stage belum berubah'
);

-- Test 3-4
update habits set progress_hari_sukses = 6
  where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
delete from check_ins where habit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select results_eq(
  $$ select (create_check_in('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'berhasil')).event $$,
  $$ values ('stage_up'::text) $$,
  'Check-in ke-7: event = stage_up'
);

select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa, progress_hari_sukses
     from habits where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ values (2, 3, 0) $$,
  'Naik stage: stage=2, nyawa refresh, progress reset'
);

-- Test 5-6
update habits set progress_hari_sukses = 6
  where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
delete from check_ins where habit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select results_eq(
  $$ select (create_check_in('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'berhasil')).event $$,
  $$ values ('endgame'::text) $$,
  'Naik dari stage terakhir: event = endgame'
);

select results_eq(
  $$ select status from habits where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ values ('maintenance'::text) $$,
  'Status jadi maintenance'
);

-- Test 7
update habits set
  status = 'active', stage_saat_ini = 2, nyawa_tersisa = 1,
  progress_hari_sukses = 5, last_evaluated_date = today_wib() - 1
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select evaluate_habit_lazy('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa, progress_hari_sukses
     from habits where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ values (1, 3, 0) $$,
  'Demosi: turun stage, nyawa refresh, progress reset'
);

-- Test 8: RLS -- user kedua (sudah dibuat di setup) coba check-in habit user 1
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

select throws_ok(
  $$ select create_check_in('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'berhasil') $$,
  'habit not found or access denied'
);

select * from finish();
rollback;