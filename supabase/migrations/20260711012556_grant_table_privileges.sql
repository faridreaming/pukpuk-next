-- ============================================================
-- Grant privilej tabel ke role 'authenticated'
--
-- Supabase mengubah default sejak 30 Mei 2026: project baru tidak lagi
-- otomatis dapat grant SELECT/INSERT/UPDATE/DELETE ke tabel public --
-- sekarang harus eksplisit. RLS policy kita sudah benar dari awal, tapi
-- RLS cuma ngatur BARIS mana yang boleh diakses -- tanpa grant ini,
-- role 'authenticated' bahkan belum diizinkan nyentuh tabelnya sama
-- sekali, apa pun RLS policy-nya.
--
-- 'anon' sengaja TIDAK dikasih apa pun -- Pukpuk nggak expose data
-- apa pun ke pengguna yang belum login.
-- ============================================================
grant select, insert, update, delete on public.habits to authenticated;
grant select, insert, update, delete on public.habit_stages to authenticated;
grant select, insert, update, delete on public.check_ins to authenticated;