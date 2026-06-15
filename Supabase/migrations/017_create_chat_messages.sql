create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),

  event_id uuid not null
    references public.tennis_events(id)
    on delete cascade,

  sender_id uuid not null
    references public.profiles(id)
    on delete cascade,

  body text not null
    check (char_length(trim(body)) > 0 and char_length(body) <= 1000),

  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create index chat_messages_event_created_idx
on public.chat_messages (event_id, created_at desc);

create index chat_messages_sender_idx
on public.chat_messages (sender_id);