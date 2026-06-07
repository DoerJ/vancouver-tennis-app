create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    host_id uuid not null references public.profiles(id) on delete cascade,
    start_time timestamptz not null,
    end_time timestamptz not null,
    event_type text not null check (event_type in ('practice', 'casual', 'match')),
    max_players integer check (max_players is null or max_players > 0),
    city text not null check (city in ('burnaby', 'richmond')),
    court text not null check (court in ('bcitCourt', 'centralParkCourt', 'southarmCourt')),
    skill_level text not null check (skill_level in ('1.0', '2.0', '3.0', '4.0')),
    status text not null default 'upcoming',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (end_time > start_time)
);

alter table public.events enable row level security;

create policy "Events are viewable by authenticated users"
on public.events
for select
to authenticated
using (true);

create policy "Users can create hosted events"
on public.events
for insert
to authenticated
with check (auth.uid() = host_id);

create policy "Hosts can update their own events"
on public.events
for update
to authenticated
using (auth.uid() = host_id)
with check (auth.uid() = host_id);
