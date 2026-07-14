begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('55555555-5555-5555-5555-555555555555', 'test5@pukpuk.test'),
  ('66666666-6666-6666-6666-666666666666', 'test6@pukpuk.test');

insert into public.habits
  (id, user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '55555555-5555-5555-5555-555555555555',
   'baca buku', 100, 'halaman', 3, 'paused', 0, 2, today_wib()),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '55555555-5555-5555-5555-555555555555',
   'push up', 50, 'reps', 1, 'active', 2, 1, today_wib());

insert into public.habit_stages (habit_id, stage_number, target_harian, nyawa_maks) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 20, 4),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 2, 60, 3),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 3, 100, 3),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 1, 50, 3);

insert into public.check_ins (habit_id, tanggal, status) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', today_wib() - 1, 'berhasil');

set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';

-- Test 1-2: restart_habit pada habit paused
select lives_ok(
  $$ select restart_habit('cccccccc-cccc-cccc-cccc-cccccccccccc') $$,
  'restart_habit jalan tanpa error untuk habit paused'
);

select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa, progress_hari_sukses, status
     from habits where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  $$ values (1, 4, 0, 'active'::text) $$,
  'Setelah restart: stage 1, nyawa sesuai nyawa_maks stage 1, progress 0, status active'
);

-- Test 3: restart_habit pada habit yang BUKAN paused -> error
select throws_ok(
  $$ select restart_habit('dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  'habit tidak dalam status paused, tidak perlu restart'
);

-- Test 4: RLS lewat RPC -- user2 gak bisa restart habit user1
set local request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select throws_ok(
  $$ select restart_habit('dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  'habit not found or access denied'
);

-- Test 5-6: RLS LANGSUNG di tabel (bukan lewat RPC) -- user2 gak bisa lihat data user1
select results_eq(
  $$ select count(*)::int from habit_stages where habit_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' $$,
  $$ values (0) $$,
  'User2 tidak bisa lihat habit_stages milik user1'
);

select results_eq(
  $$ select count(*)::int from check_ins where habit_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' $$,
  $$ values (0) $$,
  'User2 tidak bisa lihat check_ins milik user1'
);

-- Test 7-8: sebaliknya -- user1 (pemilik) TETAP bisa lihat datanya sendiri
set local request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
select results_eq(
  $$ select count(*)::int from habit_stages where habit_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' $$,
  $$ values (1) $$,
  'User1 (pemilik) BISA lihat habit_stages miliknya'
);

select results_eq(
  $$ select count(*)::int from check_ins where habit_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' $$,
  $$ values (1) $$,
  'User1 (pemilik) BISA lihat check_ins miliknya'
);

select * from finish();
rollback;