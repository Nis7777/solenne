-- Solenne backend: per-user generation log (daily cap) + storage for narrated audio.
-- The app itself is local-first; this is only what the edge functions need.

create table if not exists public.generations (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('story', 'reflect', 'tags', 'voice')),
  created_at timestamptz not null default now()
);

create index if not exists generations_user_day on public.generations (user_id, created_at desc);

alter table public.generations enable row level security;

-- Users can read their own usage; only the service role (edge functions) writes.
create policy "read own generations" on public.generations
  for select using (auth.uid() = user_id);

-- Narrated audio. Public read so AVPlayer can stream it; paths are unguessable UUIDs.
insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;
