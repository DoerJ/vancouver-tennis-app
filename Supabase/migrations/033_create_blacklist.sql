create extension if not exists citext;

create table if not exists public.blacklist (
    email citext primary key,
    reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.blacklist enable row level security;

create or replace function public.current_user_email_is_blacklisted()
returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.blacklist
        where email = nullif(trim(auth.jwt() ->> 'email'), '')::citext
    );
$$;

revoke all on function public.current_user_email_is_blacklisted() from public;
grant execute on function public.current_user_email_is_blacklisted() to authenticated;

notify pgrst, 'reload schema';
