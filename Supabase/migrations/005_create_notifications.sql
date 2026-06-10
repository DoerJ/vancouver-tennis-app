create extension if not exists pgcrypto;

create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    sender uuid not null references public.profiles(id) on delete cascade,
    recipients uuid[] not null,
    notification_type text not null,
    title text not null,
    body text not null,
    related_event_id uuid references public.tennis_events(id) on delete set null,
    read_by uuid[] not null default '{}',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint notifications_recipients_not_empty check (cardinality(recipients) > 0)
);

create index if not exists notifications_sender_idx
on public.notifications(sender);

create index if not exists notifications_recipients_idx
on public.notifications
using gin (recipients);

create index if not exists notifications_related_event_id_idx
on public.notifications(related_event_id);

create index if not exists notifications_created_at_idx
on public.notifications(created_at desc);

alter table public.notifications enable row level security;

create policy "Users can view notifications they sent or received"
on public.notifications
for select
to authenticated
using (
    auth.uid() = sender
    or auth.uid() = any(recipients)
);

create policy "Users can create notifications as themselves"
on public.notifications
for insert
to authenticated
with check (auth.uid() = sender);

create policy "Senders can update their notifications"
on public.notifications
for update
to authenticated
using (auth.uid() = sender)
with check (auth.uid() = sender);
