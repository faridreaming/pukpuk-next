begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('44444444-4444-4444-4444-444444444444', 'test4@pukpuk.test');

insert into public.habits
  (id, user_id, nama, target_akhir_nilai, target_akhir_unit, stage_saat_ini, status, nyawa_tersisa, progress_hari_sukses, last_evaluated_date)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444',
   'lari', 5, 'km', 2, 'active', 1, 3, today_wib() - 1);

insert into public.habit_stages (habit_id, stage_number, target_harian, nyawa_maks) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 1, 3),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 2, 3, 3);

set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

-- Test 1-2: nyawa=1, klik gagal HARI INI -> langsung turun stage
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

-- ============================================================
-- Test 3-4: celah double-count YANG SEBENARNYA -- bukan "hari ini"
-- (loop lazy TIDAK PERNAH menyentuh hari ini, kondisinya v_day 
-- today_wib()), tapi HARI LAMPAU yang sudah ada check-in gagal
-- eksplisit, baru "kejangkau" evaluasi setelah app nggak dibuka
-- beberapa hari.
-- ============================================================
update habits set
  stage_saat_ini = 2, nyawa_tersisa = 2, progress_hari_sukses = 0,
  last_evaluated_date = today_wib() - 3
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

delete from check_ins where habit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
insert into check_ins (habit_id, tanggal, status) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', today_wib() - 2, 'gagal');

select evaluate_habit_lazy('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- Hari (-3) dan (-1) kena potong (masing2 -1 nyawa), hari (-2) DI-SKIP
-- karena sudah ada check-in di situ. Total 2x potongan bukan 3x:
-- 2 -1(hari -3)= 1 -> skip hari -2 -> 1 -1(hari -1)= 0 -> turun stage,
-- refresh ke nyawa_maks stage 1 (3)
select results_eq(
  $$ select stage_saat_ini, nyawa_tersisa from habits where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ values (1, 3) $$,
  'evaluate_habit_lazy TIDAK motong nyawa dua kali untuk hari yang sudah ada check-in gagal'
);

select results_eq(
  $$ select last_evaluated_date from habits where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ values (today_wib()) $$,
  'last_evaluated_date terupdate ke hari ini'
);

select * from finish();
rollback;