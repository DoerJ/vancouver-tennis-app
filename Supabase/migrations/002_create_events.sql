create table if not exists public.tennis_events (
    id uuid primary key default gen_random_uuid(),
    host_id uuid not null references public.profiles(id) on delete cascade,
    start_time timestamptz not null,
    end_time timestamptz not null,
    event_type text not null check (event_type in ('practice', 'casual', 'match')),
    max_players integer check (max_players is null or max_players > 0),
    location_city text not null check (location_city in ('burnaby', 'richmond')),
    location_court text not null check (location_court in ('bcitCourt', 'centralParkCourt', 'southarmCourt')),
    skill_level text not null check (skill_level in ('1.0', '2.0', '3.0', '4.0')),
    participants uuid[] not null default '{}',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (end_time > start_time)
);

alter table public.tennis_events enable row level security;

create policy "Events are viewable by authenticated users"
on public.tennis_events
for select
to authenticated
using (true);

create policy "Users can create hosted events"
on public.tennis_events
for insert
to authenticated
with check (auth.uid() = host_id);

create policy "Hosts can update their own events"
on public.tennis_events
for update
to authenticated
using (auth.uid() = host_id)
with check (auth.uid() = host_id);
