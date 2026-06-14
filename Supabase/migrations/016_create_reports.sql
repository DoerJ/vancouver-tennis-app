create extension if not exists pgcrypto;

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references public.profiles(id) on delete cascade,
    reported_user_id uuid references public.profiles(id) on delete set null,
    reported_event_id uuid references public.tennis_events(id) on delete set null,
    reason text not null,
    details text,
    status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint reports_has_target check (
        reported_user_id is not null
        or reported_event_id is not null
    ),
    constraint reports_no_self_report check (
        reported_user_id is null
        or reported_user_id <> reporter_id
    )
);

create index if not exists reports_reporter_id_idx
on public.reports(reporter_id);

create index if not exists reports_reported_user_id_idx
on public.reports(reported_user_id);

create index if not exists reports_reported_event_id_idx
on public.reports(reported_event_id);

create index if not exists reports_status_idx
on public.reports(status);

create index if not exists reports_created_at_idx
on public.reports(created_at desc);

alter table public.reports enable row level security;

create policy "Users can create their own reports"
on public.reports
for insert
to authenticated
with check (auth.uid() = reporter_id);

create policy "Users can view their own reports"
on public.reports
for select
to authenticated
using (auth.uid() = reporter_id);
