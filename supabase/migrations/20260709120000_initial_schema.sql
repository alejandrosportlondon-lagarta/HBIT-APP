-- HBIT initial schema: profiles, mornings, missions, proof_references.
-- RLS everywhere: users can only read/write their own rows.
-- The client is offline-first; these tables are the background sync target,
-- never a dependency of the core alarm/proof/scoring loop.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles — one row per auth user, created automatically on signup
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  timezone text not null default 'UTC',
  -- Server-side emergency-exit escalation counter (Milestone 3): must
  -- survive app reinstalls, so it lives here, not on device.
  emergency_exit_uses integer not null default 0,
  emergency_exit_last_used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: own row select" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles: own row insert" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles: own row update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles: own row delete" on public.profiles
  for delete using (auth.uid() = id);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- proof_references — registered proof targets (barcode payloads, photo
-- feature prints, math/steps config). Payload is opaque JSON owned by the
-- client's ProofKit.
-- ---------------------------------------------------------------------------

create table public.proof_references (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('math', 'steps', 'barcode', 'photoMatch')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index proof_references_user_id_idx on public.proof_references (user_id);

alter table public.proof_references enable row level security;

create policy "proof_references: own rows select" on public.proof_references
  for select using (auth.uid() = user_id);
create policy "proof_references: own rows insert" on public.proof_references
  for insert with check (auth.uid() = user_id);
create policy "proof_references: own rows update" on public.proof_references
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "proof_references: own rows delete" on public.proof_references
  for delete using (auth.uid() = user_id);

create trigger proof_references_set_updated_at
  before update on public.proof_references
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- missions — the user's configured morning mission list (the editable
-- template; each morning's locked snapshot lives in mornings.missions)
-- ---------------------------------------------------------------------------

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  template text not null default 'custom',
  proof_type text check (proof_type in ('math', 'steps', 'barcode', 'photoMatch')),
  proof_reference_id uuid references public.proof_references (id) on delete set null,
  position integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index missions_user_id_idx on public.missions (user_id);

alter table public.missions enable row level security;

create policy "missions: own rows select" on public.missions
  for select using (auth.uid() = user_id);
create policy "missions: own rows insert" on public.missions
  for insert with check (auth.uid() = user_id);
create policy "missions: own rows update" on public.missions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "missions: own rows delete" on public.missions
  for delete using (auth.uid() = user_id);

create trigger missions_set_updated_at
  before update on public.missions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- mornings — the single source of truth: one row per user per day.
-- All times UTC; `date` is the calendar day in the user's timezone at
-- alarm time.
-- ---------------------------------------------------------------------------

create table public.mornings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  date date not null,
  wake_target timestamptz not null,
  wake_actual timestamptz,
  result text check (result in ('win', 'loss')),
  score integer check (score between 0 and 100),
  missions jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

create index mornings_user_id_date_idx on public.mornings (user_id, date desc);

alter table public.mornings enable row level security;

create policy "mornings: own rows select" on public.mornings
  for select using (auth.uid() = user_id);
create policy "mornings: own rows insert" on public.mornings
  for insert with check (auth.uid() = user_id);
create policy "mornings: own rows update" on public.mornings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "mornings: own rows delete" on public.mornings
  for delete using (auth.uid() = user_id);

create trigger mornings_set_updated_at
  before update on public.mornings
  for each row execute function public.set_updated_at();
