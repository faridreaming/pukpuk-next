begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'test3@pukpuk.test');

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

select lives_ok(
  $$ select create_habit_with_stages('meditasi', 30::numeric, 'menit', array[6,12,18,24,30]::numeric[]) $$,
  'create_habit_with_stages jalan tanpa error'
);

select results_eq(
  $$ select count(*)::int from habit_stages
     where habit_id = (select id from habits where nama = 'meditasi' limit 1) $$,
  $$ values (5) $$,
  '5 stage tersimpan sesuai array input'
);

select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa, status from habits where nama = 'meditasi' $$,
  $$ values (1, 3, 'active'::text) $$,
  'Habit baru mulai di stage 1, nyawa penuh, status active'
);

select throws_ok(
  $$ select create_habit_with_stages('invalid', 10::numeric, 'x', array[]::numeric[]) $$,
  'minimal 1 stage (kirim [target_akhir] kalau mau skip jadi habit statis)'
);

select * from finish();
rollback;