begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email) values
  ('77777777-7777-7777-7777-777777777777', 'test7@pukpuk.test');

insert into public.habits
  (id, user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '77777777-7777-7777-7777-777777777777',
   'nulis jurnal', 10, 'menit', 1, 'active', 3, 0, today_wib());

insert into public.habit_stages (habit_id, stage_number, target_harian, nyawa_maks) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 1, 10, 3);

set local role authenticated;
set local request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';

select lives_ok(
  $$ select archive_habit('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') $$,
  'archive_habit jalan tanpa error'
);

select results_eq(
  $$ select status from habits where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$,
  $$ values ('archived'::text) $$,
  'Status jadi archived'
);

select results_eq(
  $$ select count(*)::int from habit_stages where habit_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$,
  $$ values (1) $$,
  'habit_stages tetap utuh -- ini soft delete, bukan hard delete'
);

select * from finish();
rollback;