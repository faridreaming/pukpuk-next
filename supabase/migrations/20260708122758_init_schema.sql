create table habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  nama text not null,
  target_akhir_nilai numeric not null,
  target_akhir_unit text not null,
  stage_saat_ini int not null default 1,
  status text not null default 'active' check (status in ('active','maintenance','paused')),
  nyawa_tersisa int not null default 3,
  last_evaluated_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table habit_stages (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references habits(id) on delete cascade,
  stage_number int not null,
  target_harian numeric not null,
  nyawa_maks int not null default 3,
  unique (habit_id, stage_number)
);

create table check_ins (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references habits(id) on delete cascade,
  tanggal date not null,
  status text not null check (status in ('berhasil','gagal')),
  created_at timestamptz not null default now(),
  unique (habit_id, tanggal)  -- ini yang enforce "satu entri per hari per habit" dari spec
);

alter table habits enable row level security;
alter table habit_stages enable row level security;
alter table check_ins enable row level security;

create policy "habits_owner" on habits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "stages_via_habit" on habit_stages
  for all using (exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid()))
  with check (exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid()));

create policy "checkins_via_habit" on check_ins
  for all using (exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid()))
  with check (exists (select 1 from habits h where h.id = habit_id and h.user_id = auth.uid()));