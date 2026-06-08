create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text,
    display_name text not null,
    avatar_url text,
    skill_level text,
    preferred_area text,
    bio text,
    hosted_events uuid[] not null default '{}',
    social_tags text[] not null default '{}',
    play_style text,
    availability_preferences text[] not null default '{}',
    occupation text,
    school text,
    company text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by authenticated users"
on public.profiles
for select
to authenticated
using (true);

create policy "Users can insert their own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
