create table if not exists public.device_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    device_token text not null,
    platform text not null default 'ios',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, device_token)
);

alter table public.device_tokens enable row level security;

create policy "Users can insert their own device tokens"
on public.device_tokens
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their own device tokens"
on public.device_tokens
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
